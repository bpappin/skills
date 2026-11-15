const entities = require('@jetbrains/youtrack-scripting-api/entities');
const lib = require('./story-lib');
const links = require('./link-lib');

exports.aiTool = {
  name: 'link',
  description:
    'Link two issues. The three arguments read as a sentence, in this order: issueId, linkType, otherIssueId - ' +
    '"PROJ-2 subtask of PROJ-1" is issueId=PROJ-2, linkType="subtask of", otherIssueId=PROJ-1; ' +
    '"PROJ-3 depends on PROJ-4" is issueId=PROJ-3, linkType="depends on", otherIssueId=PROJ-4. ' +
    'Prefer this to the built-in link_issues, whose parameter names read the other way round. ' +
    'The result repeats the sentence as read back from the issue: check it says what you meant. ' +
    'A link that already holds is left alone; one that already holds the other way round is refused, with the call that removes it.',
  inputSchema: {
    type: 'object',
    properties: {
      issueId: { type: 'string', description: 'The subject of the sentence: the issue the link type is said OF (e.g. the child, the blocked one, the duplicate).' },
      linkType: { type: 'string', description: 'The link name as it reads from issueId\'s side, exactly as its issue page shows it: "subtask of", "parent for", "depends on", "is required for", "duplicates", "relates to", "discovered from".' },
      otherIssueId: { type: 'string', description: 'The object of the sentence: the issue on the far side (e.g. the parent, the blocker, the original).' },
    },
    required: ['issueId', 'linkType', 'otherIssueId'],
  },
  annotations: {
    title: 'Link two issues, read as a sentence',
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const a = ctx.arguments;
    const ro = lib.readOnlyRefusal(ctx, {
      action: 'link', issueId: a.issueId, linkType: a.linkType, otherIssueId: a.otherIssueId,
    });
    if (ro) return ro;

    // Both ids are required and neither falls back to focus: a link that
    // lands on whatever story happens to be focused is the kind of mistake
    // this tool exists to stop.
    const issue = a.issueId ? entities.Issue.findById(a.issueId) : null;
    if (!issue) return { error: 'Issue ' + a.issueId + ' not found or not visible to you. Nothing was changed.' };
    const other = a.otherIssueId ? entities.Issue.findById(a.otherIssueId) : null;
    if (!other) return { error: 'Issue ' + a.otherIssueId + ' not found or not visible to you. Nothing was changed.' };

    return links.link(issue, a.linkType, other);
  },
  outputSchema: {
    type: 'object',
    properties: {
      linked: { type: 'boolean' },
      alreadyLinked: { type: 'boolean' },
      verified: { type: 'boolean' },
      sentence: { type: 'string' },
      issueId: { type: 'string' },
      linkType: { type: 'string' },
      otherIssueId: { type: 'string' },
      reverseExists: { type: 'boolean' },
      message: { type: 'string' },
      error: { type: 'string' },
    },
  },
};
