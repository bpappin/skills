---
name: setup-project
description: Onboard and configure a project workspace for tracking, sync, and agent interaction. Use when starting a new project or refreshing workspace configuration.
---

# Project Setup

## Objective
A comprehensive onboarding skill to configure a project workspace for issue tracking, synchronization, and agent interaction. This skill establishes the foundational configuration required by all other tracking skills.

## Core Mechanics

### 1. Shared Project Configuration (`.config/project.json`)
The agent must ensure that a `.config/project.json` file exists in the project workspace. This file acts as the primary registry for shared, immutable project configuration that should be committed to version control.
*   **Action:** If `.config/project.json` does not exist, explicitly ask the user to provide the project identity:
    *   `project_id`: A unique, short-string identifier for the project (e.g., `EVO`, `DETOURS`).
    *   `sync_target`: The primary issue tracking system (e.g., `youtrack`, `github`, `jira`).
    *   `git_repo`: The repository identifier or remote URL.

*   **Action (Optional Features):** The agent MUST explicitly ask if the following optional features should be enabled:
    *   **Compliance Tracking**: If enabled (`compliance_enabled: true`), ask for the initial `active_regulations` (e.g., `["PIPEDA", "GDPR"]`).
    *   **R&D Logging**: If enabled (`rad_enabled: true`).

*   **Action:** Once provided, generate the `.config/project.json` file.

### 2. Documentation Architecture
The agent must verify or initialize the following directory structure in the workspace:
*   `docs/gap/`: Project roadmap, functional gaps, and future capabilities (`README.md`).
*   `docs/mandates/`: Core technical and functional standards (`ARCH.md`, `SPEC.md`, `DESIGN.md`).
*   `docs/design/`: Visual specifications, feature mockups, and UI foundations (`README.md`).
*   `docs/guides/`: Onboarding and operational guides (`DEVELOPER.md`, `INSTALLATION.md`).
*   `docs/reference/`: Domain knowledge and regulatory frameworks (`IDV_REFERENCE.md`, `REGULATORY.md`).
*   `docs/regulations/`: Authoritative source for regulatory mappings (`README.md`, `COMPLIANCE.md`, `PIPEDA.md`, etc.).
*   `docs/research/`: Deep-dive technical research and RAD logs (`README.md`).
*   `docs/discovery/`: Due Diligence (DD) research, vendor analysis, and cost evaluations.
*   `docs/adr/`: Architectural Decision Records.
*   `docs/ac/`: Acceptance Criteria repository.

### 3. Agent Mandates (`AGENTS.md`)
The agent MUST ensure that the project is optimized for AI assistance.
*   **Action:** If `AGENTS.md` does not exist at the project root, generate it using the [AGENTS_TEMPLATE.md](./AGENTS_TEMPLATE.md).
*   **Action:** If it exists, verify the **"Update Docs Rule"** correctly references the `.skills/config/manage-docs/` skill.

### 4. Local Agent Configuration (`~/.config/agents/<project_id>/`)
This directory handles user-specific, non-secret configuration (e.g., active persona, local formatting preferences, and skill sources). Storing this globally bypasses `.gitignore` complexities and keeps the workspace clean.
*   **Action:** The agent must resolve the `project_id` from `.config/project.json`.
*   **Action:** Ensure the `~/.config/agents/<project_id>/` directory exists.
*   **Action:** Initialize `skill-sources.json` if missing, prompting the user for the primary master skill repository path (e.g., `~/Workspace/skills/src/skills/`).
*   **Constraint:** The agent MUST route all user-specific state files (like `persona.json` and `skill-sources.json`) to this global directory, NEVER to the local project workspace.

### 3. The Secrets Vault (`~/.secrets/agents/<project_id>/`)
This project relies on a centralized secrets vault located in the user's home directory to store sensitive tokens and API keys securely outside of version control.
*   **Action:** The agent must verify that the directory `~/.secrets/agents/<project_id>/` exists.
*   **Action:** Based on the `sync_target` defined in `.config/project.json`, ask the user if they want to configure the corresponding credentials. For example, if the target is `youtrack`, the agent should help create a `youtrack.env` file inside the secrets vault containing `YOUTRACK_TOKEN=<token>`.
*   **Constraint:** The agent MUST NOT write sensitive tokens to any file inside the project workspace directory.

### 3. Verification
*   Confirm the configuration setup by reading back the stored config.
*   Verify the existence of core skills: `.skills/config/setup-project/`, `.skills/config/persona/`, and `.skills/config/manage-docs/`.
