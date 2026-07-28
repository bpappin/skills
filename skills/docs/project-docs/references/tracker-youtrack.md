# Tracker Binding: YouTrack (docs publishing)

Publish command (script bundled in this skill):

```
scripts/yt-publish.sh [--dirs adr,prd,...] [--project KEY] [--dry-run] [DOCS_DIR]
```

- Target: YouTrack knowledge-base articles, hierarchical - root article →
  child article per directory (any depth) → article per `.md` file,
  matching the tree.
- Titles are human-readable, never slugs: a directory's `README.md` is
  consumed as that directory's article (H1 = title, body = content);
  without one, a built-in map titles the standard taxonomy dirs
  ("Architecture Decision Records", "Product Requirements", "QA & Test
  Plans", ...), else the dir name is title-cased. `docs/README.md` names
  the root article; document articles take each file's H1.
- `--dry-run` prints the full article tree offline (no credentials) -
  use it to preview before the first publish.
- Project key resolves from `--project`, `$YOUTRACK_PROJECT`, or
  `.agents/config/story-tools.json`; credentials from the story-tools
  installer connections (`~/.agents/story-tools/connections/`).
- Idempotency map: `DOCS_DIR/.yt-articles.json` (commit it). Articles carry
  a generated-do-not-edit banner; the repo is canonical, one-way only.
- Always skipped: `docs/stories/` (the snapshot - never mirror the tracker
  into itself), non-`.md`, and globs in `DOCS_DIR/.yt-publish-ignore`.
  `README.md` files publish as their directory's article, never as leaves.
- YouTrack renders the same markdown the repo holds, task lists included.
