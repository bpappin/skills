---
name: story-workflow
description: Work a tracker story with strict scope discipline - focus one story, treat its acceptance-criteria checklist as the scope, route discovered work to new linked issues, and gate completion. Tracker-agnostic via per-tracker bindings (YouTrack and GitHub today; Jira later). Use whenever starting development work, picking up a ticket, resuming a task, checking off acceptance criteria, completing a story, or when new work is discovered mid-task. Triggers - "work on", "pick up", "resume", "what am I working on", "start the next story", "is this done", issue IDs like PROJ-123 or #123.
license: MIT
compatibility: Requires a connection to the project's issue tracker (see the tracker binding for specifics; YouTrack needs MCP, Cloud or Server 2025.3+)
metadata:
  author: bpappin
  version: "1.9"
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
- `github` → [references/tracker-github.md](references/tracker-github.md)

A developer may have several trackers/instances configured — always use the
one this project's config names, never another.

If the binding's tools are unavailable (no MCP connection on this machine,
server unreachable) or the user asks to work disconnected, fall back to
**offline mode** — [references/offline.md](references/offline.md): the same
operations, recorded in a local worklog and replayed later via
story-reconcile. Point the user at the installer once, confirm, then work.

## The operations

| Operation | Meaning |
|---|---|
| `focus.get` / `focus.set` | Which story is this session working on |
| `story.context` | Full briefing: narrative, AC list + state, links, references |
| `ac.toggle` | Check/uncheck one AC item (verifiably complete only) |
| `ac.add` | Expand scope — explicit user approval only |
| `work.discovered` | Log out-of-scope work as a NEW linked issue |
| `story.completeCheck` | Verdict: all AC done? QA required and present? |
| `work.logTime` | Record human-approved session time on a story |
| `story.next` | Pick the next story: highest priority, ready first |

The story format is the same everywhere (see
[references/ac-format.md](references/ac-format.md)): a `## Acceptance
Criteria` markdown task list in the issue body, optional `## References`
(ADR/PRD paths) and `## QA` (Gherkin).

## Session start

1. Note the current time — this is the session's start for time logging.
2. `focus.get` — if a story is focused, confirm it with the user; if not,
   ask which story to work ("start the next story" → `story.next`: the
   highest-priority ready story), then `focus.set`.
3. `story.context` — read the AC list and open `## References` docs before
   writing any code. The context includes priority and tags — the tags tell
   you what this story groups with.
4. Restate scope to the user in one line: the unchecked AC items.
5. Move the story onto the board: set Stage to the project's in-progress
   column (e.g. "Develop") using the binding's state tool — announce it in
   the scope line, don't ask. Read the actual column names from the
   project's dimensions; never invent one. Already in progress → no-op.
   Leave State alone — it records how the story resolves, not where it is.

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

## Session time

Sessions are the unit of time tracking: the user is either working or not,
and they decide which. At session close (completion, handoff, housekeeping,
or "I'm done"), compute end minus session start, round to the nearest 15
minutes, and propose ONE entry: "This session was about 2h - log it on
PROJ-123?" On approval, `work.logTime`. If several stories shared the
session, propose logging it on the one that got most of the time; offer a
coarse split only when it was genuinely even. Rules:

- **Never log time silently** - every entry is a number the user approved.
- Gaps inside a session are work (thinking counts); don't subtract them.
- An absurd computed number (unclosed session overnight) → ask what the
  session actually took and log that.
- "Log 30m on PROJ-123" from the user at any moment → `work.logTime`
  directly, no proposal needed.

## Priority and tags

- Priority is read from context, set by triage/planning. Never change a
  story's priority on your own; suggest a change to the user instead.
- Topical tags are Title Case, human-readable ("Trust Insights", not
  "trust-insights") and mark feature-level grouping. Component ownership
  belongs in the Subsystem field (shown in context) - never duplicate
  subsystem names as tags.
- **Human-added tags are data.** A tag you don't recognize is someone's
  grouping, not clutter - never remove or rename tags on your own
  initiative. Adding, removing, or merging tags at the user's direction
  is fine, and you may propose a tidy-up you've noticed; execute only
  what they approve.
  Release membership is the Fix versions field (shown in context), never a
  tag. Reserved workflow tags (`ready-for-agent`, `needs-gherkin`,
  `discovered`, `triaged`, triage roles) are machinery - never repurpose
  them.
- Discovered work inherits the story's topical tags automatically and lands
  at default priority - urgency is a triage decision, never copied from the
  current story.

## Completing

1. `story.completeCheck` — if not ready, work through what it reports; do
   not declare the story done.
2. If QA is required and missing, write Gherkin scenarios for the verified
   behavior into a `## QA` section
   ([references/ac-format.md](references/ac-format.md)).
3. When ready: confirm with the user, then move the story using the
   binding's state tool. Where the board has a testing/review column
   (e.g. "Testing", "Review"), Stage goes THERE, not to done — completion
   by the implementer means ready-for-verification; a human (or the QA
   pass) moves it to done. Only boards without a review column go
   straight to the done column. Where the project separates flow from
   resolution (a Stage field AND a State field), also set State to how it
   concluded (usually Fixed) — the story can sit in Testing with State
   Fixed; that is the two fields doing their jobs. Mention any open
   discovered-work issues.
4. Offer the session time entry (see Session time) if not yet logged.

## Coaching the human

This workflow is new to most people - assume the user forgets the ritual
and remind them at natural moments, one light line at a time, never
nagging:

- **Session start**: if the untriaged query has items, mention it once:
  "3 captures are waiting - say 'show me what needs attention' whenever
  you want to triage."
- **Mid-session**: when the user muses about work that is not the focused
  story ("we should also...", "someday it'd be nice..."), offer the
  capture: "want me to record that for later?" - then do it and return
  to the story. Never let a good idea evaporate OR derail the session.
- **Session close**: walk the ritual unprompted - completion check, stage
  move, the time proposal, docs sync where the project has one. The user
  should never have to remember the checklist; that is what you are for.
- **"How does this work again?"** - answer from `docs/WORKFLOW.md` (the
  project-local guide the installer maintains); keep the answer to the
  piece they asked about.

## Read-only mode

The project is read-only when the config has `"readOnly": true`, or when a
write operation is refused server-side. In that mode: never call write
operations; track AC progress and discovered work in session notes; at
checkpoints hand the user a concise change list (AC items to check,
discovered issues to file in canonical format). Reads — and focus, where
the binding marks it safe — remain allowed. (No connection at all is the
related case — see [references/offline.md](references/offline.md).)

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
