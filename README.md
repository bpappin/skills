# Agentic Engineering Skills

A centralized library of specialized instructions, workflows, and tools for AI agents (Gemini CLI and Claude Code). This repository serves as the base upstream source for seeding project-attached intelligence.

---

## 🙏 Attributions & Inspiration

Many of the core engineering and productivity skills in this repository were seeded, inspired by or adapted from the excellent work of **[Matt Pocock](https://github.com/mattpocock/skills)**. I highly recommend exploring his original repository for foundational AI agent skill patterns.

---

## 🧠 Philosophy: Project-Attached Skills

I follow a **"Project-Attached"** model for agent intelligence. Instead of installing skills into a global registry, they are carried within each repository's .skills/ directory. This ensures:
1.  **Portability**: Any developer who clones the project immediately inherits its specialized intelligence.
2.  **Context-Safety**: Agents are locked to the specific patterns and mandates of the project they are currently working on.
3.  **Versioning**: Skills evolve with the codebase they support.
4.  **Atomic Specs**: Technical specifications (PRDs and ACs) live in the repository (docs-as-code) to ensure atomic versioning and review alongside implementation changes.

---

## 🚀 Usage: Seeding a New Project

To add these skills to a new or existing project, follow the **Seed & Initialize** workflow.

### 1. Seed the Project
Copy the src/skills/ directory from this repository into the root of your target project, renaming it to .skills/:

```bash
# From this repository
cp -R src/skills/ /path/to/your/project/.skills/
```

### 2. Initialize the Agent
Open your AI agent (Gemini CLI or Claude Code) in the target project and command it to run the setup skill:

```text
Run project setup
```

### 3. Automated Onboarding
The **setup-project** skill will take over and autonomously:
*   Identify the project (ID, Sync Targets). The `project_id` is the most important as it will create `~/.secret/agents/<project_id>` and `~/.config/agents/<project_id>`.
*   Create the **AI-Optimized Documentation Hierarchy** (mandates/, prd/, ac/, discovery/, gap/, etc.).
*   Generate or audit the **AGENTS.md** context-mapping file.
*   **Intelligent Migration**: Offer to analyze and organize existing documentation into the new hierarchy.

---

## 📂 Repository Structure

- [src/skills/](./src/skills/): The "exploded" source files for each skill. This is the directory you copy into your projects.
- [tools/](./tools/): (Optional) Scripts for legacy global installation or bulk packaging.
- [src/obsolete/](./src/obsolete/): Legacy monolithic skill files preserved for reference.

## 🧩 Core Skill Categories

### 🛠️ Configuration & Onboarding
* **manage-docs**: Manage the 6-sector documentation hierarchy, perform semantic migrations of legacy documentation, and provide proactive recording of architectural and functional decisions.
* **manage-skills**: Manage the lifecycle, organization, and synchronization of AI agent skills between local project workspaces and master skill sources.
* **persona**: Initialize and manage persona state via a global persona.json file.
* **setup-project**: Onboard and configure a project workspace for tracking, sync, and agent interaction.

### 📐 Engineering & Standards
* **grill-with-docs**: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise.
* **improve-codebase-architecture**: Find deepening opportunities in a codebase, informed by the domain language in CONTEXT.md and the decisions in docs/adr/.
* **prototype**: Build a throwaway prototype to flesh out a design before committing to it.
* **tdd**: Test-driven development with red-green-refactor loop.
* **to-issues**: (deprecated in favor of to-prd specs) Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices.
* **to-design**: Formalizes the design-capturing process as a structured agent capability to ensure visual samples are generated and properly registered.
* **to-prd**: The primary workhorse. Synthesizes context into an **ID-First Spec Pair** (PRD and matching AC).
* **triage**: Triage issues through a state machine driven by triage roles.
* **zoom-out**: Tell the agent to zoom out and give broader context or a higher-level perspective.

### ⚖️ Governance & R&D
* **rad-research**: Manage Technical Research & Development (R&D) logs.
* **regulatory-compliance**: Manage and track regulatory requirements (PIPEDA, GDPR, etc.).

### Misc, Odds & Ends
* **git-guardrails-claude-code**: Set up Claude Code hooks to block dangerous git commands.
* **git-guardrails-gemini**: Codifies the strict Git safety rules for Gemini CLI.

### ⚡ Productivity
* **caveman**: Ultra-compressed communication mode to save tokens.
* **grill-me**: Interview the user relentlessly about a plan or design.
* **handoff**: Compact the current conversation into a handoff document for another agent to pick up.
* **write-a-skill**: Create new agent skills with proper structure, progressive disclosure, and bundled resources.

### 📊 Tracking & Roadmap
* **sync**: Publish local Markdown issue documents (Format A and Format B) to a remote issue tracker.

---

## 🚀 Extended Capabilities

### 🆔 ID-First Traceability
Our **to-prd** skill implements an "ID-First" workflow. Before creating local documentation, the agent acquires an authoritative ID from your remote issue tracker (GitHub/YouTrack). This ensures that code, commits, and documents are linked to a permanent identity from the first line of code.

### 🖇️ Atomic Spec-Pairing
Technical requirements are recorded as an unbreakable pair:
1.  **Requirement (PRD)**: The user story and implementation decisions.
2.  **Verification (AC)**: The testable success criteria (Gherkin-style).
This pairing ensures that the "What" is always strictly linked to the "Proof."

### 📂 AI-Optimized Documentation Hierarchy
A unique documentation model designed specifically to maximize AI context retrieval accuracy while preventing documentation bloat:
*   **Mandates**: Global "Law" (ARCH, SPEC).
*   **Stories (PRD)**: Feature requirements.
*   **Criteria (AC)**: Success outcomes.
*   **Discovery (DD)**: Research and due-diligence records.
*   **Roadmap (GAP)**: Functional gaps and technical debt.

---
*Maintained by Brill Pappin.*