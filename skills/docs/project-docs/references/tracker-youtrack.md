# Tracker Binding: YouTrack (docs sync)

Sync command (script bundled in this skill):

```
scripts/yt-sync.sh [KB_DIR] [--project KEY] [--root "Title"]
                   [--pull-only] [--allow-delete] [--force] [--dry-run]
```

- Domain: `KB_DIR` (default `./docs/knowledge`) ⇄ the project's whole
  knowledge base (`--root "Title"` scopes to one top-level article's
  subtree; its body becomes `KB_DIR/README.md`).
- Layout: an article with children is a directory (its body is the
  directory's `README.md`); a leaf article is a file. Names are
  ID-prefixed: `EVO-A-12_title-slug.md`, dirs `EVO-A-7_section-name/`.
- Per-article three-way merge against the base recorded in
  `KB_DIR/.yt-sync/` (commit it; never hand-edit). Local-only change →
  push; KB-only change → pull; both → merge, conflicts get git markers
  and are never pushed until resolved. Exit codes: 0 ok, 1 error,
  2 conflicts to resolve.
- Structure flows down: KB moves/renames move local files (reported
  under Moved - update indexes that referenced old paths). Local moves
  are moved back. A new local file's directory picks its parent at
  birth; missing section dirs birth stub section articles from their
  `README.md`.
- Deletes: KB delete prunes an unedited local file, conflicts an edited
  one. Local delete is report-only unless `--allow-delete` (soft-deletes
  the article).
- Bootstrap: empty `KB_DIR` pulls the whole KB. Non-empty without sync
  state refuses unless `--force`, which adopts every file as a new
  article (the legacy-adoption path).
- Project key resolves from `--project`, `$YOUTRACK_PROJECT`, or
  `.agents/config/story-tools.json`; credentials from the story-tools
  installer connections (`~/.agents/story-tools/connections/`). Never
  ask for or accept tokens in conversation - if authentication fails,
  tell the user to run `install.sh`.
- Requires `git` on PATH (three-way merges use `git merge-file`).
- YouTrack renders the same markdown the repo holds, task lists included.
