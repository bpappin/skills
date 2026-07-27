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
    const r = lib.currentUser();
    if (r.error) return { error: r.error };

    r.user.extensionProperties.focusIssueId = issue.id;
    return Object.assign({ focused: true }, lib.miniContext(issue));
  },
  outputSchema: {
    type: 'object',
    properties: {
      focused: { type: 'boolean' },
      id: { type: 'string' },
      summary: { type: 'string' },
      acOpen: { type: 'number' },
    },
    required: ['id'],
  },
};
