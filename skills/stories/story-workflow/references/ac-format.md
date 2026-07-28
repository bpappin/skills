# Story Format Contract

This is the exact format `app/ac-parser.js` parses. Every story_* tool and
every human editing a story description relies on it.

```markdown
<free-form story narrative — user story phrasing encouraged>

## Acceptance Criteria
- [ ] Verifiable outcome one
- [x] Verifiable outcome two (done)

## References
- EVO-A-41 Some Feature (KB article; mirror file docs/knowledge/**/EVO-A-41_*.md)
- EVO-A-17 ADR-0007 Conflict Strategy

## QA
Feature: <name>
  Scenario: <name>
    Given ...
    When ...
    Then ...
```

Rules:

- Section headings are level-2 (`##`), matched case-insensitively; a section
  runs until the next `##` heading or end of description.
- AC items are markdown task-list entries (`- [ ]` / `- [x]`, `*` also
  accepted). YouTrack renders them as clickable checkboxes, so humans and
  tools share one surface.
- Item identity for updates is index + text prefix. Tools refuse a toggle
  when the prefix doesn't match the item at that index (drift guard against
  concurrent human edits).
- `## References` is optional: one path/link per line, ADRs and PRDs by repo
  path so any agent can open them.
- `## QA` is optional Gherkin. Required at completion only when the story is
  tagged `needs-gherkin`.
- Everything outside these sections is untouched by the tools.
