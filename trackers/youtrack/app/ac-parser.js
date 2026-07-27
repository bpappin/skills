/**
 * Parser for the canonical story format (see docs/ac-format.md).
 *
 * Sections recognized in an issue description:
 *   ## Acceptance Criteria   — markdown task list, the canonical AC
 *   ## References            — optional ADR/PRD paths and doc links
 *   ## QA                    — optional Gherkin scenarios
 *
 * Runs both in YouTrack's workflow JS sandbox and plain node (for tests),
 * so it uses only language features, no host APIs.
 */

const AC_HEADING = /^##\s+acceptance criteria\s*$/i;
const REF_HEADING = /^##\s+references\s*$/i;
const QA_HEADING = /^##\s+qa\s*$/i;
const ANY_HEADING = /^##\s+/;
const TASK_ITEM = /^\s*[-*]\s+\[([ xX])\]\s+(.*)$/;

function splitLines(description) {
  return (description || '').split(/\r?\n/);
}

function sectionRange(lines, headingRe) {
  let start = -1;
  for (let i = 0; i < lines.length; i++) {
    if (headingRe.test(lines[i])) { start = i; break; }
  }
  if (start === -1) return null;
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) {
    if (ANY_HEADING.test(lines[i])) { end = i; break; }
  }
  return { start, end };
}

function parse(description) {
  const lines = splitLines(description);
  const acRange = sectionRange(lines, AC_HEADING);
  const refRange = sectionRange(lines, REF_HEADING);
  const qaRange = sectionRange(lines, QA_HEADING);

  const ac = [];
  if (acRange) {
    for (let i = acRange.start + 1; i < acRange.end; i++) {
      const m = lines[i].match(TASK_ITEM);
      if (m) {
        ac.push({
          index: ac.length,
          text: m[2].trim(),
          done: m[1].toLowerCase() === 'x',
          line: i,
        });
      }
    }
  }

  const references = [];
  if (refRange) {
    for (let i = refRange.start + 1; i < refRange.end; i++) {
      const t = lines[i].replace(/^\s*[-*]\s+/, '').trim();
      if (t) references.push(t);
    }
  }

  const qaText = qaRange
    ? lines.slice(qaRange.start + 1, qaRange.end).join('\n').trim()
    : null;

  return {
    hasAcSection: !!acRange,
    ac: ac.map(({ index, text, done }) => ({ index, text, done })),
    references,
    qaSectionPresent: !!qaRange && !!qaText,
    _lines: lines,
    _acLineNumbers: ac.map((item) => item.line),
  };
}

/**
 * Toggle one AC item. textPrefix guards against index drift when a human
 * edited the description between the agent's read and this write.
 */
function setItem(description, index, textPrefix, done) {
  const parsed = parse(description);
  if (!parsed.hasAcSection) {
    return { error: 'No "## Acceptance Criteria" section found.', ac: [] };
  }
  if (index < 0 || index >= parsed.ac.length) {
    return { error: 'AC index ' + index + ' out of range (0..' + (parsed.ac.length - 1) + ').', ac: parsed.ac };
  }
  const item = parsed.ac[index];
  const prefix = (textPrefix || '').trim().toLowerCase();
  if (prefix && !item.text.toLowerCase().startsWith(prefix)) {
    return {
      error: 'AC item at index ' + index + ' is "' + item.text + '", which does not start with "' + textPrefix + '". The list may have changed - re-read it and retry.',
      ac: parsed.ac,
    };
  }
  const lines = parsed._lines.slice();
  const lineNo = parsed._acLineNumbers[index];
  lines[lineNo] = lines[lineNo].replace(/\[([ xX])\]/, done ? '[x]' : '[ ]');
  const updated = lines.join('\n');
  return { description: updated, ac: parse(updated).ac };
}

/** Append an AC item, creating the section if it doesn't exist. */
function addItem(description, text) {
  const lines = splitLines(description);
  const acRange = sectionRange(lines, AC_HEADING);
  const entry = '- [ ] ' + text.trim();

  if (!acRange) {
    const base = (description || '').replace(/\s+$/, '');
    const updated = (base ? base + '\n\n' : '') + '## Acceptance Criteria\n' + entry;
    return { description: updated, ac: parse(updated).ac };
  }

  // insert after the last task item in the section, or right after the heading
  let insertAt = acRange.start + 1;
  for (let i = acRange.start + 1; i < acRange.end; i++) {
    if (TASK_ITEM.test(lines[i])) insertAt = i + 1;
  }
  lines.splice(insertAt, 0, entry);
  const updated = lines.join('\n');
  return { description: updated, ac: parse(updated).ac };
}

exports.parse = parse;
exports.setItem = setItem;
exports.addItem = addItem;
