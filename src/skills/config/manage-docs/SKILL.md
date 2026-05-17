---
name: manage-docs
description: Manage and intelligently distribute project knowledge across the 6-sector documentation hierarchy. Use when commanded to "update docs", "add documentation", or when project standards change.
---

# Documentation Management

## The 6-Sector Hierarchy

All knowledge must be dispersed into the appropriate specialized directory to ensure high-quality AI context mapping and prevent documentation bloat.

| Sector | Path | Focus |
| :--- | :--- | :--- |
| **Mandates** | `docs/mandates/` | The "How" and "What" (ARCH, SPEC, DESIGN). |
| **Criteria** | `docs/ac/` | The "Verification" (Success outcomes). |
| **Design** | `docs/design/` | The "Experience" (UI/UX, Mockups). |
| **Roadmap** | `docs/gap/` | The "Future" (GAPs and Technical Debt). |
| **Regulations**| `docs/regulations/` | The "Compliance" (PIPEDA, GDPR, etc.). |
| **Guides** | `docs/guides/` | The "Environment" (Onboarding and Installation). |
| **Reference** | `docs/reference/` | The "Knowledge" (IDV methods). |
| **Research** | `docs/research/` | The "Hypothesis" (R&D Logs and Decisions). |

## Workflows

### 1. Intelligent Update ("Update Docs")
When commanded to "update docs", do NOT create a generic text block. Follow this checklist:
1.  **Identify Domain**: Determine if the information is technical (ARCH), functional (SPEC), visual (DESIGN), or evaluative (AC).
2.  **Locate File**: Find the specific file or index in the corresponding sector.
3.  **Surgical Edit**: Use the `replace` tool to inject the new context idiomaticaly. 
4.  **Cross-Link**: If the update resolves a GAP, update the status in the corresponding `docs/gap/` file.

### 2. Context Mapping Rule
Before taking significant action, the agent MUST:
*   Reference `docs/mandates/SPEC.md` for business logic.
*   Reference `docs/mandates/ARCH.md` for repository/data patterns.
*   Reference `docs/ac/` for success criteria of the current feature.

### 3. Adding a new GAP
1.  Create a new file `docs/gap/XXXX-slug.md` using the next incremental ID.
2.  Update the [GAP Index](air-file://ml8ci4kvlk3fda06ret8/Users/bpappin/Workspace/coldwater/docs/gap/README.md?type=file&root=%252F).
