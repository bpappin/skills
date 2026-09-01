---
name: housekeeping
description: Perform workspace housekeeping, cleanup audits, and prepare handoff/commit documentation at the end of a work session. Use when concluding tasks, preparing for commits, or before wrapping up/transitioning a chat.
license: MIT
metadata:
  author: bpappin
  version: "1.0"
---

# Housekeeping

## Quick start

When concluding a session: review modified files, clean up debug artifacts,
reconcile the work with the story being worked, preserve decisions, and prepare
the Git commit message and PR description.

## Workflows

Execute the following steps in order at the end of a work session.

> [!IMPORTANT]
> **Execution Rule**: Before executing each step, ask the user if they want
> to run that specific step. If they decline, skip it and move immediately
> to the next step.

### Step 1: Code cleanliness & cleanup audit

Inspect the codebase and remove development artifacts before documenting:

- [ ] Remove temporary comments (`TODO: temporary fix`, personal notes).
- [ ] Remove development-only logs, print/console statements.
- [ ] Remove unused variables, imports, or dependencies.
- [ ] Clean up or delete scratch files created in the workspace.

### Step 2: Environment & configuration check

Did the session introduce environment variables, configuration settings,
or dependencies?

- [ ] New environment variables documented (README, setup scripts, .env.example).
- [ ] Package manifests updated and dependencies documented.

### Step 3: Story reconciliation & remaining work

Compare the session's work against its objectives — which, when a story
file is being worked, means its AC checklist (the to-stories skill):

- [ ] AC items verifiably completed this session are ticked in the story
      file. Tick only what you actually verified: the checkbox is the only
      completion signal here, so an optimistic tick is worse than an open
      box, because it stops the item being looked at.
- [ ] The story's `status` is current — `doing` while in flight, `done`
      only when every AC is ticked.
- [ ] Deferred work, edge cases and technical debt become **new story
      files**, not a local TODO list. Widening the story you are on is how
      scope discipline is lost.

### Step 4: Context preservation & decisions

Preserve key discussions, setup steps, and architectural choices before
the conversation is lost. File per the project-docs skill's taxonomy:

- [ ] Design decisions → `docs/decisions/` (the to-adr skill);
      investigations that led to them → `docs/research/` (to-rad).
- [ ] Update `AGENTS.md` if project setup steps changed.
- [ ] If transitioning to another agent/session, use the `handoff` skill.

### Step 5: Commit & PR documentation prep

Prepare version control and team documentation from the clean, complete
state:

- [ ] Draft a structured commit message (e.g., conventional commits),
      referencing the story number.
- [ ] Write a PR description detailing scope, rationale, and verification
      results — the story's AC checklist is the verification summary;
      link the story rather than restating it.
