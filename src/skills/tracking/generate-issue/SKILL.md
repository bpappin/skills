---
name: generate-issue
description: Generate local Markdown issue documents (Format A) for tasks, bugs, or stories to be synced with a remote tracker. Use when breaking down small tasks or isolated bug fixes.
---

# Flat Issue Generation

## Objective
Generate simple, flat issue documents (Format A) for tasks, bugs, or stories that do not require an overarching Epic container. This skill is ideal for fast-moving projects or isolated work.

## Core Mechanics

### 1. Document Creation
When the user requests to break down a feature or fix a bug into an issue, the agent must generate a Markdown document representing the task.

The document MUST adhere to the following **Format A** structure:

```markdown
# [Task Title]

**ID:** [#NEW]
**Status:** TODO
**Type:** [Story/Task/Bug]
**Parent:** [Optional Epic ID]

## What to build
A concise, user-centric description of the task. Describe the end-to-end behavior or the technical requirement.

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Resolved Gaps
- [GAP-ID] (Optional) A reference to any recorded Gaps in `docs/gap/README.md` that this issue resolves.

## Related ADRs
- [ADR-001] (Optional) A reference to an Architectural Decision Record in `docs/research/` related to this issue.
```

### 2. Context Hunting
Before finalizing the document, the agent MUST:
*   Scan `docs/gap/` to see if the work described addresses an existing gap. If so, include the gap ID in the `Resolved Gaps` section.
*   Scan `docs/research/` to identify any Architectural Decision Records that dictate how this issue should be implemented. If found, link them in the `Related ADRs` section.

### 3. File Naming
Save the generated issue document using a descriptive, lowercase, kebab-case filename (e.g., `implement-google-login.md`) in the `docs/issues/` directory (or wherever the user prefers to stage issues).
