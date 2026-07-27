const parser = require('./ac-parser');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'complete_story',
  description:
    'Validate whether a story is ready to be closed. Checks that every AC item is done and, when the story carries the "needs-gherkin" tag, that a "## QA" section with Gherkin scenarios is present. ' +
    'Returns a verdict and next actions; it does NOT change the issue state - use the standard update_issue tool to move it once ready=true. Call this before declaring any story finished.',
  inputSchema: {
    type: 'object',
    properties: {
      issueId: { type: 'string', description: 'Issue ID. Omit to use your focused story.' },
    },
  },
  annotations: {
    title: 'Validate story completion',
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const r = lib.resolveIssue(ctx.arguments.issueId);
    if (r.error) return { error: r.error };
    const issue = r.issue;

    const parsed = parser.parse(issue.description);
    const unchecked = parsed.ac.filter((a) => !a.done);
    const qaRequired = lib.hasTag(issue, lib.NEEDS_GHERKIN_TAG);
    const discovered = lib.linkedIssues(issue, lib.DISCOVERED_LINK);
    const openDiscovered = discovered.filter((d) => !d.resolved);

    const nextActions = [];
    if (!parsed.hasAcSection) {
      nextActions.push('Story has no "## Acceptance Criteria" section - add one before completing.');
    }
    unchecked.forEach((a) => {
      nextActions.push('Complete and check AC[' + a.index + ']: "' + a.text + '" (story_update_ac).');
    });
    if (qaRequired && !parsed.qaSectionPresent) {
      nextActions.push('This story is tagged needs-gherkin: add a "## QA" section with Given/When/Then scenarios to the description.');
    }
    if (openDiscovered.length > 0) {
      nextActions.push('FYI: ' + openDiscovered.length + ' open discovered-work issue(s) linked - they do NOT block completion, but mention them to the user.');
    }

    const ready = parsed.hasAcSection && unchecked.length === 0 && (!qaRequired || parsed.qaSectionPresent);
    return {
      id: issue.id,
      ready: ready,
      acTotal: parsed.ac.length,
      uncheckedAc: unchecked.map(({ index, text }) => ({ index, text })),
      qaRequired: qaRequired,
      qaSectionPresent: parsed.qaSectionPresent,
      openDiscoveredWork: openDiscovered,
      nextActions: nextActions,
      message: ready
        ? 'Story is ready to close. Use update_issue to set its state, and confirm with the user.'
        : 'Story is NOT ready to close. Work through nextActions.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      id: { type: 'string' },
      ready: { type: 'boolean' },
      uncheckedAc: { type: 'array' },
      qaRequired: { type: 'boolean' },
      qaSectionPresent: { type: 'boolean' },
      nextActions: { type: 'array', items: { type: 'string' } },
      message: { type: 'string' },
    },
    required: ['ready'],
  },
};
