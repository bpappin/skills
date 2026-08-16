const entities = require('@jetbrains/youtrack-scripting-api/entities');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'get_focus',
  description:
    'Return the story this user is currently focused on (set via story_set_focus), with a mini status: summary, state, open AC count. ' +
    'Call this at the start of a session to recover context. If nothing is focused, ask the user which story to work on, then call story_set_focus.',
  inputSchema: { type: 'object', properties: {} },
  annotations: {
    title: 'Get focused story',
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: () => {
    const info = lib.focusInfo();
    if (!info.id) {
      return { focus: null, owner: info.login, message: 'No focused story. Call story_set_focus with an issueId.' };
    }
    const issue = entities.Issue.findById(info.id);
    if (!issue) {
      return {
        focus: null,
        owner: info.login,
        message: 'Focused story ' + info.id + ' no longer exists or is not visible. Call story_set_focus again.',
      };
    }
    let project = info.project;
    try { project = issue.project.key; } catch (e) { /* keep the recorded one */ }
    const stale = lib.isResolved(issue);
    return {
      focus: lib.miniContext(issue),
      project: project,
      owner: info.login,
      stale: stale,
      message: (stale
        ? 'This focused story is already resolved - the focus is probably stale. '
        : '') +
        'Focus is stored per user (' + (info.login || 'unknown') + '), not per project: ' +
        'it is a single value, so a story in another project can be sitting here. ' +
        'Pass issueId explicitly on any tool that writes.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      focus: {
        type: ['object', 'null'],
        properties: {
          id: { type: 'string' },
          summary: { type: 'string' },
          acOpen: { type: 'number' },
        },
      },
      project: { type: ['string', 'null'] },
      owner: { type: ['string', 'null'] },
      stale: { type: 'boolean' },
      message: { type: 'string' },
    },
  },
};
