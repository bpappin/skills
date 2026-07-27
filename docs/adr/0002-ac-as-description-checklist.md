# ADR-0002: AC stored as a markdown task list in the issue description

Date: 2026-07-26 · Status: accepted

## Context

Acceptance criteria need to be readable and editable by humans in the
YouTrack UI *and* parseable/updatable by tools from workflow JS. Candidates:
child subtask issues, a custom field, or a structured section in the
description.

## Decision

AC lives in a `## Acceptance Criteria` markdown task list inside the story
description (format contract: docs/ac-format.md). YouTrack renders task
lists as clickable checkboxes, so the human surface and the machine surface
are the same text.

## Alternatives rejected

- Child subtasks: N issues per story pollutes boards and search, and every
  AC read/toggle becomes an extra round-trip; heavyweight for solo/small-team
  flow.
- Custom field: cannot cleanly hold per-item text + checked state; invisible
  in the description where the story is actually read.

## Consequences

- Read-modify-write on the description can race a concurrent human edit.
  Mitigation: toggles must match index + text prefix and refuse on drift
  (`ac-parser.setItem`); acceptable risk at this team size.
- The section format is a contract; docs/ac-format.md is the spec and
  `tests/ac-parser.test.js` pins the behavior.
