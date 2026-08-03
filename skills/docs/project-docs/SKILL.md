---
name: project-docs
description: File, create, and organize project documentation, and keep the repo's docs/knowledge/ tree in two-way sync with the tracker knowledge base (YouTrack articles or the GitHub repo wiki; tracker-agnostic via bindings). Use when deciding where a document belongs, creating a PRD, ADR, research record, QA plan, or prospect dossier, syncing docs, publishing docs to the wiki, or resolving a docs sync conflict. Triggers - "where should this doc go", "file this", "write a PRD", "record this decision", "new ADR", "update docs", "sync docs", "publish the docs".
license: MIT
compatibility: Standalone for filing/creating docs. Syncing requires git on PATH plus the binding's connection - YouTrack REST (story-tools connection or YOUTRACK_URL/TOKEN env), or a GitHub token with Contents RW and an initialized wiki.
metadata:
  author: bpappin
  version: "1.5"
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
- Tracker bindings - `tracker.type` in `.agents/config/story-tools.json`
  selects one (absent → youtrack):
  - [references/tracker-youtrack.md](references/tracker-youtrack.md) -
    YouTrack Knowledge Base (`scripts/yt-sync.sh`)
  - [references/tracker-github.md](references/tracker-github.md) -
    GitHub repo wiki (`scripts/gh-wiki-sync.sh`), capability-detected:
    no wiki → `docs/knowledge/` stays git-native, no mirror.

## The sync model

Per-article three-way merge against a recorded base (the state dir the
binding names - commit it, never hand-edit it). **Content flows both
ways** everywhere: a local edit pushes; a KB/wiki edit pulls; both at
once merge. True collisions get git conflict markers, are NEVER pushed,
and wait for you to resolve them with normal git tooling - then the
next sync pushes the resolution.

**Structure ownership differs per tracker** - see the binding:

- **YouTrack: structure flows down.** The KB is the organizing surface -
  humans arrange, rename, and edit articles there and the tree follows.
  Never `git mv` inside `docs/knowledge/` to reorganize - the sync moves
  files back and says so. The one exception: a NEW file's location
  chooses its parent section at birth. Names are ID-prefixed like
  stories: `EVO-A-12_title-slug.md`, section dirs `EVO-A-7_section-name/`.
- **GitHub: structure flows up.** The wiki has no hierarchy UI, so the
  local tree owns the layout - reorganize by moving files locally and
  the wiki's page names and generated sidebar follow. Wiki UI edits are
  content edits; a page born in the wiki UI lands at the KB root for
  filing.

## The sync ritual

- **Session start:** run the binding's sync script so the agent works
  from a fresh mirror. `--dry-run` previews; `--pull-only` refreshes
  without pushing anything.
- **After creating or editing docs:** sync again - edits reach the KB
  immediately, article by article. Do not sit on local doc edits.
- **Exit 2 = conflicts.** Open each listed file, resolve the markers,
  sync again. A file with markers is never pushed.
- **When the report lists Moved or Renamed entries:** update any
  `docs/`-root indexes or instruction files that referenced the old
  paths. That's the agent's job, every time.
- **Deletes are deliberate.** Deleting an article/page on the tracker
  side prunes the file on the next sync (a locally-edited file survives
  as a reported conflict). Deleting a local file does nothing until
  `--allow-delete`.

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

Either side can author: a human can just as well create the article in
YouTrack (it appears in the tree on the next sync) or a page in the
GitHub wiki (it lands at the KB root, then gets filed).
When a doc mixes knowledge and a task list, split it - knowledge stays
in the file, tasks become stories; propose the split first.

## Creating a document

Start from the matching template in `assets/templates/`. Keep
frontmatter to title/date only - never status/id fields; lifecycle
state is the tracker's job. PRDs list their stories as tracker IDs
(`EVO-123`, `#123`) and never contain acceptance criteria.

**`docs/README.md` is the front door** - a git-native guide to the
whole system (template: `assets/templates/docs-guide.md`; create it
during adoption, keep it current when the model changes). It is NOT
synced - it describes the system rather than living inside it.

## After a tracker move (server migrated or project rebound)

When a project is rebound to a different server/connection, the sync
*script* follows the pointer immediately - but the sync *state* does
not: the recorded base (`.yt-sync/` / `.gh-wiki-sync/`), ID-prefixed
filenames, and the `docs/stories/` snapshot all still reference the old
server. Never push blind after a move. The ritual:

1. **Trust exactly one config.** `.agents/config/story-tools.json` is
   the only pointer. Any other file naming a tracker server (legacy
   `.agents/youtrack.json`, `.agents/config/youtrack.json`, configs
   from earlier tooling) is stale - surface it to the user and get it
   removed before syncing anywhere. Two configs disagreeing is a STOP,
   not a coin flip.
2. **Dry-run first.** Run the binding's sync with `--dry-run`. A sane
   plan (your recent local edits, nothing else) means the article/page
   identities survived the migration - sync for real, done.
3. **A wild plan means the identities didn't survive** (mass deletes,
   moves, or creates you didn't make). Re-bootstrap: move the KB dir
   aside (keep it - it holds local-only edits), let an empty-dir sync
   pull the migrated KB fresh from the new server, then port the
   local-only documents into the pulled tree and sync again.
4. **Refresh the snapshots.** `docs/stories/` and `docs/dimensions.md`
   are old-server data until the binding's pull is re-run.

The installer warns about all of this when it detects a rebind; this
section is what to do about the warnings.

## Reorganizing

Structure changes happen on the side that owns structure - YouTrack:
move and rename articles there and sync; GitHub: move files locally
and sync. Either way, fix references the Moved/Renamed report surfaces.
For adopting this system over a legacy docs tree, see the migration
notes in [references/taxonomy.md](references/taxonomy.md).
