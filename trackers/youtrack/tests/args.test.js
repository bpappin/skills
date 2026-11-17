const assert = require('node:assert');
const test = require('node:test');
const args = require('../app/args');

const SCHEMA = { type: 'object', properties: { projectKey: { type: 'string' }, issueId: { type: 'string' } } };

test('declared arguments pass', () => {
  assert.equal(args.refuseUnknown({ projectKey: 'PROJ' }, SCHEMA), null);
  assert.equal(args.refuseUnknown({}, SCHEMA), null);
  assert.equal(args.refuseUnknown(undefined, SCHEMA), null);
});

test('an undeclared argument is refused, with the names the tool takes', () => {
  const r = args.refuseUnknown({ project: 'PROJ' }, SCHEMA);
  assert.deepEqual(r.unrecognised, ['project']);
  assert.deepEqual(r.accepted, ['projectKey', 'issueId']);
  assert.match(r.error, /This tool takes projectKey, issueId\./);
  assert.match(r.error, /"project" is probably projectKey/);
});

test('no hint is offered for a name the tool could not have meant', () => {
  const r = args.refuseUnknown({ colour: 'red', id: 'PROJ-1' }, SCHEMA);
  assert.deepEqual(r.unrecognised, ['colour', 'id']);
  assert.match(r.error, /Unrecognised arguments: colour, id/);
  assert.match(r.error, /"id" is probably issueId/);
  assert.doesNotMatch(r.error, /"colour" is probably/);
});

test('an alias the tool handles itself, and transport metadata, pass', () => {
  assert.equal(args.refuseUnknown({ project: 'PROJ' }, SCHEMA, ['project']), null);
  assert.equal(args.refuseUnknown({ _meta: {} }, SCHEMA), null);
});

test('a tool with no arguments says so', () => {
  const r = args.refuseUnknown({ projectKey: 'PROJ' }, { type: 'object', properties: {} });
  assert.match(r.error, /This tool takes no arguments\./);
});
