# AI Skills for Agentic Engineering

A centralized library of specialized instructions, workflows, and tools for AI agents (Gemini CLI and Claude Code). This repository serves as the template upstream source for seeding project-attached intelligence.

---

## 🙏 Attributions & Inspiration

Many of the core engineering and productivity skills in this repository were inspired by or adapted from the excellent work of **[Matt Pocock](https://github.com/mattpocock/skills)**. We highly recommend exploring his original repository for foundational AI agent patterns.

---

## 🧠 Philosophy: Project-Attached Skills

We follow a **"Project-Attached"** model for agent intelligence. Instead of installing skills into a global registry, they are carried within each repository's .skills/ directory. This ensures:
1.  **Portability**: Any developer who clones the project immediately inherits its specialized intelligence.
2.  **Context-Safety**: Agents are locked to the specific patterns and mandates of the project they are currently working on.
3.  **Versioning**: Skills evolve with the codebase they support.

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
*   Identify the project (ID, Sync Targets).
*   Create the **6-Sector Documentation Hierarchy** (mandates/, ac/, discovery/, gap/, etc.).
*   Generate or audit the **AGENTS.md** context-mapping file.
*   Enable optional governance features (R&D Logs, Compliance Tracking).

---

## 📂 Repository Structure

- [src/skills/](./src/skills/): The "exploded" source files for each skill. This is the directory you copy into your projects.
- [tools/](./tools/): (Optional) Scripts for legacy global installation or bulk packaging.
- [src/obsolete/](./src/obsolete/): Legacy monolithic skill files preserved for reference.

## 🧩 Core Skill Categories

### 🛠️ Configuration & Onboarding
*   **setup-project**: Bootstraps new workspaces and enforces documentation standards.
*   **manage-docs**: Intelligently distributes project knowledge across the 6-sector hierarchy.
*   **manage-skills**: Manages the lifecycle and synchronization of skills between project and master sources.
*   **persona**: Manages global user state for specialized roles (Developer, Designer, BA).

### 📐 Engineering & Standards
*   **tdd**: Enforces Test Driven Development and deep-module boundaries.
*   **grill-with-docs**: Stress-tests plans against existing domain models and ADRs.
*   **improve-codebase-architecture**: Guidance for refactoring toward clean, maintainable patterns.
*   **prototype**: Rapid implementation of substantial vertical slices or mockups.
*   **to-issues**: Strategy for breaking plans into "tracer-bullet" vertical slices.
*   **to-prd**: Synthesizes conversation context into a formal Product Requirements Document.
*   **triage**: Professional issue management and initial investigation.
*   **zoom-out**: High-level architectural mapping and dependency analysis.

### 📊 Tracking & Roadmap
*   **generate-epic**: Creates Format B Agile Epic containers.
*   **generate-issue**: Creates Format A Task/Bug documents.
*   **sync**: Pushes local Markdown issues to remote trackers (YouTrack, GitHub).

### ⚖️ Governance & R&D
*   **regulatory-compliance**: Audits code and ADRs against international privacy standards.
*   **rad-research**: Standardizes the logging of hypotheses and R&D outcomes (RAD).

### ⚡ Productivity
*   **caveman**: Ultra-compressed communication mode to save tokens.
*   **grill-me**: Relentless interviewing to resolve decision tree branches.
*   **handoff**: Compacts context into a document for agent-to-agent transition.
*   **write-a-skill**: Creates new skills with proper structure and triggers.

### 🛡️ Safety & Guardrails
*   **git-guardrails-gemini**: Strict instruction-based safety for Gemini CLI Git operations.
*   **git-guardrails-claude-code**: Hard-execution blocks for dangerous Git commands in Claude Code.

---

## 🚀 Extended Capabilities

While we leverage foundational agent patterns, this repository introduces several specialized domains designed for enterprise engineering:

### 🛡️ Governance & Regulatory Compliance
We have added deep-dive auditing capabilities for international privacy standards. Our agents can autonomously track implementation status against **PIPEDA** (Canada), **GDPR** (EU), and **Law 25** (Quebec), ensuring that "Structural Blindness" and "Privacy by Design" are enforced at the code and documentation layer.

### 🧪 Technical R&D Logging (RAD)
Standardized logging of technical challenges, hypotheses, and architectural outcomes. This ensures a permanent audit trail for complex engineering choices, supporting both internal knowledge transfer and architectural history.

### 🏗️ Enterprise Documentation Hierarchy
A unique 6-sector documentation model (mandates/, ac/, discovery/, gap/, regulations/, guides/, reference/, research/, standards/) designed specifically to maximize AI context retrieval accuracy while preventing the "monolithic README" anti-pattern.

### 🗺️ Decoupled Roadmap (GAPs)
A tiered strategy for project roadmap management, moving beyond flat checklists to individual, searchable files that track functional gaps and technical debt independently of the active issue backlog.

---
*Maintained by Brill Pappin.*