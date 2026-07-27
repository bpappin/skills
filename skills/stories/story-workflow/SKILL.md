---
name: story-workflow
description: Work a tracker story with strict scope discipline - focus one story, treat its acceptance-criteria checklist as the scope, route discovered work to new linked issues, and gate completion. Tracker-agnostic via per-tracker bindings (YouTrack today; GitHub/Jira later). Use whenever starting development work, picking up a ticket, resuming a task, checking off acceptance criteria, completing a story, or when new work is discovered mid-task. Triggers - "work on", "pick up", "resume", "what am I working on", "start the next story", "is this done", issue IDs like PROJ-123 or #123.
license: MIT
compatibility: Requires a connection to the project's issue tracker (see the tracker binding for specifics; YouTrack needs MCP, Cloud or Server 2025.3+)
metadata:
  author: bpappin
  version: "0.4"
---

# Story Workflow

The tracker owns stories and acceptance criteria; ADRs/PRDs are repo docs.
The AC list of the focused story IS the scope of the current session. This
file defines the workflow in tracker-neutral operations; a binding file
maps each operation to the concrete tools of the tracker in use.

## Tracker dispatch — do this first

Read `.agents/config/story-tools.json` in the project. `tracker.type`
selects the binding (absent → `youtrack`); the rest of the `tracker` object
carries connection facts (server name, URL, project key). Load the matching
binding and use ONLY its tools:

- `youtrack` → [references/tracker-youtrack.md](references/tracker-youtrack.md)

A developer may have several trackers/instances configured — always use the
one this project's config names, never another.

## The operations

| Operation | Meaning |
|---|---|
| `focus.get` / `focus.set` | Which story is this session working on |
| `story.context` | Full briefing: narrative, AC list + state, links, references |
| `ac.toggle` | Check/uncheck one AC item (verifiably complete only) |
| `ac.add` | Expand scope — explicit user approval only |
| `work.discovered` | Log out-of-scope work as a NEW linked issue |
| `story.completeCheck` | Verdict: all AC done? QA required and present? |

The story format is the same everywhere (see
[references/ac-format.md](references/ac-format.md)): a `## Acceptance
Criteria` markdown task list in the issue body, optional `## References`
(ADR/PRD paths) and `## QA` (Gherkin).

## Session start

1. `focus.get` — if a story is focused, confirm it with the user; if not,
   ask which story to work, then `focus.set`.
2. `story.context` — read the AC list and open `## References` docs before
   writing any code.
3. Restate scope to the user in one line: the unchecked AC items.

## While working

- Work only toward unchecked AC items.
- When an item is verifiably complete (tests pass, behavior confirmed),
  immediately `ac.toggle` it. Never batch-check items at session end.
- **Discovered work reflex**: any bug, refactor need, idea, or missing
  feature that does not serve an unchecked AC item → `work.discovered`
  (summary + description) → tell the user in one sentence → continue the
  focused story. Do not fix it inline, do not expand scope silently. This
  includes "quick wins" and "while we're here" fixes.
- `ac.add` is allowed only when the user explicitly asks to widen this
  story's scope. When in doubt, offer `work.discovered` first.

## Completing

1. `story.completeCheck` — if not ready, work through what it reports; do
   not declare the story done.
2. If QA is required and missing, write Gherkin scenarios for the verified
   behavior into a `## QA` section
   ([references/ac-format.md](references/ac-format.md)).
3. When ready: confirm with the user, then move the story's state using the
   binding's state tool. Mention any open discovered-work issues.

## Read-only mode

The project is read-only when the config has `"readOnly": true`, or when a
write operation is refused server-side. In that mode: never call write
operations; track AC progress and discovered work in session notes; at
checkpoints hand the user a concise change list (AC items to check,
discovered issues to file in canonical format). Reads — and focus, where
the binding marks it safe — remain allowed.

## Guardrails

- One focused story per session; changing focus requires the user's
  explicit request.
- If `ac.toggle` is refused for drift, re-read `story.context` and retry
  against the current list.
- A story with no `## Acceptance Criteria` section: stop and draft AC with
  the user before writing code.
- **Never ask for or accept tokens, credentials, or connection secrets in
  conversation** — many organizations rightly prohibit it. All
  configuration, especially secrets, is entered only through the
  story-tools installer. Missing/invalid credentials → "run `install.sh`",
  never "paste your token here".
- Background reading: [references/methodology.md](references/methodology.md)
  — the lifecycle, why the off-ramp matters, where BDD fits, writing good AC.
