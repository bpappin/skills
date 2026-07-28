const assert = require('node:assert');
const test = require('node:test');
const path = require('node:path');

test('story-lib VERSION matches manifest.json', () => {
  const manifest = require(path.join(__dirname, '..', 'app', 'manifest.json'));
  const libSrc = require('node:fs').readFileSync(path.join(__dirname, '..', 'app', 'story-lib.js'), 'utf8');
  const m = libSrc.match(/const VERSION = '([^']+)'/);
  assert.ok(m, 'VERSION const present in story-lib.js');
  assert.strictEqual(m[1], manifest.version);
});
