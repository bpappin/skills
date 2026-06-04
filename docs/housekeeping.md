# Housekeeping Prompts

This document contains useful housekeeping prompts to use when wrapping up a chat session, cleaning up code, or transitioning tasks to other sessions/trackers.

---

## 1. Preserving Context & Decisions

When you are about to finish or delete a chat session, use the following prompt to ensure that any important decisions, setup steps, or context are preserved in the codebase documentation:

```text
Task: Preserve Chat Context & Decisions
Summary: Identifies key design choices, setup steps, or architectural context from the current session and writes them to docs/ or AGENTS.md before the chat is deleted.

Prompt:
Are there any design decisions, setup steps, or context from this chat that we should preserve in docs/ or AGENTS.md before I delete this conversation? If so, list them with a short explanation and write them to the appropriate files.
```

### Why This is Important
- **Ephemeral Conversations**: Chat sessions and their histories are temporary. Once a conversation is closed or deleted, the detailed reasoning behind implementation details, configuration, and architectural choices is lost.
- **Continuous Context for AI Agents**: New chat sessions do not inherit the memory of past conversations. By saving key contexts, decisions, and setup instructions in `docs/` or `AGENTS.md`, future agents can immediately ingest this information and build upon it without starting from scratch.
- **Single Source of Truth**: Documenting design decisions and setups directly in the codebase ensures that the repository remains the single source of truth for both developers and AI assistants, preventing knowledge drift.

### Related Local Skills
* **[handoff/SKILL.md](file:///Users/bpappin/Workspace/skills/src/skills/handoff/SKILL.md)**: Compacts the current conversation into a handoff document for another agent to pick up.
* **[manage-docs/SKILL.md](file:///Users/bpappin/Workspace/skills/src/skills/manage-docs/SKILL.md)**: Manages the project's documentation hierarchy, semantic migrations, and proactive recording of architectural/functional decisions.

---

## 2. Code Cleanliness & Cleanup Audit

Before concluding coding tasks, use this prompt to check for leftover debugging artifacts and temporary files:

```text
Task: Code Cleanliness & Cleanup Audit
Summary: Scans modified files for debug logs, temporary comments, print statements, unused imports, or leftover scratch files before final staging.

Prompt:
Before we conclude, please check all modified files in this session for any debug logs, temporary comments, print statements, unused imports, or leftover scratch files that we should clean up or delete. Provide a list of identified items with a title and a brief summary of what needs cleanup.
```

### Why This is Important
- **Code Hygiene**: Prevents development-only logging, temporary markers (like `TODO: temporary fix`), and unused dependencies or imports from being checked into the main codebase.
- **Minimizes Diff Clutter**: Keeps pull requests clean and focused solely on the actual implementation of the requested features.

---

## 3. Commit & PR Documentation Prep

Use this prompt to prepare clear documentation for the Git log and team reviews:

```text
Task: Commit & PR Documentation Prep
Summary: Generates a clear Git commit message and Pull Request description summarizing session changes, rationales, and verification.

Prompt:
Prepare a clear Git commit message and a brief Pull Request description summarizing the changes we made, the rationale behind any design choices, and how they were verified. Ensure each change description includes a clear title and a short summary.
```

### Why This is Important
- **Clear History**: Clear, well-structured commit messages and PR descriptions are essential for long-term project maintenance, helping both humans and future AI agents understand *why* changes were made.
- **Streamlined Code Review**: Accelerates peer review cycles by clearly presenting the scope of changes and how they were tested.

---

## 4. Goal Alignment & Remaining Tasks

Use this prompt to verify feature completeness and track outstanding issues or technical debt:

```text
Task: Goal Alignment & Remaining Tasks
Summary: Compares completed work against original objectives and documents remaining tasks, edge cases, or technical debt.

Prompt:
Compare the work we completed in this session against our original objectives. List any edge cases, outstanding tasks, or potential technical debt that we should document as future work, providing a title and short summary for each.
```

### Why This is Important
- **Completeness**: Ensures all original requirements have been fully addressed and that any out-of-scope or deferred work is explicitly tracked rather than lost.
- **Seamless Planning**: Establishes a clear set of next steps for subsequent work sessions or other team members.

### Related Local Skills
* **[to-issues/SKILL.md](file:///Users/bpappin/Workspace/skills/src/skills/to-issues/SKILL.md)**: Breaks a plan, spec, or PRD into independently-grabbable issues on the project issue tracker.
* **[sync-tracking/SKILL.md](file:///Users/bpappin/Workspace/skills/src/skills/sync-tracking/SKILL.md)**: Pushes local Markdown requirement documents (PRDs and ACs) to a remote issue tracker (YouTrack, GitHub, Jira).

---

## 5. Environment & Configuration Check

Use this prompt to ensure that any runtime/environment configuration updates are not missed:

```text
Task: Environment & Configuration Check
Summary: Checks if any new environment variables, configuration settings, or dependencies were introduced and verifies they are documented.

Prompt:
Did we introduce any new environment variables, configuration settings, or dependencies during this session? If so, verify that they are documented in README.md, setup scripts, or .env.example, listing each update with a title and brief summary.
```

### Why This is Important
- **Onboarding & Deployment**: Missing environment configuration or package installations are a leading cause of broken builds and onboarding friction. Keeping configurations documented ensures frictionless local setups and deployments.
