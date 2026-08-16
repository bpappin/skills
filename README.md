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
   stay in `docs/` and sync to the tracker's knowledge base.

## Install

One line. Clone the suite, set up your tracker, register every agent you have.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bpappin/skills/master/bootstrap.sh)"
```

macOS, Linux, WSL, Git Bash. A couple of minutes, mostly answering
questions. Needs `git`, `curl`, `python3`. Skips agents you do not have.
Safe to re-run — that is how you update.

Then `cd` into a project, run it again to bind that project, restart your
agent, and say *"what am I working on?"*

**Joining a project that already uses this?** You do not need this repo:
clone the project and run `.agents/setup.sh`.

[Full install guide](docs/INSTALL.md) — clone-then-run for org policies
that ban piped installers, requirements per tracker, offline use, and
troubleshooting.

## The story-tools suite

Sixteen of these skills form a coupled system, installed together by the
wizard.

The wizard is the only place credentials are handled — skills never ask for
tokens. It stores connections under `~/.agents/story-tools/`, registers the
MCP server per agent (Claude Code, Gemini CLI, Antigravity, VS Code/Copilot,
Codex), deploys the YouTrack app when permissions allow, and binds projects
via a non-secret pointer at `<repo>/.agents/config/story-tools.json`.
Re-running it in a bound project offers a refresh, or a full reconfigure.

The pipeline: **triage** (inbound) / **to-prd** → **to-issues** (planning) →
**grill-with-docs** (domain model) → **story-workflow** (execution, with the
discovered-work off-ramp) → **housekeeping** + **handoff** (session close) →
**story-reconcile** (adoption/migration) → **project-docs** + **to-research**
+ **regulatory-compliance** (knowledge & compliance).

### Trackers

Skills are tracker-agnostic: neutral operations dispatched through
per-tracker binding files. **YouTrack** and **GitHub** (Issues + Projects v2,
with an issues-only fallback) are both built and live-verified; Jira can
follow without touching the skills.

Documentation syncs two ways with the tracker's knowledge base — YouTrack
articles, or the GitHub repo wiki where one is enabled. No wiki, no problem:
`docs/knowledge/` stays git-native.

### What lands in a bound project

| Path | What it is |
|---|---|
| `.agents/skills/` | The suite, copied in (`.claude/` and `.github/` symlink to it) |
| `.agents/skills/MANAGED.md` | Which skills the installer owns, and their versions — generated |
| `.agents/config/story-tools.json` | Tracker pointer + settings. Non-secret; commit it |
| `.agents/setup.sh` | Teammate onboarding: their credential, their agents, nothing else |
| `WORKFLOW.md` | Human-facing guide to the loop — generated, tracker-flavoured |
| `docs/stories/`, `.agents/config/dimensions.md` | Generated tracker snapshot and real field values |

A teammate clones and runs `.agents/setup.sh` — this repo is not needed. It
sets up their own credential (or lets them decline and work offline,
reconciling later), registers the tracker in their agents, and — when
`updates.check` is on — tells them if the project's skills are behind what
this repo publishes, offering to update.

Installed skills are managed copies: the installer overwrites them on
refresh and prunes ones it has retired. Improving a skill is discovered
work — it belongs upstream here, never in a project's copy.

## Repository map

| Directory | Contents |
|---|---|
| `skills/stories/` | Tracker discipline: story-workflow, story-reconcile, to-issues, triage |
| `skills/docs/` | Documentation system: project-docs, to-prd, to-adr, to-rad, grill-with-docs, to-wiring, regulatory-compliance |
| `skills/sessions/` | Session lifecycle: handoff, housekeeping, zoom-out |
| `skills/engineering/` | Practice: tdd, improve-codebase-architecture, prototype, to-design |
| `skills/authoring/` | Making skills: write-a-skill |
| `skills/setup/` | Agent/tool configuration: git-guardrails (Claude Code, Gemini), setup-github-copilot, setup-gitlab-duo |
| `trackers/youtrack/` | The story-tools MCP app, `deploy.sh`, `smoke.sh`, tests |
| `trackers/github/` | `smoke.sh` (tracker binding), `smoke-wiki.sh` (docs sync) — run on a dev machine |
| `bootstrap.sh` | One-line install: clone or update the suite, then run the wizard |
| `scripts/` | `install.sh` (the wizard), `skill-versions.sh` (version table; `--publish` writes `VERSIONS.json`), `share-workflow-tags.sh` |
| `docs/` | System docs: ADRs, permissions, system diagram, [skill standards](docs/skill-standards.md), and `outbox/` for proposals headed upstream |
| `.githooks/` | `pre-commit` — blocks a changed skill whose version did not move, restages `VERSIONS.json`. The installer enables it for you |
| `CHANGELOG.md` | Optional prose history — becomes the notes if you ever publish a release |
| `VERSIONS.json` | Published manifest of skill versions — how a project discovers it is behind. Regenerate when versions move |

## Maintaining this repo

Edit a skill, bump its `metadata.version`, commit, push. That is the
whole routine — there is nothing else to run, ever.

Pushing to master releases by itself, if any skill version moved.
Nothing moved means no release and no noise, so a docs fix or a typo
just rides through.

Tags are dated — `v2026.08.02`, and `v2026.08.02.1` for a second one the
same day. This repo has no release planning to describe, so a semver
number on it would claim more than it knows; the versions that carry
meaning are the per-skill ones, and those are what the update check
reads.

The pre-commit hook (enabled by the installer, not by you) refuses a
changed skill whose version did not move and restages `VERSIONS.json` —
that manifest is how a bound project learns it is behind, so it has to
be right.

Add lines to `CHANGELOG.md` under `[Unreleased]` while working and they
become the release notes. Skip it and the release still happens.

To push updated skills into a project, run the installer there; it
copies from your clone. That one stays manual on purpose — it writes
tracked files into somebody's repo.

## Library skills

`to-library-skill` used to live here. It has moved to the dependency-skills
project, where it ships next to the build plugin it teaches so the two
cannot drift apart, and it is listed in the installer's `RETIRED_SKILLS` so
existing copies are removed on the next refresh.

It was retired before its replacement was installable, deliberately: the
version that shipped here scaffolds a packaging convention that has since
been abandoned, and a stale skill teaching an abandoned convention is worse
than no skill at all. See
[docs/outbox/to-library-skill-move-brief.md](docs/outbox/to-library-skill-move-brief.md).

## Using independent skills

Seven skills here are not part of the suite and attach à la carte — copy
the ones you want into a project:

```bash
cp -R skills/engineering/tdd /path/to/project/.agents/skills/
```

Agents that read `.agents/skills/` (or a `.claude/skills` / `.github/skills`
symlink, which the wizard creates) pick them up on restart.

## Attribution

This suite was set up by borrowing heavily from
[Matt Pocock's skills](https://github.com/mattpocock/skills) (MIT, © 2026
Matt Pocock) — his repository is worth exploring for foundational
agent-skill patterns. Skills that stay close to his originals name him as
author; ones since rewritten carry `derived-from: ... - heavily modified`.

Per-skill provenance lives in each `SKILL.md` frontmatter, and the full
picture — including independent skills used but not vendored — is in
[NOTICE.md](NOTICE.md).

---
*Maintained by Brill Pappin.*
