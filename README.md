# Agentic Engineering Skills

A curated library of agent skills conforming to the
[Agent Skills Standard](https://agentskills.io/), plus **story-tools** — a
tracker-backed workflow system that keeps AI-assisted development sessions
from spiralling in scope. Skills are grouped by function; each skill is
self-contained (its scripts, references, and assets live inside its own
directory) and works with any agent that supports the standard.

Every skill here must meet the requirements in
[docs/skill-standards.md](docs/skill-standards.md) — spec conformance
(`skills-ref validate`), strict self-containment, progressive-disclosure
budgets, trigger-optimized descriptions, and non-interactive script
interfaces.

## Philosophy: project-attached skills

Skills are carried inside each repository (`.agents/skills/`), not a global
registry:

1. **Portability** — anyone who clones the project inherits its skills.
2. **Context-safety** — agents are locked to the patterns of the project
   they're working on.
3. **Versioning** — skills evolve with the codebase they support.
4. **Work lives in the tracker, knowledge lives in the repo** — stories and
   acceptance criteria belong to the issue tracker; PRDs, ADRs, and research
   stay in `docs/` and publish to the tracker's knowledge base.

## The story-tools suite

Twelve of these skills form a coupled system installed together by the
wizard:

```
./scripts/install.sh
```

The wizard is the only place credentials are handled — skills never ask for
tokens. It stores connections under `~/.agents/story-tools/`, registers the
MCP server per agent (Claude Code, Gemini CLI, VS Code/Copilot, Codex),
deploys the YouTrack app when permissions allow, and binds projects via a
non-secret pointer at `<repo>/.agents/config/story-tools.json`. Re-running
it reviews every stored value.

The pipeline: **triage** (inbound) / **to-prd** → **to-issues** (planning) →
**grill-with-docs** (domain model) → **story-workflow** (execution, with the
discovered-work off-ramp) → **housekeeping** + **handoff** (session close) →
**story-reconcile** (adoption/migration) → **project-docs** + **to-research**
+ **regulatory-compliance** (knowledge & compliance).

## Repository map

| Directory | Contents |
|---|---|
| `skills/stories/` | Tracker discipline: story-workflow, story-reconcile, to-issues, triage |
| `skills/docs/` | Documentation system: project-docs, to-prd, to-research, grill-with-docs, to-wiring, regulatory-compliance |
| `skills/sessions/` | Session lifecycle & communication: handoff, housekeeping, grill-me, zoom-out, caveman |
| `skills/engineering/` | Practice: tdd, prototype, improve-codebase-architecture, to-design |
| `skills/authoring/` | Making skills: write-a-skill, to-ai-skill |
| `skills/setup/` | Agent/tool configuration: git-guardrails (Claude Code, Gemini), setup-github-copilot, setup-gitlab-duo |
| `trackers/youtrack/` | YouTrack binding infrastructure: the story-tools MCP app, `deploy.sh`, `smoke.sh`, tests |
| `scripts/` | `install.sh` — the suite wizard |
| `docs/` | System docs: architecture ADRs, permissions, system diagram, [skill standards](docs/skill-standards.md) |

`trackers/` is deliberately plural: the suite's skills are tracker-agnostic
(neutral operations dispatched through per-tracker binding files); YouTrack
is the first binding, GitHub/Jira can follow without touching the skills.

## Using independent skills

Skills outside the suite attach à la carte — copy the ones you want into a
project:

```bash
cp -R skills/engineering/tdd /path/to/project/.agents/skills/
```

Agents that read `.agents/skills/` (or a `.claude/skills` / `.github/skills`
symlink, which the wizard creates) pick them up on restart.

## Attributions

Several skills were seeded by, inspired by, or adapted from the excellent
work of [Matt Pocock](https://github.com/mattpocock/skills) — his repository
is worth exploring for foundational agent-skill patterns.

---
*Maintained by Brill Pappin.*
