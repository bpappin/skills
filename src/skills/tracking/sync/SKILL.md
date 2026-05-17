---
name: sync
description: Push local Markdown issue documents (Format A and Format B) to a remote issue tracker (YouTrack, GitHub, Jira) using local Python scripts. Use when you are ready to publish finalized issue documents.
---

# Issue Synchronization

## Objective
Provide the agent with the knowledge and execution steps required to push local Markdown issues (Format A and Format B) to the remote issue tracker (YouTrack, GitHub, Jira) using the local Python synchronization scripts.

## Core Mechanics

### 1. Verification of Requirements
Before attempting a sync, the agent MUST verify:
*   The `.config/project.json` config exists and defines a `sync_target` (e.g., `youtrack`, `github`).
*   The appropriate sync script exists locally in `.skills/tracking/` (e.g., `yt.py` or `gh.py`).
*   The secrets vault directory (`~/.secrets/agents/<project_id>/`) exists and contains the necessary `.env` file for the active target.

### 2. Execution Preparation
The agent must prepare the environment for the script execution:
*   Identify the target Markdown files to sync (typically located in `docs/issues/`).
*   Ensure the Python environment is ready.

### 3. Running the Sync Script
Execute the script from the root of the project workspace. 

*   **Dry Run:** ALWAYS propose a dry-run first if the script supports it (e.g., passing a `--dry-run` flag) to ensure parsing succeeds without making remote mutations.
*   **Execution:** Run the script, passing the target file or directory as an argument.
    ```bash
    # Example invocation (exact arguments depend on the script implementation)
    python3 .skills/tracking/yt.py docs/issues/epic-name/
    ```

### 4. Post-Sync Validation
*   Check the output of the script to confirm successful sync.
*   Verify that `[#NEW]` tags in the local Markdown files have been successfully replaced with real remote IDs (e.g., `[ID-123]`) by the script.
*   If the script fails due to parsing errors, the agent must review the Markdown files to ensure they strictly adhere to **Format A** or **Format B** and correct any formatting issues.
