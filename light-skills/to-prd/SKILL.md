---
name: to-prd
description: Synthesize conversation context and codebase understanding into a formal PRD, with verification living on the stories that implement it - one file. Product and commercial briefs are written only when someone asks for one. Use when the user wants to formalize a plan, feature idea, or requirement discussion into a PRD, or wants an existing PRD restated for product management or business development. Triggers - "write a PRD", "formalize this plan", "turn this into requirements", "brief for the PM", "what do we tell sales", "commercial brief", "what can we promise".
license: MIT
compatibility: Standalone. Writes a PRD file into the repo; no network, no scripts, no tracker.
metadata:
  author: bpappin
  version: "1.4"
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

Create `docs/requirements/PRD-NNNN-short-slug.md` from
`assets/templates/prd.md` in this skill, taking the next unused PRD number.
`PRD-0003` is the handle stories and briefs cite, and it stays with the
document for its whole life - a PRD is corrected in place, and the ID names
the document rather than a version of it. No status frontmatter — it is wrong within a week and nobody
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

### 4. Briefing another reader - not a second document

**The output is one file: the PRD.** Do not write a brief unprompted - a brief written beside a PRD becomes a second PRD, drifts from it, and the one the business reads is the one that is wrong.

When somebody needs the PRD restated for a reader who does not follow module boundaries, ask which they want and default to the cheapest:

- **A short summary in the conversation** - a few sentences they can paste into chat, an email, or a story's notes. This is the normal answer and needs no file.
- **A file in `docs/outbox/`**, only if they ask for something to send. That is where outbound artifacts go - written FOR someone else rather than as project knowledge. Name it after the PRD it came from, e.g. `PRD-0003-draft-visibility-pm-brief.md`.

Never in `docs/requirements/`, and never anywhere a reader could mistake it for the record. The PRD is the record; a brief is one audience's view of it at one moment.

**What to cover**, when one is asked for: `assets/templates/pm-brief.md` for a product brief - outcomes, users, non-goals in plain terms, how we will know it worked, sequencing, risks, and no module names. `assets/templates/bd-brief.md` for a commercial one. Treat both as a checklist, not as a reason to create a file.

**A commercial brief has a test worth keeping:** does this change what someone outside the company can be told, sold, or promised? A new capability, a changed limit, a new integration - yes. Refactors, tech debt, internal tooling - no. The section that earns its place is **what it does NOT do**, because commercial harm comes from promises made in the gap between what shipped and what someone assumed shipped. Mark availability as committed, planned or exploratory; a reader assumes the strongest reading left open. Never carry story ids, module names or internal codenames into it.

**If briefing exposes a gap, fix the PRD.** Success signals, a date, a segment it should have named - correct it there rather than in the restatement. That is the part of the exercise worth having, and it costs no extra file.

## Review checklist

- [ ] Are the user stories comprehensive?
- [ ] Is there a discovery trail (research/ADR links) in the Problem section?
- [ ] Are decisions decoupled from specific files?
- [ ] Are non-goals explicit?
- [ ] Is the Stories table filled (or explicitly deferred to to-stories)?
- [ ] No AC in the PRD - checklists belong to the stories.
- [ ] Does the PRD say how success is measured?
- [ ] Exactly one file, unless a brief was asked for?
- [ ] If a PM brief was asked for: does it read without a single module name?
- [ ] If a commercial brief was asked for: does it pass the outside-the-company
      test, and state what the thing does *not* do?
- [ ] If any brief exists: does it cross-link the PRD, with a date?
