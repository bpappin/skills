/** Shared helpers for the story_* aiTool rules. */

const entities = require('@jetbrains/youtrack-scripting-api/entities');
const parser = require('./ac-parser');

const DISCOVERED_LINK = 'discovered from';
const NEEDS_GHERKIN_TAG = 'needs-gherkin';

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

/** Resolve the target issue: explicit id wins, else the caller's focused issue. */
function resolveIssue(issueId) {
  const id = issueId || getFocusId();
  if (!id) {
    return { error: 'No issueId given and no focused story. Call story_set_focus first, or pass issueId.' };
  }
  const issue = entities.Issue.findById(id);
  if (!issue) {
    return { error: 'Issue ' + id + ' not found or not visible to you.' };
  }
  return { issue, id };
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
    state: issue.fields.State ? issue.fields.State.name : null,
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

exports.readOnlyRefusal = readOnlyRefusal;
exports.DISCOVERED_LINK = DISCOVERED_LINK;
exports.NEEDS_GHERKIN_TAG = NEEDS_GHERKIN_TAG;
exports.currentUser = currentUser;
exports.getFocusId = getFocusId;
exports.resolveIssue = resolveIssue;
exports.hasTag = hasTag;
exports.linkedIssues = linkedIssues;
exports.miniContext = miniContext;
