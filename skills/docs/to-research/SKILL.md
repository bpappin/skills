---
name: to-research
description: Manage Technical Research & Development (R&D) logs in docs/research/. Use when starting new research, documenting hypotheses, or logging technical discovery findings.
license: MIT
compatibility: Standalone; writes RAD records under docs/research/ per the project-docs taxonomy.
metadata:
  author: bpappin
  version: "1.0"
---

# Skill: Technical Research & Development (R&D)

## Objective

Standardize documenting technical challenges, hypotheses, and outcomes -
for transparency, SR&ED tax-credit support, and a clear audit trail for
complex engineering choices.

RAD records live in `docs/research/` (the taxonomy's home for
investigations - see the project-docs skill). A RAD is the structured,
audit-grade variant of a research record; lighter investigations can use
project-docs' plain research template. Records carry no status frontmatter
- the Outcome section holds the conclusion, and any *work* a RAD spawns
becomes a tracker story, not a file.

## Activation guard

Before executing any workflow, verify `"rad_enabled": true` in
`.agents/config/project.json`. If false or missing, inform the user that
R&D logging is disabled for this project and only proceed if explicitly
instructed.

## Core workflows

### 1. Start new research

When a complex technical challenge is identified or a design pivot is
considered:

1. Create `docs/research/RAD-[ID]-[slug].md` using
   [references/rad-template.md](references/rad-template.md).
2. Assign the next incremental ID (resolve the sequence from
   `docs/research/README.md`).
3. Document the **Technical Challenge**, **Constraints**, and
   **Hypothesis**.
4. Update the `docs/research/README.md` index.

### 2. Log decision & outcome

When research concludes or a pivot is chosen:

1. Update the corresponding `RAD-[ID].md`.
2. Fill in **Decision** and **Outcome**; **Validation** points dated and
   verifiable.
3. A permanent architecture change → record/reference the ADR
   (`docs/adr/`). Implementation work that falls out → tracker stories
   (to-issues skill); link their IDs under Connections.

### 3. Review research path

When asked to "review the reasoning for [feature]": search
`docs/research/` for relevant RAD entries; summarize the **Assumptions**
and **Reasoning** that led to the current state; note any constraints that
became tracker stories and their current status.

## Documentation architecture

- `docs/research/README.md` — master index of research activities.
- `docs/research/RAD-[ID]-[slug].md` — deep-dive research and decision
  records.
