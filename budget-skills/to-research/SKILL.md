---
name: to-research
description: Manage Technical Research & Development (R&D) logs as audit-grade RAD records in docs/research/. Use when starting new research, documenting hypotheses, or logging technical discovery findings.
license: MIT
compatibility: Standalone. Writes RAD records into docs/research/; no network, no scripts, no tracker.
metadata:
  author: bpappin
  version: "1.0"
---

# Skill: Technical Research & Development (R&D)

## Objective

Standardize documenting technical challenges, hypotheses, and outcomes -
for transparency, SR&ED tax-credit support, and a clear audit trail for
complex engineering choices.

RAD records live in `docs/research/`. A RAD is the structured, audit-grade
variant of a research record; lighter investigations can use the `to-rad`
skill's plainer template. Records carry no status frontmatter - the Outcome
section holds the conclusion, and any *work* a RAD spawns becomes a story
(`to-stories`), not a section of the record.

## Activation guard

Before executing any workflow, verify `"rad_enabled": true` in
`.agents/config/project.json`. If false or missing, inform the user that
R&D logging is disabled for this project and only proceed if explicitly
instructed.

## Core workflows

### 1. Start new research

When a complex technical challenge is identified or a design pivot is
considered:

1. Create the record in `docs/research/` as `RAD-[ID]-short-slug.md`
   (heading `# RAD-[ID] - [Title]`) using
   [references/rad-template.md](references/rad-template.md).
2. Assign the next incremental ID - the highest already in the directory,
   plus one.
3. Document the **Technical Challenge**, **Constraints**, and
   **Hypothesis**.
4. Update the directory's `README.md` index if it keeps one.

### 2. Log decision & outcome

When research concludes or a pivot is chosen:

1. Update the corresponding `RAD-[ID].md`.
2. Fill in **Decision** and **Outcome**; **Validation** points dated and
   verifiable.
3. A permanent architecture change → record/reference the ADR in
   `docs/decisions/` (to-adr). Implementation work that falls out →
   stories (to-stories); link their numbers under Connections.

### 3. Review research path

When asked to "review the reasoning for [feature]": search
`docs/research/` for relevant RAD entries; summarize the **Assumptions**
and **Reasoning** that led to the current state; note any constraints that
became stories and their current status.

## Documentation architecture

- `docs/research/README.md` — the index of research activities, if the
  project keeps one.
- `RAD-[ID]` records in that directory — deep-dive research and decision
  records.
