---
name: generate-epic
description: Generate comprehensive Agile Epic documents (Format B) that act as an index for multiple child stories (Format A). Use when planning complex features or major system changes.
---

# Agile Epic Generation

## Objective
Generate comprehensive Agile Epic documents (Format B) that act as an index/container for multiple child stories (Format A). This skill is designed for complex feature planning.

## Core Mechanics

### 1. The Epic Container (Format B)
When the user wants to plan a large feature, the agent must generate a master Epic document. This document MUST adhere to the following **Format B** structure:

```markdown
# Epic: [Epic Title]

A high-level description of the entire epic, its business value, and overall goals.

## Stories Index
| ID | Summary | Status | Type | Link |
|---|---|---|---|---|
| [#NEW] | [Story 1 Title] | TODO | Story | [link-to-story-1.md](./link-to-story-1.md) |
| [#NEW] | [Story 2 Title] | TODO | Task | [link-to-story-2.md](./link-to-story-2.md) |

## Resolved Gaps
- [GAP-ID] Reference to a Gap this Epic resolves at a macro level.
```

### 2. Child Story Generation (Format A)
For every row added to the `Stories Index` table, the agent MUST generate a corresponding child document using the **Format A** structure defined in the `generate-issue` skill.
*   The `Link` column in the Epic's table must point accurately to the relative path of the generated child document.
*   Child documents must have their `**Parent:**` field explicitly set to the Epic's ID (or `[#NEW]` if the Epic is also new).

### 3. Context Hunting
During generation, the agent MUST:
*   Scan `docs/gap/` and `docs/research/` to identify relevant macro-level context for the Epic, and micro-level context for individual Stories.
*   Distribute these references accurately. If a Gap applies to the whole feature, list it in the Epic. If an ADR only applies to one specific database migration story, list it in that specific child document.

### 4. File Organization
Save the Epic document and its child stories in a logical folder structure (e.g., `docs/issues/epic-name/`).
