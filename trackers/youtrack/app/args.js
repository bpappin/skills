/**
 * Refusing an argument a tool does not know.
 *
 * A tool that ignores an argument it does not recognise answers a question
 * nobody asked. For the story_* tools that is not a harmless default: with
 * no issue or project named they fall back to the caller's focused story,
 * and focus is one value per account, not per project - so `project: "A"`
 * where the tool takes `projectKey` came back with project B's values, and
 * nothing in the call said the argument had been dropped. A write tool
 * called the same way acts on the wrong story.
 *
 * So a name that is not in the tool's own input schema stops the call,
 * and the refusal lists the names the tool does take.
 *
 * No scripting-API import, so the tests can load it.
 */

// What a caller most often means by a name the tools do not use.
const MEANT = {
  project: 'projectKey', projectid: 'projectKey', key: 'projectKey', projectkey: 'projectKey',
  issue: 'issueId', id: 'issueId', issuekey: 'issueId', story: 'issueId', storyid: 'issueId', issueid: 'issueId',
  other: 'otherIssueId', target: 'otherIssueId', targetissueid: 'otherIssueId',
  type: 'linkType', link: 'linkType',
  prefix: 'textPrefix', checked: 'done', title: 'summary', body: 'description',
};

/**
 * Null when every argument is one the tool declares; otherwise a refusal
 * to return as the tool's result. `schema` is the tool's own inputSchema,
 * so the accepted names cannot drift from the declared ones. `alsoAllowed`
 * names aliases a tool handles itself. A name starting with "_" is
 * transport metadata, not a caller's argument, and is let through.
 */
function refuseUnknown(given, schema, alsoAllowed) {
  const accepted = Object.keys((schema && schema.properties) || {});
  const allowed = accepted.concat(alsoAllowed || []);
  const unknown = Object.keys(given || {}).filter((name) =>
    name.charAt(0) !== '_' && allowed.indexOf(name) === -1);
  if (!unknown.length) return null;

  const hints = [];
  unknown.forEach((name) => {
    const meant = MEANT[name.toLowerCase()];
    if (meant && accepted.indexOf(meant) !== -1) hints.push('"' + name + '" is probably ' + meant);
  });
  return {
    error: 'Unrecognised argument' + (unknown.length > 1 ? 's' : '') + ': ' + unknown.join(', ') + '. This tool takes ' +
      (accepted.length ? accepted.join(', ') : 'no arguments') + '.' +
      (hints.length ? ' ' + hints.join('; ') + '.' : '') +
      ' Nothing was done: an argument that is not understood is never guessed at, because the fallback is your focused story, which may be in another project.',
    unrecognised: unknown,
    accepted: accepted,
  };
}

exports.refuseUnknown = refuseUnknown;
