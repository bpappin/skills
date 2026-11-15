/**
 * Linking two issues, written so the direction cannot be misread.
 *
 * Every function here takes a link as a sentence: SUBJECT, LINK TYPE,
 * OBJECT - "PROJ-2 subtask of PROJ-1". The link type is the name as it
 * reads from the subject's side, which is how the subject's issue page
 * shows it. The tracker's built-in link tool takes the same three things
 * under names that read the other way round, and agents following those
 * names produced reversed links over and over; hence a sentence, and a
 * read-back in every result.
 *
 * No scripting-API import: the tools pass real issues, the tests pass
 * fakes, and the logic is the same for both.
 */

/** The ids on the far side of one link type, as read from `issue`. */
function idsIn(set) {
  const out = [];
  if (set) set.forEach((l) => out.push(l.id));
  return out;
}

/**
 * The set of issues `issue` reaches by `linkType`, or null when the
 * project has no link type that reads that way. The name is tried as
 * given and then in lower case, since the stock names are lower case and
 * a caller copying one from prose may not be.
 */
function linkSet(issue, linkType) {
  const wanted = String(linkType || '').trim().replace(/\s+/g, ' ');
  if (!wanted) return null;
  const names = wanted === wanted.toLowerCase() ? [wanted] : [wanted, wanted.toLowerCase()];
  for (let i = 0; i < names.length; i++) {
    try {
      const set = issue.links[names[i]];
      if (set) return { set, name: names[i] };
    } catch (e) {
      // not a link type here - try the next spelling
    }
  }
  return null;
}

function sentence(issue, name, other) {
  return issue.id + ' ' + name + ' ' + other.id;
}

function unknownType(issue, linkType) {
  return {
    error: 'No link type reads "' + linkType + '" from ' + issue.id + '. Use the name exactly as the issue page shows it ' +
      'from that issue\'s side - "subtask of", "parent for", "depends on", "is required for", "duplicates", "relates to" - ' +
      'and nothing was changed.',
  };
}

/** True when `other` already reaches `issue` by the same directed name. */
function reverseHolds(issue, name, other) {
  const back = linkSet(other, name);
  return !!back && idsIn(back.set).indexOf(issue.id) !== -1;
}

/**
 * Make "issue <linkType> other" true. Idempotent: a link that already
 * holds is reported, not duplicated. Refuses when the same link already
 * holds the other way round, because a directed link in both directions
 * is what a mistaken call followed by its correction leaves behind - the
 * mistaken one has to be removed first, and the caller is told how.
 */
function link(issue, linkType, other) {
  if (issue.id === other.id) {
    return { error: 'An issue cannot be linked to itself (' + issue.id + '). Nothing was changed.' };
  }
  const found = linkSet(issue, linkType);
  if (!found) return unknownType(issue, linkType);
  const name = found.name;
  const said = sentence(issue, name, other);

  if (idsIn(found.set).indexOf(other.id) !== -1) {
    return {
      linked: true, alreadyLinked: true, verified: true, sentence: said,
      issueId: issue.id, linkType: name, otherIssueId: other.id,
      message: 'Already true: ' + said + '. Nothing was changed.',
    };
  }
  if (reverseHolds(issue, name, other)) {
    return {
      error: 'The reverse already holds: ' + sentence(other, name, issue) + '. Both cannot be meant. If that one is the mistake, ' +
        'remove it with story_unlink(issueId=' + other.id + ', linkType="' + name + '", otherIssueId=' + issue.id + ') and call this again. ' +
        'Nothing was changed.',
      reverseExists: true,
    };
  }

  found.set.add(other);

  // Read it back from the issue rather than trusting the call.
  const after = linkSet(issue, name);
  const verified = !!after && idsIn(after.set).indexOf(other.id) !== -1;
  return {
    linked: verified, alreadyLinked: false, verified: verified, sentence: said,
    issueId: issue.id, linkType: name, otherIssueId: other.id,
    message: verified
      ? 'Linked: ' + said + '.'
      : 'Asked for "' + said + '" but it does not read back from ' + issue.id + '. Check with get_issue before relying on it.',
  };
}

/**
 * Make "issue <linkType> other" false. When that link does not hold but
 * its reverse does, says so and gives the call that would remove it: the
 * usual reason to be here is a link that went in backwards.
 */
function unlink(issue, linkType, other) {
  const found = linkSet(issue, linkType);
  if (!found) return unknownType(issue, linkType);
  const name = found.name;
  const said = sentence(issue, name, other);

  if (idsIn(found.set).indexOf(other.id) === -1) {
    if (reverseHolds(issue, name, other)) {
      return {
        error: 'Not linked that way round: what holds is ' + sentence(other, name, issue) + '. To remove that, call ' +
          'story_unlink(issueId=' + other.id + ', linkType="' + name + '", otherIssueId=' + issue.id + '). Nothing was changed.',
        reverseExists: true,
      };
    }
    return { error: 'There is no link "' + said + '" to remove. Nothing was changed.', reverseExists: false };
  }

  found.set.delete(other);

  const after = linkSet(issue, name);
  const verified = !after || idsIn(after.set).indexOf(other.id) === -1;
  return {
    unlinked: verified, verified: verified, sentence: said,
    issueId: issue.id, linkType: name, otherIssueId: other.id,
    message: verified
      ? 'Removed: ' + said + '.'
      : 'Asked to remove "' + said + '" but it still reads back from ' + issue.id + '. Check with get_issue.',
  };
}

exports.idsIn = idsIn;
exports.linkSet = linkSet;
exports.link = link;
exports.unlink = unlink;
