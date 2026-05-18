# Agent Capabilities Index

### Config
- **manage-docs**: Manage the 6-sector documentation hierarchy, perform semantic migrations of legacy documentation, and provide proactive recording of architectural and functional decisions.

- **manage-skills**: Manage the lifecycle, organization, and synchronization of AI agent skills between local project workspaces and master skill sources.

- **persona**: Initialize and manage persona state via a global persona.json file. Adapts agent behavior, technical focus, and output style to match the user's active role.

- **setup-project**: Onboard and configure a project workspace for tracking, sync, and agent interaction.

### Engineering
- **tdd**: Test-driven development with red-green-refactor loop. Ensures code quality and adherence to verified behavior.

- **prototype**: Build a throwaway prototype to flesh out a design before committing to it.

- **improve-codebase-architecture**: Find refactoring opportunities and consolidate modules to make the codebase more testable and AI-navigable.

- **to-prd**: Turn conversation context and codebase understanding into a formal PRD and matching AC spec.

- **to-issues**: Break a plan, spec, or PRD into independently-grabbable implementation issues on the task board.

- **triage**: Triage issues through a state machine driven by triage roles.

- **zoom-out**: Give broader context or a higher-level perspective when unfamiliar with a section of code.

- **grill-with-docs**: Grilling session that challenges a plan against the existing domain model and documentation.

### Governance
- **rad-research**: Manage Technical Research & Development (R&D) logs, document hypotheses, and log architectural decisions.

- **regulatory-compliance**: Manage and track regulatory requirements (PIPEDA, GDPR, etc.) and audit compliance across ADRs/Code.

### Tracking
- **sync**: Push local Markdown issue documents to a remote issue tracker (YouTrack, GitHub, Jira).

- **generate-epic**: Generate comprehensive Agile Epic documents that act as an index for multiple child stories.

- **generate-issue**: Generate local Markdown issue documents (Format A) for standalone tasks or bugs.

### Productivity
- **write-a-skill**: Create new agent skills with proper structure, progressive disclosure, and bundled resources.

- **handoff**: Compact the current conversation into a handoff document for another agent to pick up.

- **caveman**: Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler while keeping full technical accuracy.

- **grill-me**: Interview the user relentlessly about a plan or design until reaching shared understanding.

### Misc
- **git-guardrails-gemini**: Codifies the strict Git safety rules for Gemini CLI to prevent destructive operations.
