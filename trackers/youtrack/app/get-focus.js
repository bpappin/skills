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
    const focusId = lib.getFocusId();
    if (!focusId) {
      return { focus: null, message: 'No focused story. Call story_set_focus with an issueId.' };
    }
    const issue = entities.Issue.findById(focusId);
    if (!issue) {
      return { focus: null, message: 'Focused story ' + focusId + ' no longer exists or is not visible. Call story_set_focus again.' };
    }
    return { focus: lib.miniContext(issue) };
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
      message: { type: 'string' },
    },
  },
};
