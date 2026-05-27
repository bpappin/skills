# Agentic Engineering Tools

This directory contains installation scripts for AI agents.

## ⚠️ Critical Usage Warning

We follow a **"Project-Attached Skills"** model. For standard development, you should **NOT** use these scripts. Instead, copy the `src/skills/` directory into your project as `.agents/skills/`.

Using these tools is **DIFFERENT** from the project-attached model and should only be done if you understand the trade-offs.

| Feature | Project-Attached (Recommended) | Registry Install (Tools) |
| :--- | :--- | :--- |
| **Location** | Inside your repo (`.agents/skills/`) | Global (`~/.gemini/`) or Claude Settings |
| **Portability** | High (Carried with the code) | Low (Local to your machine) |
| **Versioning** | Locked to the codebase | Global (May conflict across projects) |
| **Onboarding** | Automatic on clone | Manual script execution |

---

## 🛠️ Available Tools

### 1. Gemini CLI Install (`install-gemini.sh`)
Packages the exploded skill directories into `.skill` archives and installs them into the Gemini registry.

*   **Usage**:
    ```bash
    # Install to global user scope (available everywhere)
    ./install-gemini.sh --global

    # Install to current workspace scope (available in current folder)
    ./install-gemini.sh --local
    ```

### 2. Claude Code Install (`install-claude.sh`)
Injects the skill instructions directly into Claude's global `customInstructions` configuration.

*   **Usage**:
    ```bash
    ./install-claude.sh
    ```

### 3. Project Local Install & Migrate (`install-project.sh`)
Installs the entire skill library locally into a target project workspace under `.agents/skills/`. It automatically detects legacy `.skills/` directories in the target project, prompting/performing the automated migration and file backup.

*   **Usage**:
    ```bash
    # Install or migrate a project at /path/to/my/project
    ./install-project.sh /path/to/my/project

    # Run in dry-run mode to inspect legacy customizations before migrating
    ./install-project.sh --dry-run /path/to/my/project

    # Migrate without creating a backup folder
    ./install-project.sh --no-backup /path/to/my/project
    ```

---

## 📢 Note on Precedence
If a skill with the same name exists in both the project's `.agents/skills/` directory and the global registry, the **Project-Attached** version always takes precedence.
