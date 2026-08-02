---
name: to-prd
description: Synthesize conversation context and codebase understanding into a formal PRD, with verification living on tracker stories. Use when the user wants to formalize a plan, feature idea, or requirement discussion into a PRD document.
license: MIT
compatibility: Standalone for the PRD document; creating the verification stories uses the to-issues skill and the project's tracker.
derived-from: https://github.com/mattpocock/skills (MIT, (c) 2026 Matt Pocock) - heavily modified
metadata:
  author: bpappin
  version: "1.2"
---

# Product Requirements (to-prd)

Synthesize the current context into a **PRD document** in the **Product Requirements** section of
`docs/knowledge/`. The
PRD carries requirements and intent; **verification lives on tracker
stories** (their `## Acceptance Criteria` checklists), never in a companion
AC file — the tracker is the source of truth for anything with done-ness.

Works with the project-docs skill: this skill is the authoring workflow;
project-docs owns the conventions, the template, and the KB sync.

## Process

### 1. Synthesis

From the conversation and the codebase: identify the problem, the actors,
and the major modules — look for opportunities to extract deep modules
(isolatable, testable logic). Use the project's domain glossary and respect
existing ADRs. If research fed this (the Research section of `docs/knowledge/`), reference it.

### 2. Write the PRD

Create `<slug>.md` in the Product Requirements section directory of
`docs/knowledge/` (find it by its README H1; create it per project-docs if
missing) from the project-docs template (`assets/templates/prd.md` in that
skill). No id/status frontmatter — the `# Title` heading names the KB
article, and the sync gives the file its ID-prefixed name. Sections:

- **Problem** — from the user's perspective, with the discovery trail
  (link Research records that led here).
- **Goals / Non-goals** — non-goals are the requirements-level scope guard.
- **Requirements** — numbered (R1, R2 …) narrative requirements, backed by
  an extensive list of user stories ("As an <actor>, I want <feature>, so
  that <benefit>").
- **Decisions** — architectural choices, API contracts, module boundaries.
  No file paths or code snippets, unless a snippet encodes a decision
  (state machine, schema, type shape) more precisely than prose.
- **Stories** — the table of tracker story IDs. Leave it with a
  placeholder note until step 3 fills it.

Run the project-docs sync after writing — the PRD becomes a KB article
immediately (and again after step 3 fills the Stories table).

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
