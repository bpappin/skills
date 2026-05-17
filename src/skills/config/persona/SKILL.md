---
name: persona
description: Initialize and manage persona state via a global persona.json file. Adapts agent behavior, technical focus, and output style to match the user's active role (Developer, Designer, BA, etc) and specialty. Use when starting an interaction, setting up a workspace, or when the user mentions their role or persona.
---

# Skill: Persona Management & Adaptation

## Objective
Enable the AI agent to dynamically adapt its behavior, technical focus, and output style based on the user's active persona instance. This allows a single user to adopt multiple roles (e.g., "Developer" vs. "Designer") or seamlessly switch between multiple specialized profiles of the same role.

## Core Mechanics: Global State Management
The agent must manage persona state using a global, project-specific JSON file to ensure local state is never committed to version control.

1.  **Context Resolution:**
    *   The agent MUST first identify the current `project_id` by reading the `.config/project.json` file in the workspace root.
    *   The persona state file is strictly located at: `~/.config/agents/<project_id>/persona.json`.

2.  **Initialization & Context Loading:**
    *   Upon starting an interaction, the agent MUST read the `persona.json` file.
    *   **If the file exists:** Adopt the behavior and focus defined by the `active_persona_id` inside the JSON object.
    *   **If the file does NOT exist:** The agent MUST explicitly pause and ask the user to initialize their first persona by providing their **Name**, **Role**, and **Specialty**.

3.  **State Creation & Schema:**
    *   When adding a new persona or creating the file, the agent must use the following JSON schema:
        ```json
        {
          "active_persona_id": "dev-1",
          "personas": {
            "dev-1": {
              "name": "Alex",
              "role": "Developer",
              "specialty": "Backend/Ktor"
            },
            "designer-1": {
              "name": "Jordan",
              "role": "Designer",
              "specialty": "UX Mechanics"
            }
          }
        }
        ```
    *   The agent must update the `active_persona_id` when the user requests to switch personas.

## Dynamic Persona Profiles
The agent must shift its operational boundaries dynamically based on the active persona profile.

*   **name:** Identifies the specific individual or profile handle.
*   **role:** Defines the primary domain of operation. The agent adapts its behavior to fit the role:
    *   *Examples:*
        *   **Developer:** Focus on code implementation, architecture, and engineering standards. Proposes technical plans and writes executable code.
        *   **Designer:** Focus on mechanics, UX, aesthetics, and systems design. Abstains from writing executable software code; prioritizes Markdown, Mermaid, and outlines.
        *   **Business Analyst (BA):** Focus on requirement gathering, acceptance criteria, and specifications mapping.
*   **specialty:** Further narrows the focus within the role.
    *   *Examples:* Mobile vs. Backend for Developers, Economy vs. UI for Designers.

By evaluating the `role` and `specialty` of the `active_persona_id`, the agent seamlessly supports an unlimited number of unique persona instances across different disciplines.
