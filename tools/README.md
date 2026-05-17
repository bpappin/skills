# Agentic Engineering Tools

This directory contains synchronization and installation scripts for AI agents.

## ⚠️ Critical Usage Warning

We follow a **"Project-Attached Skills"** model. For standard development, you should **NOT** use these scripts. Instead, copy the `src/skills/` directory into your project as `.skills/`.

Using these tools is **DIFFERENT** from the project-attached model and should only be done if you understand the trade-offs.

| Feature | Project-Attached (Recommended) | Registry Sync (Tools) |
| :--- | :--- | :--- |
| **Location** | Inside your repo (`.skills/`) | Global (`~/.gemini/`) or Claude Settings |
| **Portability** | High (Carried with the code) | Low (Local to your machine) |
| **Versioning** | Locked to the codebase | Global (May conflict across projects) |
| **Onboarding** | Automatic on clone | Manual script execution |

---

## 🛠️ Available Tools

### 1. Gemini CLI Sync (`sync-gemini.sh`)
Packages the exploded skill directories into `.skill` archives and installs them into the Gemini registry.

*   **Usage**:
    ```bash
    # Install to global user scope (available everywhere)
    ./sync-gemini.sh --global

    # Install to current workspace scope (available in current folder)
    ./sync-gemini.sh --local
    ```

### 2. Claude Code Sync (`sync-claude.sh`)
Injects the skill instructions directly into Claude's global `customInstructions` configuration.

*   **Usage**:
    ```bash
    ./sync-claude.sh
    ```

---

## 📢 Note on Precedence
If a skill with the same name exists in both the project's `.skills/` directory and the global registry, the **Project-Attached** version always takes precedence.
