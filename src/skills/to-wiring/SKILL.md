---
name: to-wiring
description: Audit, check, and maintain the application's internal feature wiring rules in WIRING.md. Use when starting a project, proposing a new feature plan, or auditing feature-to-feature integration hooks.
---

# Application Wiring (to-wiring)

## Objective
Provide an interactive and project-specific workflow to define, check, and maintain the internal connections ("wiring") between features in the codebase. This ensures that integration hooks between features are planned upfront and never forgotten as the app grows.

## Core Hierarchy
1.  **Project Wiring Rulebook (WIRING.md)**: A root-level markdown file in the project workspace that defines:
    - The project's specific connection mechanisms (e.g., direct imports, dependency injection, callbacks).
    - Global services and features that other modules must integrate with.
    - Explicit feature-to-feature connection rules.
2.  **AI Instructions (AGENTS.md / GEMINI.md)**: Rules in the project's root instructions mandating that agents read and respect `WIRING.md` when planning new code.

---

## Workflows

### 1. Bootstrapping & Configuration
Triggered when the user asks to "setup wiring", "initialize wiring rules", or if a wiring command is run and `WIRING.md` does not exist.
1.  **Verify Configuration**: Ensure the project is initialized (check `.agents/config/project.json` or legacy `.config/project.json`).
2.  **Trigger Q&A Interview**: Ask the user the following questions to understand how the project's architecture connects features together.
    - *Question 1 (Wiring Mechanisms)*: *"How do different features/components typically connect and interact in this codebase? (e.g., direct imports/method calls, callback interfaces, dependency injection frameworks like Hilt or Dagger, global notifications?)"*
    - *Question 2 (Existing Global Services)*: *"Are there any 'global' services or shared modules in the app that other features should integrate with? (e.g., a shared DatabaseHelper, Analytics, Logger, User Session, Notifications?)"*
    - *Question 3 (Locations)*: *"Where do these global systems typically live in your directory structure (e.g., core/, shared/, utils/)?"*
3.  **Generate WIRING.md**:
    - Load the local template file `<master-dir>/to-wiring/WIRING_TEMPLATE.md` (or copy from project skills if local).
    - Substitute the user's answers into the template structure.
    - Write the resulting `WIRING.md` to the project root.
4.  **Inject Mandates**: Call the audit/update routine to add the wiring rules to `AGENTS.md` (or `GEMINI.md`).

### 2. Interactive Wiring Audit (`to-wiring audit`)
Triggered by "audit wiring", "update WIRING.md", or after bootstrapping.
1.  **Code/Docs Scan**: Scan `src/`, `lib/`, `docs/prd/`, and `docs/ac/` to detect potential wiring candidates:
    - Files or classes in common/shared directories.
    - Features mentioned in specs as dependent on other modules.
    - Widely imported classes or services.
2.  **Verify Connection Patterns**: If the mechanisms of communication are not clear from the codebase, prompt the user for clarification.
3.  **Candidate-Screening Q&A**: For each potential wiring candidate detected, ask the user:
    - *"I detected [Feature/Module X] at [path]. Should we track this as a wiring target or global service in WIRING.md? If yes, what triggers or connection rules apply?"*
    - **Interactive Option**: If the client supports the `ask_question` tool, use a multi-select list or write-in choices to screen candidates. Otherwise, walk through them in chat.
4.  **Update WIRING.md**: Append all approved candidates and their connection rules under the **Feature Connections & Triggers** section.
5.  **Inject AGENTS.md Rules**: Ensure the project's root `AGENTS.md` (or `GEMINI.md`) file contains the following block:
    ```markdown
    - **Wiring & Integration Checks**:
      - Before proposing any implementation plan, you MUST read `WIRING.md`.
      - Check the proposed feature against all wiring and connection rules.
      - Include an "Integration Hooks" section in the plan showing how the feature hooks up to the systems listed.
      - Suggest adding the new feature to `WIRING.md` if it qualifies as a global service.
    ```

### 3. Planning Checks (`to-wiring check`)
Triggered automatically during implementation planning of a new feature, or when running "check wiring".
1.  **Read Rules**: Read `WIRING.md`.
2.  **Cross-Reference**: Compare the proposed feature's PRD and spec against the integration triggers of all listed global services and other features.
3.  **Identify Integration Hooks**: For any matched trigger, define how the hookup will be built (using the project's specific connection patterns).
4.  **Detect Global Candidates**: Evaluate if the new feature itself is a **Global Feature** (e.g., if it provides database tables, telemetry, notifications, shared state, or is designed to be called by multiple future modules).
    - If it is a global candidate, prompt the user: *"This new feature behaves like a global service. Should we register it in WIRING.md so other features hook into it?"*
5.  **Document in Plan**: Add an `Integration Hooks` section to the implementation plan, proving that all connection rules are satisfied.

---

## Rules & Constraints
- **Zero Architectural Assumptions**: Do not assume the project uses an event bus, dependency injection, pub/sub, or any specific library. Adapt completely to the connection patterns specified by the user.
- **Maintain Context**: Never auto-delete existing wiring rules in `WIRING.md` unless the user explicitly confirms the feature is deprecated or removed.
- **Strict Screening**: Always screen candidate features through the Q&A process. Never unilaterally add a wiring rule without user confirmation.

---

## Discovery Trail
- **2026-06-06**: Created the initial `to-wiring` skill defining bootstrapping Q&A, interactive candidate-screening audits, planning checks, and `AGENTS.md` integrations.
