---
name: project-docs
description: File, create, and organize project documentation using the eight-home taxonomy, and mirror the docs tree into the tracker knowledge base (YouTrack articles today; tracker-agnostic via bindings). Use when deciding where a document belongs, creating a PRD, ADR, research record, QA plan, or prospect dossier, reorganizing a docs/ tree, or publishing docs to YouTrack. Triggers - "where should this doc go", "file this", "write a PRD", "record this decision", "new ADR", "update docs", "reorganize docs", "publish docs".
license: MIT
compatibility: Standalone for filing/creating docs. Publishing to YouTrack articles requires an MCP or REST connection (story-tools profile or YOUTRACK_URL/TOKEN env).
metadata:
  author: bpappin
  version: "0.3"
---

# Project Docs

Documentation follows one rule: **if it tracks work, it lives in YouTrack;
if it's knowledge, it lives in the repo.** No repo doc carries status, id,
or sync frontmatter — lifecycle state is YouTrack's job (see the
story-workflow skill). This skill covers the knowledge side.

Bundled resources:

- [references/taxonomy.md](references/taxonomy.md) — the eight homes, the
  filing rule, and the migration map from the legacy 15-sector layout.
- `assets/templates/` — starting points: `prd.md`, `adr.md`, `research.md`,
  `qa-plan.md`, `prospect.md`.
- [references/tracker-youtrack.md](references/tracker-youtrack.md) — the
  YouTrack publishing binding (`scripts/yt-publish.sh`). `tracker.type` in
  `.agents/config/story-tools.json` selects the binding (absent → youtrack).

## Filing a document

Two questions, in order:

1. **Does it track work?** (has a status, will be "done", lists tasks) →
   it's a YouTrack story/epic, not a file. Use the story-workflow skill.
2. **What kind of knowledge is it?** decision → `adr/` · requirement →
   `prd/` · standing spec → `spec/` · picture/mockup → `design/` ·
   investigation → `research/` · external fact (vendors, prospects,
   regulations, domain) → `reference/` · how-to → `guides/` · test
   protocol → `qa/` · written FOR an outside party (third-party bug
   report, correspondence) → `outbox/` (stored, never published). In a
   monorepo, split within a home by subsystem subdirectory
   (`adr/cms-server/`), named after the Subsystem field values. Details
   and edge cases:
   [references/taxonomy.md](references/taxonomy.md).

When the user hands you a doc that mixes both (e.g. a spec with a task
list), split it: knowledge stays in the file, the task list becomes
stories - propose the split before doing it.

## Creating a document

Start from the matching template in `assets/templates/`. Keep frontmatter
to title/date only — never status/id fields. PRDs list their stories as
YouTrack IDs (the template shows how); they never contain acceptance
criteria.

**Every docs directory carries a `README.md` index** (template:
`assets/templates/readme.md`) whose `# H1` is the directory's
human-readable name — "Architecture Decision Records", not "adr". Someone
who doesn't know the acronyms must be able to navigate by titles alone.
The publisher uses that README as the directory's article in the knowledge
base, so the title and intro are what non-repo readers see. `docs/README.md`
does the same for the root. Create one whenever you create a directory.

## Publishing to the tracker's knowledge base

The whole docs tree mirrors into the tracker's knowledge area as a matching
hierarchy (root "Project Docs" → one node per directory → one per document),
so stories can link readable docs and non-repo people can search them. Run
the publish command from the tracker binding
([references/tracker-youtrack.md](references/tracker-youtrack.md) for
YouTrack).

- **One-way, always.** The repo is canonical; articles are generated
  mirrors stamped with a do-not-edit banner. Never copy article edits back
  by hand — fix the repo file and re-publish.
- Idempotent: `.yt-articles.json` in the docs dir maps path → article ID
  (commit it). Re-runs update in place; deleted mappings recreate.
- Credentials come from the story-tools installer's profiles — if the
  script can't authenticate, tell the user to run `install.sh`. Never ask
  for or accept tokens in conversation.
- **Human-readable hierarchy.** Directory articles are titled from the
  directory's `README.md` H1 (that README is the article body too); dirs
  without one fall back to a built-in title map for the standard taxonomy
  ("Architecture Decision Records", "Product Requirements", ...), then to a
  title-cased dir name. Document articles are titled from each file's H1.
  Nothing in the knowledge base should show a bare slug like "adr".
- The tracker snapshot dir (e.g. `docs/youtrack/`) and `docs/outbox/`
  are never published — the first would mirror the tracker into itself,
  the second is outbound material, not knowledge. Non-markdown files are skipped; add
  glob lines to `docs/.yt-publish-ignore` to exclude anything else.
- Preview first: `--dry-run` prints the exact article tree (titles,
  hierarchy, create/update actions) offline, no credentials needed.
- Run after doc changes merge, or on request ("publish docs").

## Reorganizing / adopting this taxonomy

For knowledge docs, propose a move table (current path → new home), get
approval, `git mv`, fix cross-references. For the retired work-tracking
sectors (`ac/`, `gap/`, statused QA runs, handoffs), hand off to the
story-reconcile skill — that migration needs its approval gate.
