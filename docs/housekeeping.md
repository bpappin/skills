# Housekeeping Prompts

This document contains useful housekeeping prompts to use when wrapping up a chat session, cleaning up code, or transitioning tasks to other sessions/trackers.

---

## 1. Preserving Context & Decisions

When you are about to finish or delete a chat session, use the following prompt to ensure that any important decisions, setup steps, or context are preserved in the codebase documentation:

```text
Are there any design decisions, setup steps, or context from this chat that we should preserve in docs/ or AGENTS.md before I delete this conversation? If so, write them to the appropriate files.
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
Before we conclude, please check all modified files in this session for any debug logs, temporary comments, print statements, unused imports, or leftover scratch files that we should clean up or delete.
```

### Why This is Important
- **Code Hygiene**: Prevents development-only logging, temporary markers (like `TODO: temporary fix`), and unused dependencies or imports from being checked into the main codebase.
- **Minimizes Diff Clutter**: Keeps pull requests clean and focused solely on the actual implementation of the requested features.

---

## 3. Commit & PR Documentation Prep

Use this prompt to prepare clear documentation for the Git log and team reviews:

```text
Prepare a clear Git commit message and a brief Pull Request description summarizing the changes we made, the rationale behind any design choices, and how they were verified.
```

### Why This is Important
- **Clear History**: Clear, well-structured commit messages and PR descriptions are essential for long-term project maintenance, helping both humans and future AI agents understand *why* changes were made.
- **Streamlined Code Review**: Accelerates peer review cycles by clearly presenting the scope of changes and how they were tested.

---

## 4. Goal Alignment & Remaining Tasks

Use this prompt to verify feature completeness and track outstanding issues or technical debt:

```text
Compare the work we completed in this session against our original objectives. List any edge cases, outstanding tasks, or potential technical debt that we should document as future work.
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
Did we introduce any new environment variables, configuration settings, or dependencies during this session? If so, verify that they are documented in README.md, setup scripts, or .env.example.
```

### Why This is Important
- **Onboarding & Deployment**: Missing environment configuration or package installations are a leading cause of broken builds and onboarding friction. Keeping configurations documented ensures frictionless local setups and deployments.
