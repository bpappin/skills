/** Shared helpers for the story_* aiTool rules. */

const entities = require('@jetbrains/youtrack-scripting-api/entities');
const parser = require('./ac-parser');

const VERSION = '0.5.0';  // keep in sync with manifest.json (tests/version.test.js enforces)
const DISCOVERED_LINK = 'discovered from';
const NEEDS_GHERKIN_TAG = 'needs-gherkin';

// Workflow/triage machinery tags - never treated as topical grouping tags,
// never inherited by discovered work. Everything else on a story is topical.
const RESERVED_TAGS = [
  'needs-gherkin', 'discovered', 'ready-for-agent', 'ready-for-human',
  'needs-triage', 'needs-info', 'triaged', 'bug', 'enhancement', 'wontfix',
  'Star',
];

function currentUser() {
  // Spike S3: confirm User.current resolves to the MCP caller inside aiTools.
  const user = entities.User.current;
  if (!user) {
    return { error: 'Could not resolve the calling user. Pass an explicit issueId instead of relying on focus.' };
  }
  return { user };
}

function getFocusId() {
  const r = currentUser();
  if (r.error) return null;
  return r.user.extensionProperties.focusIssueId || null;
}

/**
 * Who owns the focus, and where it points. Focus lives on the user record,
 * so WHICH user that is decides whether focus is per-person or shared by
 * everyone using the same token. Report it rather than assume it.
 */
function focusInfo() {
  const out = { id: null, project: null, login: null };
  const r = currentUser();
  if (r.error) return out;
  try { out.login = r.user.login || null; } catch (e) { /* not readable */ }
  try { out.id = r.user.extensionProperties.focusIssueId || null; } catch (e) { /* unset */ }
  try { out.project = r.user.extensionProperties.focusProject || null; } catch (e) { /* older focus, set before projects were recorded */ }
  return out;
}

function setFocus(issue) {
  const r = currentUser();
  if (r.error) return { error: r.error };
  r.user.extensionProperties.focusIssueId = issue.id;
  // Recorded so a caller can see the project without loading the issue -
  // a focus pointing at another project is the failure that costs real work.
  try { r.user.extensionProperties.focusProject = issue.project.key; } catch (e) { /* best effort */ }
  return { ok: true };
}

/** Is this issue closed? Best-effort - never throws, never blocks on failure. */
function isResolved(issue) {
  try { return !!issue.resolved; } catch (e) { return false; }
}

/**
 * Resolve the target issue: an explicit id ALWAYS wins.
 *
 * Falling back to focus is the dangerous path. Focus is one value on the
 * user record with no project dimension, so it can point at a story in a
 * completely different project - and a write that lands there is not a
 * typo, it is an issue filed under the wrong key, linked to unrelated work
 * and needing manual cleanup. So the fallback reports itself, and refuses
 * when the focused story is closed, which is the usual sign it is stale.
 */
function resolveIssue(issueId, opts) {
  const options = opts || {};
  const id = issueId || getFocusId();
  if (!id) {
    return { error: 'No issueId given and no focused story. Call story_set_focus first, or pass issueId.' };
  }
  const issue = entities.Issue.findById(id);
  if (!issue) {
    return { error: 'Issue ' + id + ' not found or not visible to you.' };
  }
  const usedFocus = !issueId;
  if (usedFocus && options.forWrite && isResolved(issue)) {
    return {
      error: 'Refusing to act on the focused story ' + id + ': it is already resolved, ' +
        'so the focus is almost certainly stale. Pass an explicit issueId, or call ' +
        'story_set_focus with the story you are actually working on.',
    };
  }
  let project = null;
  try { project = issue.project.key; } catch (e) { /* unreadable */ }
  return { issue, id, usedFocus, project };
}

// Case-insensitive: humans Title Case tags ("Triaged"), and a case
// variant of a machinery tag must never be inherited.
const RESERVED_LOWER = RESERVED_TAGS.map((t) => t.toLowerCase());

/**
 * Every server tag on the issue that is not workflow/triage machinery -
 * in practice the one-off delivery batch tag, plus whatever else an admin
 * has created for cross-cutting state.
 *
 * NOT the "Topical Tags" custom field, despite the resemblance. That field
 * is a separate, later mechanism: its values are curated in the repo
 * (.agents/config/topical-tags.md) and pushed into the field's value set,
 * because agents cannot create server tags - one made ad hoc is owned by
 * that account and invisible to everyone else. This function was named
 * topicalTags before that field existed, which read as a claim it never
 * made. Read it as "tags an agent may inherit", nothing more.
 */
function nonMachineryTags(issue) {
  const out = [];
  const tags = issue.tags;
  if (!tags) return out;
  tags.forEach((t) => {
    if (RESERVED_LOWER.indexOf(String(t.name).toLowerCase()) === -1) out.push(t.name);
  });
  return out;
}

function allTags(issue) {
  const out = [];
  const tags = issue.tags;
  if (!tags) return out;
  tags.forEach((t) => { if (t.name !== 'Star') out.push(t.name); });
  return out;
}

function fieldValue(issue, name) {
  try {
    const v = issue.fields[name];
    return v && v.name !== undefined ? v.name : null;
  } catch (e) {
    return null;
  }
}

/**
 * Two distinct dimensions:
 *   stage = where the work is in the flow (Stage/Kanban State/Status)
 *   State = how it concluded (Fixed, Won't fix, Duplicate, ...) - the
 *           resolution, when the project separates the two.
 * Projects with only a State field use it for both; then state() reads
 * State and resolution() is null.
 */
function stateName(issue) {
  const flow = ['Stage', 'Kanban State', 'Status'];
  for (let i = 0; i < flow.length; i++) {
    const v = fieldValue(issue, flow[i]);
    if (v) return v;
  }
  return fieldValue(issue, 'State');
}

function resolutionName(issue) {
  const flow = ['Stage', 'Kanban State', 'Status'];
  for (let i = 0; i < flow.length; i++) {
    if (fieldValue(issue, flow[i])) return fieldValue(issue, 'State');
  }
  return null;  // single-state-field project: State IS the flow, no separate resolution
}

/** Best-effort read of a multi-value field's names; null when absent/unreadable. */
function fieldNames(issue, fieldName) {
  try {
    const v = issue.fields[fieldName];
    if (!v) return null;
    const out = [];
    v.forEach((x) => out.push(x.name !== undefined ? x.name : '' + x));
    return out;
  } catch (e) {
    return null;
  }
}

/** Best-effort read of a field's display value; null when absent/unreadable. */
function fieldString(issue, fieldName) {
  try {
    const v = issue.fields[fieldName];
    if (v === null || v === undefined) return null;
    return v.name !== undefined ? v.name : '' + v;
  } catch (e) {
    return null;
  }
}

function hasTag(issue, tagName) {
  const tags = issue.tags;
  if (!tags) return false;
  let found = false;
  tags.forEach((t) => { if (t.name === tagName) found = true; });
  return found;
}

function linkedIssues(issue, linkName) {
  const out = [];
  const links = issue.links[linkName];
  if (links) {
    links.forEach((l) => out.push({ id: l.id, summary: l.summary, resolved: !!l.resolved }));
  }
  return out;
}

function miniContext(issue) {
  const parsed = parser.parse(issue.description);
  const open = parsed.ac.filter((a) => !a.done).length;
  return {
    id: issue.id,
    summary: issue.summary,
    state: stateName(issue),
    acTotal: parsed.ac.length,
    acOpen: open,
  };
}

/**
 * Instance-wide write guard, toggled by an admin in the app's Settings tab.
 * Returns null when writes are allowed, or a structured refusal the agent
 * can relay to a human (include the proposed change in `proposed`).
 */
function readOnlyRefusal(ctx, proposed) {
  const on = !!(ctx && ctx.settings && ctx.settings.readOnlyMode);
  if (!on) return null;
  return {
    error: 'story-tools is in read-only mode on this YouTrack instance. Do not retry; present the proposed change to the user so a human can apply it.',
    readOnly: true,
    proposed: proposed || null,
  };
}

exports.VERSION = VERSION;
exports.readOnlyRefusal = readOnlyRefusal;
exports.RESERVED_TAGS = RESERVED_TAGS;
exports.nonMachineryTags = nonMachineryTags;
exports.allTags = allTags;
exports.fieldString = fieldString;
exports.fieldNames = fieldNames;
exports.stateName = stateName;
exports.resolutionName = resolutionName;
exports.DISCOVERED_LINK = DISCOVERED_LINK;
exports.NEEDS_GHERKIN_TAG = NEEDS_GHERKIN_TAG;
exports.currentUser = currentUser;
exports.getFocusId = getFocusId;
exports.focusInfo = focusInfo;
exports.setFocus = setFocus;
exports.isResolved = isResolved;
exports.resolveIssue = resolveIssue;
exports.hasTag = hasTag;
exports.linkedIssues = linkedIssues;
exports.miniContext = miniContext;
