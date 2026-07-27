const entities = require('@jetbrains/youtrack-scripting-api/entities');
const parser = require('./ac-parser');
const lib = require('./story-lib');

exports.aiTool = {
  name: 'get_story_context',
  description:
    'Full briefing for the story you are working on: summary, state, acceptance criteria (AC) checklist, references to ADR/PRD docs, linked discovered work, and whether a QA/Gherkin section is required. ' +
    'Call this at the start of a work session and re-read it before making scope decisions. ' +
    'THE AC LIST DEFINES THE SCOPE: work that does not serve an AC item belongs in a new issue via story_add_discovered_work, never in silent expansion of this story. ' +
    'If issueId is omitted, uses your focused story (story_set_focus).',
  inputSchema: {
    type: 'object',
    properties: {
      issueId: {
        type: 'string',
        description: 'Issue ID (e.g. PROJ-123). Omit to use your focused story.',
      },
    },
  },
  annotations: {
    title: 'Get story context',
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
    const focusId = lib.getFocusId();

    return {
      id: issue.id,
      summary: issue.summary,
      state: issue.fields.State ? issue.fields.State.name : null,
      assignee: issue.fields.Assignee ? issue.fields.Assignee.login : null,
      project: { key: issue.project.key, name: issue.project.name },
      description: issue.description,
      hasAcSection: parsed.hasAcSection,
      ac: parsed.ac,
      references: parsed.references,
      qaRequired: lib.hasTag(issue, lib.NEEDS_GHERKIN_TAG),
      qaSectionPresent: parsed.qaSectionPresent,
      parent: lib.linkedIssues(issue, 'subtask of'),
      discoveredWork: lib.linkedIssues(issue, lib.DISCOVERED_LINK),
      isFocused: focusId === issue.id,
      scopeRule:
        'Only work that serves an unchecked AC item above is in scope. Anything else you discover: call story_add_discovered_work to log it as a separate linked issue, then continue this story.',
    };
  },
  outputSchema: {
    type: 'object',
    properties: {
      id: { type: 'string' },
      summary: { type: 'string' },
      ac: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            index: { type: 'number' },
            text: { type: 'string' },
            done: { type: 'boolean' },
          },
        },
      },
    },
    required: ['id'],
  },
};
