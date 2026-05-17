---
name: setup-project
description: Onboard and configure a project workspace for tracking, sync, and agent interaction. Use when starting a new project or refreshing workspace configuration.
---

# Project Setup

## Objective
A comprehensive onboarding skill to configure a project workspace for issue tracking, synchronization, and agent interaction. This skill establishes the foundational configuration required by all other tracking skills.

## Core Mechanics

### 1. Shared Project Configuration (`.config/project.json`)
The agent must ensure that a `.config/project.json` file exists in the project workspace. 
*   **Action:** If `.config/project.json` does not exist, explicitly ask the user for:
    *   `project_id`: A unique identifier (e.g., `EVO`, `DETOURS`).
    *   `sync_target`: Primary issue tracker (e.g., `youtrack`, `github`).
    *   `git_repo`: The repository identifier or remote URL.
*   **Optional Features:** Ask to enable **Compliance Tracking** (`active_regulations`) and **R&D Logging**.

### 2. Documentation Architecture
The agent must verify or initialize the hierarchy:
*   `docs/mandates/`: Technical and functional overviews (`ARCH.md`, `SPEC.md`).
*   `docs/prd/`: Feature stories and requirements.
*   `docs/ac/`: Testable acceptance criteria.
*   `docs/discovery/`: Due Diligence (DD) research and cost evaluations.
*   `docs/gap/`: Roadmap and functional gaps.
*   `docs/adr/`: Architectural Decision Records.
*   `docs/regulations/`: Regulatory compliance mappings.
*   `docs/research/`: Deep-dive RAD logs.
*   `docs/guides/`, `docs/reference/`, `docs/design/`.

### 3. Legacy Doc Discovery
After initialization, the agent MUST offer to organize existing documentation:
> *"I noticed existing documentation files scattered in your project. Would you like me to analyze and organize them into the new 6-sector hierarchy (Mandates, Stories, Discovery, etc.)?"*
*   **Action**: If yes, trigger the `migrate docs` workflow from the `manage-docs` skill.

### 4. Agent Mandates (`AGENTS.md`)
*   **Action:** Generate or audit `AGENTS.md` at the project root. Ensure the **"Update Docs Rule"** correctly references the `manage-docs` skill.
*   **Safety**: Remind the user that technical specs live in `/docs` (not Wikis) for versioning.

### 5. Local Agent Configuration (`~/.config/agents/<project_id>/`)
*   **Action:** Ensure the directory exists.
*   **Skill Sources**: Initialize `skill-sources.json` if missing, prompting for the master skill repository path (e.g., `~/Workspace/skills/src/skills/`).
*   **Constraint:** NEVER store machine-specific paths or personal state in the project workspace.

### 6. The Secrets Vault (`~/.secrets/agents/<project_id>/`)
*   **Action:** Verify the directory exists. 
*   **Credentials**: Help create `<target>.env` (e.g., `github.env`) containing tokens for the `sync_target`.
