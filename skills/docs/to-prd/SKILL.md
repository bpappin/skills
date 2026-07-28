---
name: to-prd
description: Synthesize conversation context and codebase understanding into a formal PRD, with verification living on tracker stories. Use when the user wants to formalize a plan, feature idea, or requirement discussion into a PRD document.
license: MIT
compatibility: Standalone for the PRD document; creating the verification stories uses the to-issues skill and the project's tracker.
metadata:
  author: bpappin
  version: "1.1"
---

# Product Requirements (to-prd)

Synthesize the current context into a **PRD document** in `docs/development/prd/`. The
PRD carries requirements and intent; **verification lives on tracker
stories** (their `## Acceptance Criteria` checklists), never in a companion
AC file — the tracker is the source of truth for anything with done-ness.

Works with the project-docs skill: this skill is the authoring workflow;
project-docs owns the taxonomy, the template, and publishing.

## Process

### 1. Synthesis

From the conversation and the codebase: identify the problem, the actors,
and the major modules — look for opportunities to extract deep modules
(isolatable, testable logic). Use the project's domain glossary and respect
existing ADRs. If research fed this (docs/development/research/), reference it.

### 2. Write the PRD

Create `docs/development/prd/<slug>.md` from the project-docs template
(`assets/templates/prd.md` in that skill). No id/status frontmatter, no
sync IDs — the filename slug is the identity. Sections:

- **Problem** — from the user's perspective, with the discovery trail
  (link `docs/development/research/` records that led here).
- **Goals / Non-goals** — non-goals are the requirements-level scope guard.
- **Requirements** — numbered (R1, R2 …) narrative requirements, backed by
  an extensive list of user stories ("As an <actor>, I want <feature>, so
  that <benefit>").
- **Decisions** — architectural choices, API contracts, module boundaries.
  No file paths or code snippets, unless a snippet encodes a decision
  (state machine, schema, type shape) more precisely than prose.
- **Stories** — the table of tracker story IDs. Leave it with a
  placeholder note until step 3 fills it.

### 3. Create the verification

Offer to run the **to-issues** skill to break the PRD into tracker stories
(vertical slices, each carrying its own `## Acceptance Criteria`). When the
stories are published, fill the PRD's `## Stories` table with their IDs and
which requirements each covers. Where a requirement has strict rules or
needs test automation, note it so the story gets the `needs-gherkin` tag.

## Review checklist

- [ ] Are the user stories comprehensive?
- [ ] Is there a discovery trail (research/ADR links) in the Problem section?
- [ ] Are decisions decoupled from specific files?
- [ ] Are non-goals explicit?
- [ ] Is the Stories table filled (or explicitly deferred to to-issues)?
- [ ] No AC in the PRD - checklists belong to the stories.
