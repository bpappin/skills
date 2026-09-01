---
name: to-prd
description: Synthesize conversation context and codebase understanding into a formal PRD, with verification living on the stories that implement it - then derive the product and commercial briefs the PRD's other audiences need. Use when the user wants to formalize a plan, feature idea, or requirement discussion into a PRD, or wants an existing PRD restated for product management or business development. Triggers - "write a PRD", "formalize this plan", "turn this into requirements", "brief for the PM", "what do we tell sales", "commercial brief", "what can we promise".
license: MIT
compatibility: Standalone. Writes a PRD file into the repo; no network, no scripts, no tracker.
metadata:
  author: bpappin
  version: "1.0"
---

# Product Requirements (to-prd)

Synthesize the current context into a **PRD document** under
`docs/requirements/`. The PRD carries requirements and intent;
**verification lives on the stories** that implement it, in their
`## Acceptance Criteria` checklists, never in a companion AC file. One
place holds done-ness, and it is the story.

> **A PRD is a product decision, not a capture.** If you are recording
> something you noticed - a bug, a gap, an idea, a story that needs
> writing - write it up as a story (`to-stories`). Only write a PRD
> when deciding what the product does is your call to make. Nobody should
> be pushed into authoring one because a story they picked up turned out
> to be thin.

## Process

### 1. Synthesis

From the conversation and the codebase: identify the problem, the actors,
and the major modules — look for opportunities to extract deep modules
(isolatable, testable logic). Use the project's domain glossary and respect
existing ADRs. If research fed this (`docs/research/`), reference it.

### 2. Write the PRD

Create `docs/requirements/<slug>.md` from `assets/templates/prd.md` in
this skill. No status frontmatter — it is wrong within a week and nobody
updates it. The `# Title` heading names the document. Sections:

- **Problem** — from the user's perspective, with the discovery trail
  (link Research records that led here).
- **Goals / Non-goals** — non-goals are the requirements-level scope guard.
- **Requirements** — numbered (R1, R2 …) narrative requirements, backed by
  an extensive list of user stories ("As an <actor>, I want <feature>, so
  that <benefit>").
- **Decisions** — architectural choices, API contracts, module boundaries.
  No file paths or code snippets, unless a snippet encodes a decision
  (state machine, schema, type shape) more precisely than prose.
- **Stories** — a table of the story files that implement this PRD, and
  the requirements each covers. Leave it with a placeholder note until
  step 3 fills it.

### 3. Create the verification

Offer to run the **to-stories** skill to break the PRD into story files
(vertical slices, each carrying its own `## Acceptance Criteria`). When the
stories are written, fill the PRD's `## Stories` table with their numbers
and which requirements each covers. Where a requirement has strict rules or
needs test automation, say so in that story's Specification.

### 4. Derive the audience briefs

A PRD is written for the people building the thing. The same decisions
matter to people who do not read module boundaries, and re-explaining it
verbally each time is how the versions drift apart.

**Separate documents, not renderings.** Each brief is a first-class
document written for its own audience. Do not write one document with a
section per reader: nobody reads past their own part, and the version that
matters to them ends up buried in something written for someone else.

**Cross-link all of them.** That is what stops them diverging silently, and
it is how a reader who needs more depth finds it. Where two state the same
fact, **the PRD owns it** — correct it there first, then carry the
correction outward.

**Each tier may hold what the others do not.** Competitive positioning was
never in the PRD and does not belong there. But if a brief needs something
the PRD *should* have said — success signals, a firm date, a segment — that
is a gap in the PRD. Fix it there, then write the brief. This is the most
useful thing about the exercise: it finds the holes.

**Product brief** (`assets/templates/pm-brief.md` in this skill) - write
this whenever the PRD represents a real product decision. Outcomes, users,
non-goals in plain terms, how we will know it worked, sequencing, risks. No
module names; if the problem cannot be stated without them, the PRD's
Problem section is not finished.

**Commercial brief** (`assets/templates/bd-brief.md`) - **only when it makes
sense**, and often it does not. The test: *does this change what someone
outside the company can be told, sold, or promised?* A new capability, a
changed limit, a new integration - yes. Refactors, tech debt, internal
tooling, performance work nobody asked for - no, and producing one anyway
trains people to ignore them.

When you do write one, the section that earns its place is **what it does
NOT do**. Commercial harm comes from promises made in the gap between what
shipped and what someone assumed shipped. Mark availability as committed,
planned, or exploratory, because a reader assumes the strongest reading you
leave open. Never carry story numbers, module names, or internal codenames into
it.

Both live beside the PRD in `docs/requirements/` unless the project has a
commercial or go-to-market section, in which case the commercial brief
belongs there.

## Review checklist

- [ ] Are the user stories comprehensive?
- [ ] Is there a discovery trail (research/ADR links) in the Problem section?
- [ ] Are decisions decoupled from specific files?
- [ ] Are non-goals explicit?
- [ ] Is the Stories table filled (or explicitly deferred to to-stories)?
- [ ] No AC in the PRD - checklists belong to the stories.
- [ ] Does the PM brief read without a single module name?
- [ ] Does the PRD actually say how success is measured, or did the brief
      expose that it does not?
- [ ] If there is a commercial brief, does it pass the outside-the-company
      test - and does it state what the thing does *not* do?
- [ ] Does each brief cross-link the PRD and the other tiers, with a date?
