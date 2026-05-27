# Agentic Engineering Skills

A centralized library of specialized instructions, workflows, and tools for AI agents (Gemini CLI and Claude Code) conforming to the [Agent Skills Standard](https://agentskills.io/). This repository serves as the base upstream source for seeding project-attached intelligence.

---

## 🙏 Attributions & Inspiration

Many of the core engineering and productivity skills in this repository were seeded, inspired by or adapted from the excellent work of **[Matt Pocock](https://github.com/mattpocock/skills)**. I highly recommend exploring his original repository for foundational AI agent skill patterns.

---

## 🧠 Philosophy: Project-Attached Skills

I follow a **"Project-Attached"** model for agent intelligence. Instead of installing skills into a global registry, they are carried within each repository's .agents/skills/ directory. This ensures:
1.  **Portability**: Any developer who clones the project immediately inherits its specialized intelligence.
2.  **Context-Safety**: Agents are locked to the specific patterns and mandates of the project they are currently working on.
3.  **Versioning**: Skills evolve with the codebase they support.
4.  **Atomic Specs**: Technical specifications (PRDs and ACs) live in the repository (docs-as-code) to ensure atomic versioning and review alongside implementation changes.

---

## ⚙️ Installation & Usage

Depending on your workflow, you can use these skills under the **Project-Attached** model (recommended) or install them globally for all workspaces.

### Option A: Project-Attached (Recommended)

To carry these skills inside a specific repository so they are version-controlled and portable:

1. **Seed the Project**: Copy the `src/skills/` directory from this repository into the root of your target project, renaming it to `.agents/skills/`:
   ```bash
   cp -R src/skills/ /path/to/your/project/.agents/skills/
   ```

2. **Initialize the Agent**: Start your agent (Gemini CLI or Claude Code) in the target project and command it:
   ```text
   Run project setup
   ```

3. **Automated Onboarding**: The **setup-project** skill will take over and automatically:
   * Identify the project (ID, Sync Targets).
   * Create the AI-optimized documentation hierarchy (`mandates/`, `prd/`, `ac/`, `discovery/`, `gap/`, etc.).
   * Generate or audit the `AGENTS.md` context-mapping file.

---

### Option B: Global Registry Installation (Gemini CLI)

If you want these skills globally available in any directory without attaching them to individual projects:

1. Run the Gemini installation tool from this repository:
   ```bash
   ./tools/install-gemini.sh --global
   ```
2. In your active Gemini session, reload your registry:
   ```text
   /skills reload
   ```

---

### Option C: Global Claude Code Integration

To integrate these instructions directly into Claude Code's global configuration:

1. Run the Claude installation tool from this repository:
   ```bash
   ./tools/install-claude.sh
   ```

---

## 📂 Repository Structure

- [src/skills/](./src/skills/): The source files for each skill. This is the directory you copy into your projects.
- [tools/](./tools/): Scripts for global installation or Claude Code integration.

## 🧩 Core Skill Categories

### 🛠️ Configuration & Onboarding
* **manage-docs**: Manage the 13-sector documentation hierarchy, perform semantic migrations of legacy documentation, and provide proactive recording of architectural and functional decisions.
* **manage-skills**: Manage the lifecycle, organization, and synchronization of AI agent skills between local project workspaces and master skill sources.
* **manage-persona**: Initialize and manage persona state via a global persona.json file.
* **setup-project**: Onboard and configure a project workspace for tracking, sync, and agent interaction.

### 📐 Engineering & Standards
* **grill-with-docs**: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise.
* **improve-codebase-architecture**: Find deepening opportunities in a codebase, informed by the domain language in CONTEXT.md and the decisions in docs/adr/.
* **prototype**: Build a throwaway prototype to flesh out a design before committing to it.
* **tdd**: Test-driven development with red-green-refactor loop.
* **to-ai-skill**: Scaffold and maintain machine-readable AI skill instructions bundled within this library for consuming AI agents.
* **to-design**: Formalizes the design-capturing process as a structured agent capability to ensure visual samples are generated and properly registered.
* **to-issues**: Break a plan, spec, or PRD into independently-grabbable issues on the project issue tracker using tracer-bullet vertical slices.
* **to-prd**: The primary workhorse. Synthesizes context into an **ID-First Spec Pair** (PRD and matching AC).
* **triage**: Triage issues through a state machine driven by triage roles.
* **zoom-out**: Tell the agent to zoom out and give broader context or a higher-level perspective.

### ⚖️ Governance & R&D
* **to-research**: Manage Technical Research & Development (R&D) logs.
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
* **sync-tracking**: Push local Markdown requirement documents (PRDs and ACs) to a remote issue tracker (YouTrack, GitHub, Jira) using local Python scripts.

---

## 🚀 Extended Capabilities

### 🆔 ID-First Traceability
Our **to-prd** skill implements an "ID-First" workflow. Local requirement documents are initialized with `id: #NEW` in their YAML frontmatter. Running the sync script publishes the ticket to the remote issue tracker (GitHub/YouTrack) and automatically updates the local frontmatter `id` field with the authoritative remote ID. This ensures that specs, code, and commits are linked to a permanent remote identity from the beginning.

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