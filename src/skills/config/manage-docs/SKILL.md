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
| **Criteria** | `docs/ac/` | The "Verification" (Testable success outcomes). Permanent artifacts of a feature. |
| **Discovery** | `docs/discovery/` | The "Why" and "Due Diligence" (DD). Vendor research, cost analysis, and feasibility. |
| **Design** | `docs/design/` | The "Experience" (UI/UX, Mockups). |
| **Roadmap** | `docs/gap/` | The "Future" (GAPs and Technical Debt). Transient task trackers for missing pieces. |
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
4.  **Cross-Link**: If the update resolves a GAP, update the status in the corresponding `docs/gap/` file. Note: While an AC may be derived from a GAP, they are independent datasets; ACs define success, while GAPs track roadmap progress.

### 2. Context Mapping Rule
Before taking significant action, the agent MUST:
*   Reference `docs/mandates/SPEC.md` for business logic.
*   Reference `docs/mandates/ARCH.md` for repository/data patterns.
*   Reference `docs/ac/` for the *permanent* success criteria of the current feature.
*   Reference `docs/gap/` for the *transient* roadmap status of the task.

### 3. Adding a new GAP
1.  Create a new file `docs/gap/XXXX-slug.md` using the next incremental ID.
2.  Update the [GAP Index](air-file://ml8ci4kvlk3fda06ret8/Users/bpappin/Workspace/coldwater/docs/gap/README.md?type=file&root=%252F).

### 4. Due Diligence (DD) Records
Before making significant architectural choices or vendor selections, create a Due Diligence record in `docs/discovery/`.
1.  **Format**: Use the prefix `DD-XXXX-slug.md`.
2.  **Trail Preservation**: Include a "Discovery Trail" or "Background" section that summarizes the back-and-forth discussions (including AI logic) that led to the findings.
3.  **Traceability**: Reference the DD record in subsequent ADRs or GAPs using the `[DD-XXXX]` identifier.

### 5. Architectural Decision Records (ADR)
When a hard-to-reverse decision is made, record it in `docs/adr/`.
1.  **Format**: Use sequential numbering: `XXXX-slug.md`.
2.  **Criterion**: Only record decisions that are hard to reverse, surprising without context, or the result of a real trade-off.
3.  **Template**: Keep it concise (1-3 sentences for context/decision/rationale). Include Status, Options Considered, and Consequences only when they add value.
4.  **Traceability**: Cross-link to related Due Diligence (DD) or GAPs.
