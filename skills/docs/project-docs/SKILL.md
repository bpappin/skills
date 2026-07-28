---
name: project-docs
description: File, create, and organize project documentation, and keep the repo's docs/knowledge/ tree in two-way sync with the tracker knowledge base (YouTrack articles today; tracker-agnostic via bindings). Use when deciding where a document belongs, creating a PRD, ADR, research record, QA plan, or prospect dossier, syncing docs, or resolving a docs sync conflict. Triggers - "where should this doc go", "file this", "write a PRD", "record this decision", "new ADR", "update docs", "sync docs".
license: MIT
compatibility: Standalone for filing/creating docs. Syncing with YouTrack requires a REST connection (story-tools profile or YOUTRACK_URL/TOKEN env) and git on PATH.
metadata:
  author: bpappin
  version: "1.0"
---

# Project Docs

Everything lives in exactly one of three kinds of place:

1. **Work** (status, done-ness, task lists) → tracker issues, never files.
   Use the story-workflow skill.
2. **Knowledge** (decisions, specs, research, guides, mandates - anything
   a person would look up) → the tracker's knowledge base, mirrored
   two-way into `docs/knowledge/`.
3. **Machinery** (agent instructions, wiring rules, indexes, tooling
   state) → plain git files. `AGENTS.md` and `WIRING.md` at the repo
   root; doc-system notes and indexes at the `docs/` root. Never synced.

`docs/stories/` is the generated issue snapshot (story-reconcile skill) -
unchanged by this skill, never edited, never synced as articles.

Bundled resources:

- [references/taxonomy.md](references/taxonomy.md) - filing conventions
  and suggested starting sections.
- `assets/templates/` - starting points: `prd.md`, `adr.md`,
  `research.md`, `qa-plan.md`, `prospect.md`, plus `readme.md` (section
  filing guide) and `docs-guide.md` (the `docs/README.md` front door).
- [references/tracker-youtrack.md](references/tracker-youtrack.md) - the
  YouTrack sync binding (`scripts/yt-sync.sh`). `tracker.type` in
  `.agents/config/story-tools.json` selects the binding (absent → youtrack).

## The sync model

**YouTrack is the organizing surface; git is the history and merge
engine.** Humans arrange, rename, and edit articles in the knowledge
base. Agents (and humans) edit the mirrored files in `docs/knowledge/`.
`scripts/yt-sync.sh` reconciles the two per-article with a three-way
merge against a recorded base (`.yt-sync/` - commit it, never hand-edit
it):

- **Content flows both ways.** A local edit pushes; a KB edit pulls;
  both at once merge. True collisions get git conflict markers, are
  NEVER pushed, and wait for you to resolve them with normal git
  tooling - then the next sync pushes the resolution.
- **Structure flows down only.** Hierarchy and titles belong to
  YouTrack; rearrange there and the tree follows. Never `git mv` inside
  `docs/knowledge/` to reorganize - the sync moves files back and says
  so. The one exception: a NEW file's location chooses its parent
  section at birth.
- **Names are ID-prefixed** like stories: `EVO-A-12_title-slug.md`,
  section dirs `EVO-A-7_section-name/`. New files are renamed to match
  once their article exists.

## The sync ritual

- **Session start:** run `yt-sync.sh` (from the tracker binding) so the
  agent works from a fresh mirror. `--dry-run` previews; `--pull-only`
  refreshes without pushing anything.
- **After creating or editing docs:** sync again - edits reach the KB
  immediately, article by article. Do not sit on local doc edits.
- **Exit 2 = conflicts.** Open each listed file, resolve the markers,
  sync again. A file with markers is never pushed.
- **When the report lists Moved entries:** update any `docs/`-root
  indexes or instruction files that referenced the old paths. That's
  the agent's job, every time.
- **Deletes are deliberate.** Deleting an article in YouTrack prunes the
  file on the next sync (a locally-edited file survives as a reported
  conflict). Deleting a local file does nothing until `--allow-delete`.

## Filing a document

1. **Does it track work?** → it's an issue, not a file.
2. **Otherwise, pick the section.** Each section directory's `README.md`
   IS the section article's body - read it; it says what belongs there.
   Create the file in that directory with a `# Title` heading (that
   heading becomes the article title), then sync. No matching section?
   Create the directory with a `README.md` describing what belongs in it
   (template: `assets/templates/readme.md`) - the sync births the
   section article too. Suggested starting sections:
   [references/taxonomy.md](references/taxonomy.md).

Either side can author: a human can just as well create the article
directly in YouTrack, and it appears in the tree on the next sync.
When a doc mixes knowledge and a task list, split it - knowledge stays
in the file, tasks become stories; propose the split first.

## Creating a document

Start from the matching template in `assets/templates/`. Keep
frontmatter to title/date only - never status/id fields; lifecycle
state is the tracker's job. PRDs list their stories as YouTrack IDs and
never contain acceptance criteria.

**`docs/README.md` is the front door** - a git-native guide to the
whole system (template: `assets/templates/docs-guide.md`; create it
during adoption, keep it current when the model changes). It is NOT
synced - it describes the system rather than living inside it.

## Reorganizing

Structure changes happen in YouTrack: move and rename articles there,
sync, then fix references the Moved report surfaces. For adopting this
system over a legacy docs tree, see the migration notes in
[references/taxonomy.md](references/taxonomy.md).
