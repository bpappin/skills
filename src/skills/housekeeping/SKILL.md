---
name: housekeeping
description: Perform workspace housekeeping, cleanup audits, and prepare handoff/commit documentation at the end of a work session. Use when concluding tasks, preparing for commits, or before wrapping up/transitioning a chat.
---

# Housekeeping

## Quick start

When concluding a session, review modified files, clean up debug logs, align work with objectives, and prepare the Git commit message and PR description.

## Workflows

The agent MUST execute the following housekeeping prompts in logical order at the end of a work session:

> [!IMPORTANT]
> **Execution Rule**: Before executing each step, the agent MUST ask the user if they want to run that specific step. If the user declines, says "no", or requests to skip, the agent must skip it and move immediately to the next step.

### Step 1: Code Cleanliness & Cleanup Audit
First, inspect the codebase and remove any development artifacts to ensure the code is clean before documenting it:
- **Prompt**:
  ```text
  Before we conclude, please check all modified files in this session for any debug logs, temporary comments, print statements, unused imports, or leftover scratch files that we should clean up or delete.
  ```
- **Checklist**:
  - [ ] Remove temporary comments like `TODO: temporary fix` or personal notes.
  - [ ] Remove development-only logs, print/console statements.
  - [ ] Remove unused variables, imports, or dependencies.
  - [ ] Clean up or delete scratch files created in the workspace.

### Step 2: Environment & Configuration Check
Next, verify if any system configuration changes or new dependencies were introduced:
- **Prompt**:
  ```text
  Did we introduce any new environment variables, configuration settings, or dependencies during this session? If so, verify that they are documented in README.md, setup scripts, or .env.example.
  ```
- **Checklist**:
  - [ ] New environment variables documented.
  - [ ] Package manifest files updated and dependencies documented.

### Step 3: Goal Alignment & Remaining Tasks
Assess the completed work against the original requirements and document outstanding tasks or debt:
- **Prompt**:
  ```text
  Compare the work we completed in this session against our original objectives. List any edge cases, outstanding tasks, or potential technical debt that we should document as future work.
  ```
- **Checklist**:
  - [ ] Check off all tasks in `task.md`.
  - [ ] Record deferred work as GAPs in `docs/gap/` or log them in the project issue tracker (e.g., using `to-issues` skill).

### Step 4: Context Preservation & Decisions
Save key discussions, setup instructions, or architectural choices so that future sessions/agents can pick up the context:
- **Prompt**:
  ```text
  Are there any design decisions, setup steps, or context from this chat that we should preserve in docs/ or AGENTS.md before I delete this conversation? If so, write them to the appropriate files.
  ```
- **Checklist**:
  - [ ] Document design decisions in `docs/adr/` (ADRs) or `docs/discovery/` (DDs).
  - [ ] Update `AGENTS.md` if any project setup steps changed.
  - [ ] If transitioning to another agent/session, use the `handoff` skill to generate a handoff doc.

### Step 5: Commit & PR Documentation Prep
Finally, prepare the version control and team documentation based on the clean, complete state of the workspace:
- **Prompt**:
  ```text
  Prepare a clear Git commit message and a brief Pull Request description summarizing the changes we made, the rationale behind any design choices, and how they were verified.
  ```
- **Checklist**:
  - [ ] Draft a structured commit message (e.g., conventional commits).
  - [ ] Write a PR description detailing scope, rationale, and verification results.
