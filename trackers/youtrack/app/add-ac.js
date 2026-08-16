const parser = require('./ac-parser');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'add_ac',
  description:
    'Add a new acceptance-criteria item to a story. THIS EXPANDS THE STORY\'S SCOPE - use it only when the user has explicitly agreed to widen this story. ' +
    'For newly discovered work, bugs, or ideas that surfaced while working, use story_add_discovered_work instead: it logs the work as a separate linked issue and keeps this story\'s scope stable.',
  inputSchema: {
    type: 'object',
    properties: {
      text: { type: 'string', description: 'The new AC item, phrased as a verifiable outcome.' },
      issueId: { type: 'string', description: 'Issue ID. Omit to use your focused story.' },
    },
    required: ['text'],
  },
  annotations: {
    title: 'Add acceptance criteria item (scope expansion)',
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const ro = lib.readOnlyRefusal(ctx, {
      action: 'add_ac',
      issueId: ctx.arguments.issueId || null,
      text: ctx.arguments.text,
    });
    if (ro) return ro;

    const r = lib.resolveIssue(ctx.arguments.issueId, { forWrite: true });
    if (r.error) return { error: r.error };
    const issue = r.issue;

    const result = parser.addItem(issue.description, ctx.arguments.text);
    issue.description = result.description;
    return {
      id: issue.id,
      ac: result.ac,
      message: 'Scope expanded: new AC item added. If this was not explicitly approved by the user, undo by discussing with them - or move it to a new issue via story_add_discovered_work.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      id: { type: 'string' },
      ac: { type: 'array' },
      message: { type: 'string' },
    },
  },
};
