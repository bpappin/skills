# Changelog

Notable changes, in prose, for anyone who has not been watching the
commits — including future you.

**Optional.** Nothing depends on this being current: skills carry their
own `metadata.version`, and that is what the update check reads. Keep it
up when a change is worth explaining, skip it when it is not. If you
ever publish a release, whatever is here becomes its notes.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Nothing yet.

## [2026.08.03]

### Fixed

- **A YouTrack refresh now rebuilds `docs/dimensions.md`.** The GitHub
  bind always reseeded it; the YouTrack bind never did, so a project
  would get an updated `yt-pull.sh` and keep a stale dimensions file
  until someone ran a full pull. `yt-pull.sh` gained
  `--dimensions-only` to make that cheap.
- **`docs/dimensions.md` now lists every usable tag, not just topical
  ones.** Workflow tags were filtered out as "machinery", which left an
  agent reading the file unable to see that `needs-triage` exists — so
  it invented substitutes. They are now a named section with a one-line
  meaning each, and any the server is missing are called out so nobody
  tries to apply a tag that was never created.
- **Versions are split into current/upcoming and already-shipped.**
  Released values sat alongside open ones with nothing distinguishing
  them, which invited targeting new work at a shipped version.

### Added

- **Leaf → section recovery** in the YouTrack docs binding. A section
  created as a bare file is a leaf article, and local layout is derived
  from the KB rather than chosen — so the intuitive local fix (mkdir +
  README, delete the flat file) resurrects the file *and* creates a
  duplicate section article. The working recipe — give it a child in
  YouTrack, delete the local leaf, sync — was derivable from the
  existing rules but never written down, and the duplicate trap was
  not documented at all.

- **GitHub wiki docs sync** — `docs/knowledge/` now syncs two ways with a
  repo wiki, the same three-way merge model as the YouTrack binding.
  Structure flows *up* on GitHub (the wiki has no hierarchy, so the local
  tree owns layout, with a generated sidebar). Capability-detected: no
  wiki, and docs simply stay git-native.
- **`.agents/setup.sh` ships with every bound project** — teammates
  onboard from a clone without this repo. Sets up their own credential,
  registers the tracker in their agents, and lets them decline entirely
  and work offline. It cannot rebind the project.
- **`MANAGED.md` in each project** — names the skills the installer owns
  and their versions, so agents and humans can tell managed copies from
  the project's own. Skills the suite has retired are pruned on refresh;
  third-party and project-local skills never are.
- **Optional update check** — a project can ask whether its skills are
  behind what this repo publishes (`VERSIONS.json`) and offer to update.
  Never acts unasked, fails silent offline, honours `updates.check`.
- **`to-library-skill`** (formerly `to-ai-skill`) — maintains the agent
  skill a library ships inside its own artifact, so agents stop
  reinventing code they cannot see. Scaffolds per module, indexes a
  multi-module repo, and harvests skills from dependencies across npm,
  SPM, Python, Go, Cargo, NuGet and JVM jars. Runs standalone.
- **`MANIFEST.MF` `Agent-Skills` attribute** — jars announce their skills
  instead of being scanned. Proposal, with the write-up in
  [`docs/outbox/`](docs/outbox/) for the upstream maintainers.
- **One-line install** — `bootstrap.sh` plus a full
  [install guide](docs/INSTALL.md) covering manual install, requirements,
  teammate onboarding, offline use, and troubleshooting.
- **Release automation** — `VERSIONS.json` refreshes itself on push;
  tagging packages every skill and attaches it to a Release.
- **`NOTICE.md`** — upstream sources and per-skill provenance.

### Changed

- **Bundled library skills follow the emerging convention** —
  `.agents/skills/<name>/SKILL.md` (`META-INF/agents/skills/` on the
  JVM), a standard Agent Skill any agent can load, rather than a private
  format. Scanners still read the older layouts.
- **The domain glossary is knowledge** — it lives in `docs/knowledge/`
  and syncs like everything else, with `AGENTS.md` pointing at it,
  instead of a root `CONTEXT.md`.
- **`grill-with-docs` absorbed `grill-me`** — one skill that adapts to
  whatever the project has: glossary, knowledge tree, tracker, or none of
  them, in which case it just grills.
- **Attribution corrected** — this suite was set up by borrowing heavily
  from [Matt Pocock's skills](https://github.com/mattpocock/skills) (MIT,
  © 2026 Matt Pocock). Skills close to his originals name him; rewritten
  ones carry `derived-from`. MIT was always the right licence; his
  copyright notice was missing.
- **Installer refresh reports what moved** — old → new per skill, so a
  refresh says what it did rather than doing it silently.
- Agent registrations are refreshed on every install, so a newly
  installed agent picks up existing connections without `--register`.
- README rewritten against the current repo.

### Fixed

- A rebind to a different tracker server now warns that the docs sync
  state and story snapshot still reference the old one, and
  `project-docs` documents the recovery.
- Legacy `.agents/config/youtrack.json` pointers are removed on refresh
  instead of shadowing the real one.
- `improve-codebase-architecture` no longer points at paths that stopped
  existing (`docs/adr/`, a root `CONTEXT.md`) and is version-stamped.
- Version comparison is numeric per component, so `1.10` correctly beats
  `1.9`.

### Removed

- `grill-me` (superseded by `grill-with-docs`) and `to-ai-skill`
  (renamed). Both are pruned from projects on refresh.
- `caveman` is no longer vendored here — it is an independent skill,
  installed from [upstream](https://github.com/JuliusBrussee/caveman) and
  never touched by the installer.
