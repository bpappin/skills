const entities = require('@jetbrains/youtrack-scripting-api/entities');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'set_focus',
  description:
    'Pin the story you (this user) are actively working on. Other story_* tools default to the focused story when issueId is omitted. ' +
    'Set focus once at the start of a work session; change it deliberately, not because new work appeared mid-task.',
  inputSchema: {
    type: 'object',
    properties: {
      issueId: {
        type: 'string',
        description: 'Issue ID to focus (e.g. PROJ-123).',
      },
    },
    required: ['issueId'],
  },
  annotations: {
    title: 'Set focused story',
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const issue = entities.Issue.findById(ctx.arguments.issueId);
    if (!issue) {
      return { error: 'Issue ' + ctx.arguments.issueId + ' not found or not visible to you.' };
    }
    const w = lib.setFocus(issue);
    if (w.error) return { error: w.error };

    // Read it back. A write that reports success and does not stick is the
    // worst outcome here: every later tool then acts on the old story.
    const after = lib.focusInfo();
    if (after.id !== issue.id) {
      return {
        error: 'Focus did not take: asked for ' + issue.id + ', reads back as ' +
          (after.id || 'nothing') + '. Do not rely on focus - pass issueId explicitly.',
      };
    }
    let project = null;
    try { project = issue.project.key; } catch (e) { /* unreadable */ }
    return Object.assign({ focused: true, project: project, owner: after.login }, lib.miniContext(issue));
  },
  outputSchema: {
    type: 'object',
    properties: {
      focused: { type: 'boolean' },
      project: { type: ['string', 'null'] },
      owner: { type: ['string', 'null'] },
      id: { type: 'string' },
      summary: { type: 'string' },
      acOpen: { type: 'number' },
    },
    required: ['id'],
  },
};
