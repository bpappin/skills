# Skill Standards

Normative requirements for every skill in this repository. Derived from the
[Agent Skills specification](https://agentskills.io/specification) and its
guides on [optimizing descriptions](https://agentskills.io/skill-creation/optimizing-descriptions),
[using scripts](https://agentskills.io/skill-creation/using-scripts), and
[client implementation](https://agentskills.io/client-implementation/adding-skills-support).
The closer we stay to the standard, the cheaper this library is to maintain
and the more agents it works in unmodified.

**Gate: every skill MUST pass `skills-ref validate <skill-dir>` before it
lands.** ([skills-ref](https://github.com/agentskills/agentskills/tree/main/skills-ref))

## 1. Structure and frontmatter (spec conformance)

A skill is a directory containing `SKILL.md`, optionally plus `scripts/`,
`references/`, and `assets/`. Frontmatter rules:

| Field | Required | Constraints |
|---|---|---|
| `name` | yes | 1–64 chars; lowercase `a-z0-9-`; no leading/trailing/consecutive hyphens; MUST match the directory name |
| `description` | yes | 1–1024 chars; what the skill does AND when to use it |
| `license` | no | short — a license name or bundled file reference |
| `compatibility` | no | 1–500 chars; ONLY when the skill has real environment requirements (most skills should omit it) |
| `metadata` | no | string→string map; use reasonably unique keys |
| `allowed-tools` | no | experimental; space-separated pre-approved tools |

No other top-level frontmatter keys — anything custom goes under `metadata`.
(This is why zoom-out carries `metadata.disable-model-invocation` instead of
the client-specific top-level key, with the intent restated in the
description so the behavior survives on any agent.)

## 2. Portability (self-containment)

- Everything a skill needs ships inside its own directory: scripts in
  `scripts/`, docs in `references/`, templates in `assets/`.
- All file references are **relative paths from the skill root**, one level
  deep. Never `../` out of the skill, never absolute paths, never
  repo-relative paths — a skill must survive being copied alone into any
  project's `.agents/skills/`.
- The only external paths a skill may name are the deliberate well-known
  locations of the story-tools system: `~/.agents/story-tools/` (per-user
  connections, created by the installer) and
  `<project>/.agents/config/story-tools.json` (non-secret pointer).
- Skills NEVER ask for or accept credentials in conversation. Secrets are
  entered only through the installer.

## 3. Progressive disclosure (context budgets)

Agents load skills in three tiers; structure content accordingly:

1. **Metadata** (~100 tokens) — `name` + `description`, loaded at startup
   for every installed skill. This is all the agent sees until it activates.
2. **Instructions** — the full `SKILL.md` body, loaded on activation. Keep
   it under **500 lines** (< ~5000 tokens). One skill = one job.
3. **Resources** — `scripts/`, `references/`, `assets/`, loaded only when
   the instructions point at them.

Move detail out of `SKILL.md` into focused reference files — smaller files
mean less context per load. List bundled scripts in the body so the agent
knows they exist; don't inline their contents.

## 4. Descriptions (triggering)

The description carries the entire burden of activation — an agent decides
to load a skill from the description alone.

- **Imperative phrasing**: "Use when …", not "This skill does …".
- **Cover both halves**: what it does, and the situations that call for it.
- **User intent, not mechanics**: describe what the user is trying to
  achieve; include trigger phrases users actually say, including cases
  where they don't name the domain.
- **Be pushy but bounded**: list the contexts where the skill applies; for
  skills with near-neighbors (to-prd vs to-issues, grill-me vs
  grill-with-docs), state the boundary so the wrong one doesn't fire.
- ≤ 1024 characters; a few sentences is usually right.

When tuning a description, use the eval-query loop from the guide: ~20
realistic queries (8–10 should-trigger with varied phrasing/explicitness,
8–10 near-miss negatives), 3 runs each, train/validation split (~60/40) to
avoid overfitting, revise by generalizing rather than pasting keywords from
failed queries.

## 5. Scripts (agentic interfaces)

Bundled scripts and one-off commands MUST be designed for a non-interactive
agent reading stdout/stderr:

- **Never block on input** — no TTY prompts, confirmations, or password
  dialogs. All input via flags, environment variables, or stdin. A missing
  argument produces a usage error, not a prompt.
- **`--help` / usage text** — brief description, flags, examples. This is
  how the agent learns the interface; keep it concise.
- **Helpful errors** — say what went wrong, what was expected, and what to
  try. Distinct exit codes for distinct failure types.
- **Structured output** — JSON/CSV/TSV on stdout; progress and diagnostics
  on stderr. Composable with `jq`/`cut`/`awk`.
- **Idempotent** — agents retry; "create if not exists" beats "fail on
  duplicate".
- **Safe defaults** — `--dry-run` for destructive or stateful operations;
  explicit `--force`/`--confirm` where the risk warrants it.
- **Bounded output** — default to a summary or limit; support `--offset` or
  an `--output` file when results can be large (harnesses truncate).
- **Dependencies**: prefer self-contained scripts (bash + standard tools;
  Python with PEP 723 inline metadata run via `uv run`). For one-off
  commands, pin versions (`npx tool@x.y.z`, `uvx tool@x.y.z`) and state
  prerequisites in `SKILL.md` — runtime-level requirements go in the
  `compatibility` field.
- Reference scripts by relative path from the skill root; agents execute
  from there.

## 6. What we may assume from clients

Conforming clients scan `<project>/.agents/skills/` and `~/.agents/skills/`
(plus their own native locations), load only name+description at startup,
and activate by reading `SKILL.md` — so a skill must work through file-read
activation alone, with no client-specific machinery. Project-level skills
override user-level ones on name collision, which is why project-attached
is our default install mode. Clients may strip frontmatter on activation:
**never put load-bearing instructions in frontmatter** — anything the agent
must follow belongs in the body (or, for triggering, the description).
Custom frontmatter beyond the spec may be ignored or rejected — hence rule
1. Untrusted-repo gating means project skills might not load at all in some
clients; skills should degrade gracefully rather than assume they ran.

## 7. Repository conventions

- Groups under `skills/<group>/<skill>` are curation only — grouping must
  never create coupling. Each skill still stands alone (rule 2).
- Suite membership (what the wizard installs) lives in
  `scripts/install.sh`, not in directory structure.
- Shared prose is duplicated into each skill that needs it, never
  cross-referenced between skills (e.g. CONTEXT-FORMAT.md exists in both
  grill-with-docs and improve-codebase-architecture by design).
- `trackers/` holds per-tracker infrastructure (apps, deploy tooling) —
  nothing under `skills/` may depend on files there.
