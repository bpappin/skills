const entities = require('@jetbrains/youtrack-scripting-api/entities');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'add_discovered_work',
  description:
    'THE SCOPE-GUARD OFF-RAMP. When you discover work that does not serve an AC item of the current story (a bug, a refactor, a missing feature, a good idea), call this to log it as a NEW issue linked to the current story - then return to the story. ' +
    'This is the default action for anything out of scope; never silently expand the current story instead. The new issue starts unassigned at the project default priority (urgency is a triage decision - never copy the current story\'s priority) and inherits the story\'s topical tags so the work stays grouped.',
  inputSchema: {
    type: 'object',
    properties: {
      summary: { type: 'string', description: 'Short title for the discovered work.' },
      description: { type: 'string', description: 'Optional details: what was found, where, why it matters. Include an "## Acceptance Criteria" section if the scope is already clear.' },
      issueId: { type: 'string', description: 'The story you were working on when this surfaced. Omit ONLY if you want your focused story used - the focus may belong to another project.' },
      fromIssueId: { type: 'string', description: 'Alias of issueId, kept for older callers. Prefer issueId.' },
    },
    required: ['summary'],
  },
  annotations: {
    title: 'Log discovered work as a new linked issue',
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const ro = lib.readOnlyRefusal(ctx, {
      action: 'add_discovered_work',
      summary: ctx.arguments.summary,
      description: ctx.arguments.description || null,
      fromIssueId: ctx.arguments.issueId || ctx.arguments.fromIssueId || null,
    });
    if (ro) return ro;

    // Accept either name. Passing an id and having it silently ignored
    // creates the issue in whatever project the focus points at - a
    // different project entirely, in the worst case.
    const passedId = ctx.arguments.issueId || ctx.arguments.fromIssueId || null;
    const r = lib.resolveIssue(passedId, { forWrite: true });
    if (r.error) return { error: r.error };
    const source = r.issue;

    const u = lib.currentUser();
    if (u.error) return { error: u.error };

    const created = new entities.Issue(u.user, source.project, ctx.arguments.summary);
    if (ctx.arguments.description) {
      created.description = ctx.arguments.description;
    }

    // Prefer a dedicated "discovered from" link type; fall back to relates-to + tag.
    let linkType = lib.DISCOVERED_LINK;
    try {
      created.links[lib.DISCOVERED_LINK].add(source);
    } catch (e) {
      linkType = 'relates to';
      try {
        created.links['relates to'].add(source);
      } catch (e2) {
        linkType = null;
      }
      try {
        created.addTag('discovered');
      } catch (e3) {
        // tag creation not permitted; link (if any) still records provenance
      }
    }

    // Grouping travels with the off-ramp: inherit the source's non-machinery
    // server tags - the delivery batch it belongs to - never the
    // workflow/triage machinery tags, and never the priority. The "Topical
    // Tags" custom field is a different mechanism and does NOT travel here.
    const inherited = [];
    lib.nonMachineryTags(source).forEach((name) => {
      try {
        created.addTag(name);
        inherited.push(name);
      } catch (e) {
        // tag not creatable/visible for this user - skip
      }
    });

    return {
      newIssueId: created.id,
      linkedTo: source.id,
      project: source.project.key,
      usedFocus: !passedId,
      linkType: linkType,
      inheritedTags: inherited,
      message:
        'Discovered work logged as ' + created.id + ' in project ' + source.project.key +
        (passedId ? '' : ' (from your FOCUSED story - no issue id was passed; check the project is right)') +
        ' - it will be triaged separately. Now continue working on ' + source.id +
        '; do not start the new issue.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      newIssueId: { type: 'string' },
      linkedTo: { type: 'string' },
      project: { type: 'string' },
      usedFocus: { type: 'boolean' },
      linkType: { type: ['string', 'null'] },
      inheritedTags: { type: 'array', items: { type: 'string' } },
      message: { type: 'string' },
    },
    required: ['newIssueId'],
  },
};
