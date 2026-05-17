---
name: manage-skills
description: Manage the lifecycle, organization, and synchronization of AI agent skills between local project workspaces and master skill sources. Use when user wants to sync skills, update the master skills source, or organize the .skills directory.
---

# Skill Management

## Objective
Provide a standardized, interactive workflow for maintaining a consistent library of AI agent skills across multiple projects and centralized master sources.

## Core Hierarchy
1.  **Project Skills (`.skills/`)**: Local workspace skills, often refined or customized for a specific project.
2.  **Master Sources**: Remote or local authoritative repositories for shared skills. Paths are configured per-machine in `~/.config/agents/<project_id>/skill-sources.json`.

## Workflows

### 1. Configuration & Discovery
Before any operation, the agent must verify the project is initialized (`.config/project.json`).
- **Load Sources**: Read `~/.config/agents/<project_id>/skill-sources.json`. 
- **Prompt**: If sources are missing, ask the user for the primary master skill repository path (e.g., `~/Workspace/skills/src/skills/`).
- **List**: Show all local skills and available skills from all master sources.

### 2. Downstream Sync (Pull: Source ➔ Project)
Triggered by "Sync Skills". This workflow brings shared improvements into the current workspace.
1.  **Detection**: Compare local `.skills/` with the registered master sources.
2.  **Reporting**: Present a categorized report:
    - **New**: Skills available in sources but missing locally.
    - **Updates**: Local skills that are identical to an older master version but have a newer version available.
    - **Divergent**: Local skills that have been modified and differ from the latest master version.
3.  **Conflict Resolution**: 
    - For **New** and **Update** items: Ask for permission to install/overwrite.
    - For **Divergent** items: **STOP** and display a diff. Ask the user: *"The local version has diverged. Do you want to overwrite your local changes, keep your version, or promote your changes to the master source instead?"*
4.  **Execute**: Copy the entire directory (scripts/resources included) only after user confirmation.

### 3. Upstream Sync (Push: Project ➔ Source)
Triggered ONLY by an explicit command (e.g., "Push skill [name] to master").
1.  **Select Target**: If multiple sources exist, ask which one should receive the update.
2.  **Validate**: Ensure the skill follows the [write-a-skill](../productivity/write-a-skill/SKILL.md) mandate.
3.  **Preserve Discovery**: Verify that the `SKILL.md` includes a **Discovery Trail** section capturing the original design logic and AI discussion history.
4.  **Execute**: Copy the local project skill to the selected master repository.

## Rules & Constraints
- **Kebab-Case**: Always use kebab-case for skill directory names.
- **Atomic Operations**: Always copy the full directory to maintain functionality.
- **Explicit Pushes**: Never automatically update a master source.
- **PII Scrubbing**: Ensure all logic in the master source is generic and scrubbed of project-specific PII (unless it's in the Discovery Trail for context).
