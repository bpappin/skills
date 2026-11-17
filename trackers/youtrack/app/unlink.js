const entities = require('@jetbrains/youtrack-scripting-api/entities');
const lib = require('./story-lib');
const args = require('./args');
const links = require('./link-lib');

exports.aiTool = {
  name: 'unlink',
  description:
    'Remove a link between two issues - the repair for a link that went in backwards or should not exist. ' +
    'Same sentence order as story_link: issueId, linkType, otherIssueId removes "issueId <linkType> otherIssueId" and nothing else. ' +
    'If the link holds the other way round instead, nothing is removed and the result gives the call that would remove it. ' +
    'Only remove a link you made in this session, or one the user asked you to remove.',
  inputSchema: {
    type: 'object',
    properties: {
      issueId: { type: 'string', description: 'The subject of the sentence being removed.' },
      linkType: { type: 'string', description: 'The link name as it reads from issueId\'s side, exactly as its issue page shows it.' },
      otherIssueId: { type: 'string', description: 'The object of the sentence being removed.' },
    },
    required: ['issueId', 'linkType', 'otherIssueId'],
  },
  annotations: {
    title: 'Remove a link between two issues',
    readOnlyHint: false,
    destructiveHint: true,
    idempotentHint: false,
    openWorldHint: false,
    returnDirect: false,
  },
  execute: (ctx) => {
    const bad = args.refuseUnknown(ctx.arguments, exports.aiTool.inputSchema);
    if (bad) return bad;

    const a = ctx.arguments;
    const ro = lib.readOnlyRefusal(ctx, {
      action: 'unlink', issueId: a.issueId, linkType: a.linkType, otherIssueId: a.otherIssueId,
    });
    if (ro) return ro;

    const issue = a.issueId ? entities.Issue.findById(a.issueId) : null;
    if (!issue) return { error: 'Issue ' + a.issueId + ' not found or not visible to you. Nothing was changed.' };
    const other = a.otherIssueId ? entities.Issue.findById(a.otherIssueId) : null;
    if (!other) return { error: 'Issue ' + a.otherIssueId + ' not found or not visible to you. Nothing was changed.' };

    return links.unlink(issue, a.linkType, other);
  },
  outputSchema: {
    type: 'object',
    properties: {
      unlinked: { type: 'boolean' },
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
