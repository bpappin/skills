# How should story-tools handle more than one person on a project?

RAD-0003 · 2026-08-18
Keywords: teams, roles, junior developer, contractor, hourly, permissions,
          maintainer, contributor, who writes the PRD, per-developer setup,
          setup.sh, readOnly, tracker permissions, rejected: per-person
          skill bundles, rejected: role taxonomy

Status: partly decided, partly open. The immediate pain is fixed, and
recommendations 1-4 below are now built: role is declared, asked once at
setup from a fixed set, stored user-side, read as a hint. Enforcement stays
with the tracker. Open questions 1-5 remain open. Reached by discussion,
not experiment - no `Measured against:` line.

## Question

The suite assumes one person who owns the product thinking *and* the
implementation. That is true of its author and false of most teams.

The case that surfaced it: a junior developer, paid hourly, working
alongside the maintainer. They should be picking up ready stories, writing
code, and filing what they find. They should not be authoring PRDs - it is
not their call, it is expensive on the clock, and the result gets rewritten.

The workflow pushed them there anyway.

## Trail

### The immediate cause, and its fix

`story-workflow` said: *a story with no `## Acceptance Criteria` - stop and
draft AC with the user before writing code.* "The user" is whoever is in the
session. Hand a thin story to someone who does not own the requirements and
that instruction means either inventing them under time pressure, or
climbing the chain into `to-prd` because that is where the workflow pointed.

Fixed in `story-workflow` 1.18: a story without AC is not ready to be
worked, by anyone. It goes back to triage. Deliberately **not** framed as a
permissions rule - requirements invented inside a work session are invented
by whoever is holding the ticket, with nobody reviewing them, which is the
scope hole the skill exists to close. Whoever owns the requirements can
still fix the story, as a separate triage step rather than a detour.

That removes the pressure. It does not answer the question.

### The line is not "can they author"

The first framing was wrong. Contributors must be able to create issues and
file bugs - that is how work reaches the maintainer in the first place, and
blocking it would break the flow that already works.

The real boundary is **deciding what the product is**. Capture is for
everyone; PRDs, ADRs and RADs are product and architecture decisions. So:

| Everyone | Whoever owns the product |
|---|---|
| create issues, file bugs | `to-prd`, `to-adr`, `to-rad` |
| `story-workflow`, `worklog`, `tdd` | triage *routing*: priority, subsystem, readiness |
| discovered work off-ramp | `grill-with-docs` |
| triage *capture* | deciding a story is ready to work |

### Why a smaller skill set per person cannot work

The obvious answer - install fewer skills for a contributor - is
structurally impossible. The installer copies skills into
`.agents/skills/`, those are **tracked files**, and everyone who clones the
repo gets the same set. A contributor install would strip the maintainer's
own skills, or the two would overwrite each other on every refresh.

Role cannot be a property of the project, because the project is shared.
**Role is a property of the person.**

### The seam that already exists

`setup.sh` ships into every bound project and is explicitly the
per-developer step: it configures *your* credential and *your* agent
registrations and deliberately does not touch skills. Per-person state
already lives beside it in `~/.agents/story-tools/`.

That is where "what am I on this project?" belongs. Nothing else in the
system is per-person.

### Precedent in the pointer

`readOnly` already exists: agents propose changes but never write. It is a
capability flag, project-scoped. Role is the same idea with more values and
a different scope - per person rather than per project. Whether the two
should merge is an open question rather than an obvious yes.

### Declared or derived?

**Declared** - the developer says what they are during `setup.sh`, stored
user-side. Simple, works offline, no tracker round trip. But it is
self-asserted, it drifts as people's responsibilities change, and it is a
second source of truth about something the tracker already knows.

**Derived** - read it from the tracker, which knows who everyone is and
what they may do. Authoritative and cannot drift. But it needs a per-binding
mapping from tracker groups to roles, costs a call, and fails when offline
or when the tracker's own model does not distinguish the thing we care
about (GitHub write access does not mean "owns the requirements").

### Skills instruct; they do not enforce

Worth stating plainly, because it bounds what any of this can achieve. A
skill is instructions. A role expressed in a skill is advisory - an agent
can be told not to write a PRD and still write one, and a determined human
can invoke the skill directly.

Actual enforcement lives in the tracker: permissions, and the existing
`readOnly` path. So the honest design is **advisory role shaping what the
agent offers, tracker permissions enforcing what can actually happen** -
the same split as everywhere else in the suite: mechanism in the tool,
judgement in the agent.

## Findings

**Most of the pain was one sentence, not a missing feature.** Removing the
push into authoring fixed the bleeding without any role concept. That is
worth remembering before building the general answer: check how much is
left once the specific instruction is corrected.

**Role is per-person, and the system has exactly one per-person surface.**
`setup.sh` and `~/.agents/story-tools/`. Anything committed to the repo is
shared by definition and cannot carry it.

**Capture must never be gated.** Whatever roles exist, filing an issue or a
bug is open to everyone. It is how work reaches the person who can triage
it, and gating it would produce silence rather than compliance.

**A role cannot be enforced by a skill.** Design it as a hint that shapes
what an agent offers and how it routes, and let the tracker be the thing
that refuses.

**Few roles, phrased as activities.** Asking what someone *is* invites a
status vocabulary nobody can apply consistently; asking what they *do*
maps onto the work. Four - implement, make the technical
calls, manage the work, decide the product - cover the observed cases, they
are not exclusive, and holding all of them is the ordinary solo answer
rather than a special case. Add a fifth only when a real situation demands
it, as the fourth was.

**Architecture is its own role.** `to-adr` and `to-rad` are neither
product decisions nor ordinary implementation, and forcing them into either
would have been wrong: managing the work and making the technical calls are
different jobs, and a junior developer should not be writing ADRs. So
`architect` - the senior developer or architect - joined the set. This is
the fourth role the finding above said to wait for: a real situation
demanded it rather than a vocabulary anticipating one.

## Recommendation

Nothing is decided. The direction that survives the trail above:

1. **Ship the thin-story fix and observe.** Already done. It may be
   sufficient for a two-person team, and that is worth finding out before
   building more.
2. **If more is needed: declared role, per developer**, chosen during
   `setup.sh`, stored in `~/.agents/story-tools/`, with two values.
3. **Skills read it as a hint** - shaping what is offered and where thin
   work routes - never as a permission check they pretend to enforce.
4. **Leave enforcement to the tracker**, including the existing `readOnly`
   path.
5. **Revisit derived-from-tracker** only if declared roles visibly drift.

## Open questions

1. ~~**Where exactly does the role live**~~ - settled: per project, keyed
   by the tracker's identity for it (`repo`, else project key), in
   `~/.agents/story-tools/developer.json`. A contractor can be a
   contributor on one project and own another.
2. **Does `readOnly` fold into role**, or stay a separate project-level
   flag? They overlap without being the same thing.
3. **Is triage split?** Capture is clearly for everyone and routing is
   clearly not, but "this story is ready to work" sits awkwardly between.
4. ~~**What does a solo project do?**~~ - settled: the roles are asked as
   what you *do*, not what you are, they are not exclusive, and Enter takes
   all three ("working solo"). One keystroke, no label anyone has to accept
   about themselves.
5. **Does the tracker binding need a role concept**, or is this purely
   local? YouTrack and GitHub model permissions differently and neither
   maps cleanly onto "owns the requirements".

## References

- `skills/stories/story-workflow/SKILL.md` 1.18 - the thin-story guardrail
- `skills/docs/to-prd/SKILL.md` 1.5 - a PRD is a decision, not a capture
- `scripts/install.sh` - `ship_setup`, and the `readOnly` pointer flag
- RAD-0002 - stakeholder comments; the same question of who may change
  what, arriving from the other direction
