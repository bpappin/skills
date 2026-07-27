const assert = require('node:assert');
const test = require('node:test');
const parser = require('../app/ac-parser');

const SAMPLE = `As a user I want offline sync so that edits survive flaky networks.

## Acceptance Criteria
- [ ] Edits made offline are queued locally
- [x] Queue drains automatically on reconnect
- [ ] Conflicts surface a merge dialog

## References
- docs/prd/offline-sync.md
- docs/adr/0007-conflict-strategy.md

## QA
Feature: offline queue
  Scenario: reconnect drains queue
    Given queued edits exist
    When the network reconnects
    Then the queue drains within 30s
`;

test('parses AC items with state', () => {
  const p = parser.parse(SAMPLE);
  assert.equal(p.hasAcSection, true);
  assert.equal(p.ac.length, 3);
  assert.deepEqual(p.ac[1], { index: 1, text: 'Queue drains automatically on reconnect', done: true });
});

test('parses references and QA presence', () => {
  const p = parser.parse(SAMPLE);
  assert.deepEqual(p.references, ['docs/prd/offline-sync.md', 'docs/adr/0007-conflict-strategy.md']);
  assert.equal(p.qaSectionPresent, true);
});

test('handles missing sections', () => {
  const p = parser.parse('Just a plain description.');
  assert.equal(p.hasAcSection, false);
  assert.deepEqual(p.ac, []);
  assert.equal(p.qaSectionPresent, false);
});

test('handles empty/null description', () => {
  assert.equal(parser.parse('').hasAcSection, false);
  assert.equal(parser.parse(null).hasAcSection, false);
});

test('setItem toggles with matching prefix', () => {
  const r = parser.setItem(SAMPLE, 0, 'Edits made offline', true);
  assert.equal(r.error, undefined);
  assert.equal(r.ac[0].done, true);
  assert.match(r.description, /- \[x\] Edits made offline are queued locally/);
  // rest of document untouched
  assert.match(r.description, /## QA/);
});

test('setItem refuses on prefix mismatch', () => {
  const r = parser.setItem(SAMPLE, 0, 'Completely different text', true);
  assert.match(r.error, /does not start with/);
});

test('setItem refuses out-of-range index', () => {
  const r = parser.setItem(SAMPLE, 9, 'x', true);
  assert.match(r.error, /out of range/);
});

test('setItem prefix match is case-insensitive', () => {
  const r = parser.setItem(SAMPLE, 2, 'conflicts SURFACE', true);
  assert.equal(r.error, undefined);
  assert.equal(r.ac[2].done, true);
});

test('addItem appends after last item', () => {
  const r = parser.addItem(SAMPLE, 'New criterion');
  assert.equal(r.ac.length, 4);
  assert.equal(r.ac[3].text, 'New criterion');
  const lines = r.description.split('\n');
  const idx = lines.findIndex((l) => l.includes('New criterion'));
  assert.match(lines[idx - 1], /Conflicts surface a merge dialog/);
});

test('addItem creates section when missing', () => {
  const r = parser.addItem('Plain story.', 'First AC');
  assert.equal(r.ac.length, 1);
  assert.match(r.description, /## Acceptance Criteria\n- \[ \] First AC/);
});

test('addItem on empty description', () => {
  const r = parser.addItem('', 'Only AC');
  assert.match(r.description, /^## Acceptance Criteria\n- \[ \] Only AC$/);
});

test('CRLF descriptions parse', () => {
  const crlf = 'Story\r\n\r\n## Acceptance Criteria\r\n- [ ] Item one\r\n';
  const p = parser.parse(crlf);
  assert.equal(p.ac.length, 1);
  assert.equal(p.ac[0].text, 'Item one');
});

test('AC section bounded by next heading', () => {
  const doc = '## Acceptance Criteria\n- [ ] Real AC\n## Notes\n- [ ] Not an AC, just a task note\n';
  const p = parser.parse(doc);
  assert.equal(p.ac.length, 1);
});
