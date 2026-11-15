const assert = require('node:assert');
const test = require('node:test');
const links = require('../app/link-lib');

// A tracker small enough to read: two directed link types and one that
// reads the same from both sides. Adding to one side shows on the other
// under the opposite name, as it does in the real one.
const OPPOSITE = {
  'subtask of': 'parent for', 'parent for': 'subtask of',
  'depends on': 'is required for', 'is required for': 'depends on',
  'relates to': 'relates to',
};

function tracker() {
  const issues = {};
  function side(owner, name) {
    const held = [];
    return {
      held,
      forEach: (fn) => held.slice().forEach(fn),
      add: (other) => {
        if (held.indexOf(other) === -1) held.push(other);
        const back = other.links[OPPOSITE[name]].held;
        if (back.indexOf(owner) === -1) back.push(owner);
      },
      delete: (other) => {
        const at = held.indexOf(other);
        if (at !== -1) held.splice(at, 1);
        const back = other.links[OPPOSITE[name]].held;
        const there = back.indexOf(owner);
        if (there !== -1) back.splice(there, 1);
      },
    };
  }
  return (id) => {
    if (!issues[id]) {
      const issue = { id, links: {} };
      Object.keys(OPPOSITE).forEach((name) => { issue.links[name] = side(issue, name); });
      issues[id] = issue;
    }
    return issues[id];
  };
}

const ids = (issue, name) => links.idsIn(issue.links[name]);

test('a link reads as the sentence it was given', () => {
  const at = tracker();
  const child = at('PROJ-2'), parent = at('PROJ-1');
  const r = links.link(child, 'subtask of', parent);
  assert.equal(r.linked, true);
  assert.equal(r.verified, true);
  assert.equal(r.sentence, 'PROJ-2 subtask of PROJ-1');
  assert.deepEqual(ids(child, 'subtask of'), ['PROJ-1']);
  assert.deepEqual(ids(parent, 'parent for'), ['PROJ-2']);
  assert.deepEqual(ids(parent, 'subtask of'), []);
});

test('the blocked issue is the subject of "depends on"', () => {
  const at = tracker();
  const blocked = at('PROJ-3'), blocker = at('PROJ-4');
  links.link(blocked, 'depends on', blocker);
  assert.deepEqual(ids(blocked, 'depends on'), ['PROJ-4']);
  assert.deepEqual(ids(blocker, 'depends on'), []);
});

test('linking twice changes nothing and says so', () => {
  const at = tracker();
  links.link(at('PROJ-2'), 'subtask of', at('PROJ-1'));
  const again = links.link(at('PROJ-2'), 'subtask of', at('PROJ-1'));
  assert.equal(again.alreadyLinked, true);
  assert.deepEqual(ids(at('PROJ-2'), 'subtask of'), ['PROJ-1']);
});

test('a link that holds the other way round is refused, with the repair', () => {
  const at = tracker();
  links.link(at('PROJ-1'), 'subtask of', at('PROJ-2')); // the mistake
  const r = links.link(at('PROJ-2'), 'subtask of', at('PROJ-1'));
  assert.equal(r.reverseExists, true);
  assert.match(r.error, /story_unlink\(issueId=PROJ-1, linkType="subtask of", otherIssueId=PROJ-2\)/);
  assert.deepEqual(ids(at('PROJ-2'), 'subtask of'), []);
});

test('the repair it names works, and the link then goes in', () => {
  const at = tracker();
  links.link(at('PROJ-1'), 'subtask of', at('PROJ-2'));
  const gone = links.unlink(at('PROJ-1'), 'subtask of', at('PROJ-2'));
  assert.equal(gone.unlinked, true);
  assert.equal(links.link(at('PROJ-2'), 'subtask of', at('PROJ-1')).linked, true);
  assert.deepEqual(ids(at('PROJ-1'), 'parent for'), ['PROJ-2']);
  assert.deepEqual(ids(at('PROJ-1'), 'subtask of'), []);
});

test('unlinking the wrong way round removes nothing and says which way holds', () => {
  const at = tracker();
  links.link(at('PROJ-2'), 'subtask of', at('PROJ-1'));
  const r = links.unlink(at('PROJ-1'), 'subtask of', at('PROJ-2'));
  assert.equal(r.reverseExists, true);
  assert.match(r.error, /PROJ-2 subtask of PROJ-1/);
  assert.deepEqual(ids(at('PROJ-2'), 'subtask of'), ['PROJ-1']);
});

test('unlinking what is not linked is an error, not a silent success', () => {
  const at = tracker();
  const r = links.unlink(at('PROJ-2'), 'depends on', at('PROJ-1'));
  assert.ok(r.error);
  assert.equal(r.reverseExists, false);
});

test('a link type that reads the same both ways is one link, not two', () => {
  const at = tracker();
  links.link(at('PROJ-5'), 'relates to', at('PROJ-6'));
  const back = links.link(at('PROJ-6'), 'relates to', at('PROJ-5'));
  assert.equal(back.alreadyLinked, true);
  assert.equal(links.unlink(at('PROJ-6'), 'relates to', at('PROJ-5')).unlinked, true);
  assert.deepEqual(ids(at('PROJ-5'), 'relates to'), []);
});

test('an unknown link type and a self-link change nothing', () => {
  const at = tracker();
  assert.match(links.link(at('PROJ-2'), 'child of', at('PROJ-1')).error, /No link type reads "child of"/);
  assert.match(links.link(at('PROJ-2'), '  ', at('PROJ-1')).error, /No link type/);
  assert.match(links.link(at('PROJ-2'), 'subtask of', at('PROJ-2')).error, /cannot be linked to itself/);
  assert.deepEqual(ids(at('PROJ-2'), 'subtask of'), []);
});

test('the name is matched as written, then in lower case', () => {
  const at = tracker();
  const r = links.link(at('PROJ-2'), 'Subtask  Of', at('PROJ-1'));
  assert.equal(r.linkType, 'subtask of');
  assert.equal(r.sentence, 'PROJ-2 subtask of PROJ-1');
});

test('a link that does not read back is reported as unverified', () => {
  const stuck = { forEach: () => {}, add: () => {}, delete: () => {} };
  const a = { id: 'PROJ-7', links: { 'depends on': stuck } };
  const b = { id: 'PROJ-8', links: { 'depends on': stuck } };
  const r = links.link(a, 'depends on', b);
  assert.equal(r.linked, false);
  assert.equal(r.verified, false);
  assert.match(r.message, /does not read back/);
});
