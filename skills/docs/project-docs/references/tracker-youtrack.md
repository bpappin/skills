# Tracker Binding: YouTrack (docs publishing)

Publish command (script bundled in this skill):

```
scripts/yt-publish.sh [--dirs adr,prd,...] [--project KEY] [DOCS_DIR]
```

- Target: YouTrack knowledge-base articles, hierarchical - root "Project
  Docs" article → child article per directory (any depth) → article per
  `.md` file, matching the tree.
- Project key resolves from `--project`, `$YOUTRACK_PROJECT`, or
  `.agents/config/story-tools.json`; credentials from the story-tools
  installer connections (`~/.agents/story-tools/connections/`).
- Idempotency map: `DOCS_DIR/.yt-articles.json` (commit it). Articles carry
  a generated-do-not-edit banner; the repo is canonical, one-way only.
- Always skipped: `docs/youtrack/` (the snapshot - never mirror the tracker
  into itself), non-`.md`, `README.md`, and globs in
  `DOCS_DIR/.yt-publish-ignore`.
- YouTrack renders the same markdown the repo holds, task lists included.
