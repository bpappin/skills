const entities = require('@jetbrains/youtrack-scripting-api/entities');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'add_discovered_work',
  description:
    'THE SCOPE-GUARD OFF-RAMP. When you discover work that does not serve an AC item of the current story (a bug, a refactor, a missing feature, a good idea), call this to log it as a NEW issue linked to the current story - then return to the story. ' +
    'This is the default action for anything out of scope; never silently expand the current story instead. The new issue starts unassigned and unscheduled so it can be triaged later.',
  inputSchema: {
    type: 'object',
    properties: {
      summary: { type: 'string', description: 'Short title for the discovered work.' },
      description: { type: 'string', description: 'Optional details: what was found, where, why it matters. Include an "## Acceptance Criteria" section if the scope is already clear.' },
      fromIssueId: { type: 'string', description: 'The story you were working on when this surfaced. Omit to use your focused story.' },
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
      fromIssueId: ctx.arguments.fromIssueId || null,
    });
    if (ro) return ro;

    const r = lib.resolveIssue(ctx.arguments.fromIssueId);
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

    return {
      newIssueId: created.id,
      linkedTo: source.id,
      linkType: linkType,
      message:
        'Discovered work logged as ' + created.id + ' - it will be triaged separately. Now continue working on ' + source.id + '; do not start the new issue.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      newIssueId: { type: 'string' },
      linkedTo: { type: 'string' },
      linkType: { type: ['string', 'null'] },
      message: { type: 'string' },
    },
    required: ['newIssueId'],
  },
};
