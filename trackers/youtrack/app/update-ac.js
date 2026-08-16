const parser = require('./ac-parser');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'update_ac',
  description:
    'Check or uncheck one acceptance-criteria item on a story. Identify the item by BOTH its index and a prefix of its text — if they disagree (someone edited the list), the tool refuses and returns the current list so you can retry. ' +
    'Only mark an item done when the work is verifiably complete. Returns the full updated AC list.',
  inputSchema: {
    type: 'object',
    properties: {
      index: { type: 'number', description: '0-based index in the AC list as returned by story_get_story_context.' },
      textPrefix: { type: 'string', description: 'First few words of the AC item text, as a drift guard.' },
      done: { type: 'boolean', description: 'true to check the item, false to uncheck.' },
      issueId: { type: 'string', description: 'Issue ID. Omit to use your focused story.' },
    },
    required: ['index', 'textPrefix', 'done'],
  },
  annotations: {
    title: 'Update acceptance criteria item',
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const ro = lib.readOnlyRefusal(ctx, {
      action: 'update_ac',
      issueId: ctx.arguments.issueId || null,
      index: ctx.arguments.index,
      textPrefix: ctx.arguments.textPrefix,
      done: ctx.arguments.done,
    });
    if (ro) return ro;

    const r = lib.resolveIssue(ctx.arguments.issueId, { forWrite: true });
    if (r.error) return { error: r.error };
    const issue = r.issue;

    const result = parser.setItem(
      issue.description,
      ctx.arguments.index,
      ctx.arguments.textPrefix,
      ctx.arguments.done
    );
    if (result.error) return { error: result.error, ac: result.ac };

    issue.description = result.description;
    const open = result.ac.filter((a) => !a.done).length;
    return {
      id: issue.id,
      ac: result.ac,
      acOpen: open,
      message: open === 0 ? 'All AC checked. Call story_complete_story to validate completion.' : open + ' AC item(s) remaining.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      id: { type: 'string' },
      ac: { type: 'array' },
      acOpen: { type: 'number' },
      message: { type: 'string' },
    },
  },
};
