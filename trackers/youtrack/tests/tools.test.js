const assert = require('node:assert');
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');

// The tools import the tracker's scripting API, which exists only inside
// the tracker. Stand a small one in its place so each tool file loads and
// its execute() runs here: two projects, an issue in each, and a focus
// that points at the OTHER project - the arrangement that goes wrong.
const projects = {
  AAA: { key: 'AAA', fields: [{ name: 'Subsystem', values: [{ name: 'Alpha One' }, { name: 'Alpha Two' }] }] },
  BBB: { key: 'BBB', fields: [{ name: 'Subsystem', values: [{ name: 'Beta One' }] }] },
};
const issues = {
  'AAA-1': { id: 'AAA-1', project: projects.AAA, description: '', links: {}, tags: [] },
  'BBB-7': { id: 'BBB-7', project: projects.BBB, description: '', links: {}, tags: [] },
};
const fakeEntities = {
  Project: { findByKey: (k) => projects[k] || null },
  Issue: { findById: (id) => issues[id] || null },
  User: { current: { login: 'agent', extensionProperties: { focusIssueId: 'BBB-7', focusProject: 'BBB' } } },
};
const realLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === '@jetbrains/youtrack-scripting-api/entities') return fakeEntities;
  return realLoad.call(this, request, ...rest);
};

const APP = path.join(__dirname, '..', 'app');
const tools = fs.readdirSync(APP)
  .filter((f) => f.endsWith('.js'))
  .map((f) => ({ file: f, mod: require(path.join(APP, f)) }))
  .filter((t) => t.mod.aiTool);

test('every tool file was found', () => {
  assert.ok(tools.length >= 11, 'found ' + tools.length);
});

for (const { file, mod } of tools) {
  test(file + ' refuses an argument name it does not declare', () => {
    const r = mod.aiTool.execute({ arguments: { noSuchArgument: 'x' }, settings: {} });
    assert.ok(r && r.error, 'no refusal from ' + file);
    assert.match(r.error, /Unrecognised argument: noSuchArgument/);
    assert.deepEqual(r.accepted, Object.keys(mod.aiTool.inputSchema.properties || {}));
  });
}

const dims = require(path.join(APP, 'project-dimensions.js')).aiTool;
const ask = (a) => dims.execute({ arguments: a, settings: {} });

test('dimensions answers for the project named, whatever is focused', () => {
  const r = ask({ projectKey: 'AAA' });
  assert.equal(r.project, 'AAA');
  assert.equal(r.resolvedFrom, 'projectKey');
  assert.deepEqual(r.dimensions.Subsystem, ['Alpha One', 'Alpha Two']);
});

test('dimensions takes "project" as another name for projectKey', () => {
  const r = ask({ project: 'AAA' });
  assert.equal(r.project, 'AAA');
  assert.deepEqual(r.dimensions.Subsystem, ['Alpha One', 'Alpha Two']);
});

test('dimensions takes the project from an issue', () => {
  const r = ask({ issueId: 'AAA-1' });
  assert.equal(r.project, 'AAA');
  assert.equal(r.resolvedFrom, 'issueId');
});

test('dimensions never falls back to the focused story', () => {
  const r = ask({});
  assert.match(r.error, /Name the project/);
  assert.equal(r.project, undefined);
  assert.equal(r.dimensions, undefined);
});

test('dimensions refuses a project it cannot find, and names that disagree', () => {
  assert.match(ask({ projectKey: 'ZZZ' }).error, /Project ZZZ not found/);
  assert.match(ask({ projectKey: 'AAA', project: 'BBB' }).error, /name different projects/);
  assert.match(ask({ projectKey: 'AAA', issueId: 'BBB-7' }).error, /BBB-7 is in project BBB, not AAA/);
  assert.equal(ask({ projectKey: 'AAA', issueId: 'AAA-1' }).project, 'AAA');
});

test('the refusal says which name was probably meant', () => {
  const ctx = require(path.join(APP, 'get-story-context.js')).aiTool;
  const r = ctx.execute({ arguments: { issue: 'AAA-1' }, settings: {} });
  assert.match(r.error, /"issue" is probably issueId/);
  assert.match(r.error, /Nothing was done/);
});
