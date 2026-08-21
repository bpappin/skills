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

## [2026.08.21]

Nothing yet.

## [2026.08.18]

Nothing yet.

## [2026.08.16]

### Fixed

- **`add_discovered_work` ignored the issue id it was given, and filed in
  the wrong project.** Its parameter was named `fromIssueId` while every
  other tool in the app takes `issueId`, so an agent passing `issueId` had
  it dropped as an unknown property and the call fell through to the
  focused story - which can belong to a different project entirely. Twice
  observed in the wild: issues created under the wrong key, linked to
  unrelated work, needing manual cleanup. It now accepts either name,
  returns `project` and `usedFocus`, and says in its message when it fell
  back to focus so a wrong project is visible immediately rather than
  after the write. Needs a YouTrack deploy to take effect.

- **Focus is now honest about what it is.** It lives on the user record as
  a single value with no project dimension, so a story from another project
  can be sitting in it - which is how the above went wrong twice.
  `story_set_focus` records the project, reads the value back and fails
  loudly if it did not stick; `story_get_focus` returns the project, the
  user the focus belongs to, and whether the focused story is already
  resolved. The tools that write acceptance criteria or file discovered
  work refuse to act on a focused story that is resolved, since that is the
  usual sign the focus is stale - an explicit `issueId` always wins and is
  never second-guessed. `complete_story` and `log_work` are deliberately
  exempt: finishing a story resolves it, and effort is often logged
  straight afterwards.

### Removed

- **`worklog` is no longer part of the suite install.** A developer's
  working day is personal - it spans every project and belongs to the
  person, not to any repo - so installing it into every bound project put a
  private record in front of people who never asked for it. It stays in
  this repo and attaches à la carte: copy `skills/sessions/worklog` into a
  project that wants it. Deliberately **not** in `RETIRED_SKILLS`; it is
  not retired, just not installed by default. Existing copies are pruned
  from projects on the next refresh via the manifest, so anyone still using
  it should copy it back.

### Added

- **Roles, asked once at setup, in terms of what you actually do.**
  `setup.sh` asks whether you implement features (`developer`), manage the
  work (`lead` - triage, priorities, deciding a story is ready), make the
  technical calls (`architect` - architecture, ADRs, research), or decide
  what the product does (`product` - PRDs). They are listed in
  chain-of-command order, so the list reads the way a team is arranged, and
  they are not exclusive: Enter takes all of them, which is the answer for
  someone working solo, so the common case costs one keystroke rather than
  acquiring ceremony. Stored
  in `~/.agents/story-tools/developer.json`, keyed by the tracker's own
  identity for the project, because installed skills are tracked files -
  the repo is shared and cannot carry anything about a particular person.
  `--role dlap` sets it without the prompt. It shapes what agents offer and
  nothing else: the tracker still enforces what can actually happen. See
  `docs/rad/0003-more-than-one-person.md`.

  `WORKFLOW.md` gained a **Who does what** section covering the same ground
  for humans: the four roles and what each does, that they are not
  exclusive and solo means all of them, that a role is a hint rather than a
  permission, and that capture is never gated. It regenerates on refresh,
  so bound projects pick it up without anyone editing a file.

- **Agents now notice when setup has not been run.** A fresh clone looks
  fully configured - skills and workflow docs are committed - while the
  person has no credential and no role. `story-workflow` and `triage` stop
  and point at `.agents/setup.sh` when there is no entry for the project,
  rather than failing later in a way that reads as a broken tracker.

### Fixed

- **The story snapshot stamped its generation date into every file**, so a
  pull rewrote all of them whether or not anything changed upstream. On a
  team that meant two people pulling on different days conflicted on every
  story - one project has 299 of them - over content neither had written.
  The date now lives in `INDEX.md` alone, so a story file changes only when
  the issue changed and a conflict means something.

- **The snapshot is synced per developer wherever a tracker exists.**
  Committed exists for the case where you *cannot* reach the tracker, so it
  is no longer the default: a project bound to YouTrack or GitHub gets
  `snapshot: synced` - gitignored between markers in `.gitignore`, each
  developer pulling their own - and a project with no tracker gets
  `committed`. Derived rather than asked, since the binding
  already answers it - but **an existing committed snapshot is treated as
  a decision and never flipped silently**: one person working alone has no
  conflicts to have and a copy readable with no tracker, so a project
  already carrying its snapshot in git keeps it. Only a project with
  nothing tracked yet takes the new default. An explicit `snapshot` in the
  pointer always wins, and `--snapshot synced|committed` forces it. On refresh the
  installer notices a snapshot still tracked from an earlier setup and
  **offers to untrack it**, because gitignoring a tracked file does nothing
  on its own - it explains why in a yellow heads-up block -
  git keeps tracking what it already tracks, so the ignore rule alone
  changes nothing - then gives the exact commands for the person running it
  and the separate ones everyone else needs after pulling, and offers to run
  the first set. Files stay on disk; only the tracking stops. If git refuses
  - hooks, permissions, a managed checkout - it says so, shows what git
  reported, and asks the user to run it themselves rather than reporting a
  success that did not happen. `story-reconcile` gained the rules for
  resolving a conflict: never hand-merge, but "take either side" is only
  safe when neither side holds a change the tracker lacks - otherwise that
  change goes to the tracker first and the file is regenerated. The offline
  pending log is the opposite case: append-only, so a conflict there keeps
  both sides, and taking one loses somebody's session.

### Changed

- **A story with no acceptance criteria goes back to triage instead of
  being written on the spot.** `story-workflow` used to say "stop and
  draft AC with the user" - which, when the person holding the ticket is
  not the person who decides what the product does, means requirements get
  invented mid-implementation by whoever is under time pressure, or the
  developer gets pushed up into `to-prd` because that is where the
  workflow pointed. It now tags `needs-triage` and hands the story back.
  Deliberately not a permissions rule: nobody should be authoring
  requirements inside a work session. Whoever owns them can still fix the
  story - as a separate, deliberate triage step, not a detour. Filing the
  gap as an issue or a bug stays open to everyone; that is the off-ramp.
  `to-prd` gained a matching note that a PRD is a product decision rather
  than a way to record something you noticed.


- **`docs/` no longer holds anything a public site should not publish.**
  GitHub Pages offers a `/docs` branch source, and selecting it publishes
  everything beneath - the knowledge tree and the story snapshot included.
  Nothing else claims `docs/`; this is one host's shortcut landing on a
  directory that already meant something here, and GitLab Pages has no
  equivalent. Three moves rather than a restructure: `WORKFLOW.md` goes to
  the repo root, where the orientation files already live and a human will
  find it; `dimensions.md` moves to `.agents/config/`, since it is
  tool-read reference data and never was documentation; and the installer
  now generates `docs/_config.yml` excluding `knowledge/` and `stories/`.
  Story snapshots stay in `docs/` - people read them. The config is
  generated, so it stays in step with what the suite writes, and it is
  left alone if a project already has one of its own.

  On refresh the installer notices copies left at the old paths and **asks**
  before touching them - removing one that has been superseded, moving one
  whose new location is still empty. Nothing in a project's repo is moved
  or deleted without a yes, and a non-interactive run reports and leaves
  them alone.


- **`to-issues` 1.10, `triage` 1.19 - dimensions are a precondition, not
  advice.** The rule to read a project's dimension values lived only in the
  *proposal* step, mid-paragraph; the step that actually writes to the
  tracker said nothing. An agent that compressed the proposal round arrived
  at the write with no constraint in view, invented a topical tag and left
  Subsystem unset. The rule now sits at the top of the write step in both
  skills, stated as a refusal, and topical tags are explicitly drawn from
  the set the project already uses - freeform is not permission to invent
  one.

- **The YouTrack bindings now say where tags actually live.**
  `story_project_dimensions` returns fields only - it has never returned
  tags - while the binding pointed at it as the source for "dimension
  values", so an agent looking for the existing tag set found nothing and
  reasonably concluded it had no way to check. `docs/dimensions.md` has
  listed every usable tag, workflow and topical, all along. Both bindings
  now carry a separate row for it, note that the dimensions tool derives
  the project from the focused story when `projectKey` is omitted, and say
  plainly: never mint a tag because you could not find a list - say you
  could not read it and ask.


## [2026.08.13]

### Removed

- **`to-library-skill` has left the suite.** It moves to the
  dependency-skills project, where it ships beside the build plugin it
  teaches so the two cannot drift. It is now in the installer's
  `RETIRED_SKILLS`, so existing copies are pruned from projects and from
  `~/.agents/skills` on the next refresh. This happens before the
  replacement is installable on purpose — the version that shipped here
  scaffolds a packaging convention that has since been abandoned, and a
  stale skill teaching an abandoned convention is worse than none.

- **Five superseded skills retired.** `setup-project`, `manage-skills`,
  `manage-docs`, `manage-persona` and `sync-tracking` predate the current
  suite and were still sitting in projects installed by older versions of
  the wizard - the installer had no record of owning them, so nothing
  pruned them. They are now in `RETIRED_SKILLS` and go on the next
  refresh. Their work is done by the installer, `project-docs`, and
  `to-issues`/`story-reconcile` respectively.

### Changed

- **`grill-with-docs` 2.1.** Version bump for the story-format changes
  made in the same round that moved `story-workflow`, `story-reconcile`
  and `worklog` - this one shipped without one, so a bound project had no
  way to tell it was behind.

### Fixed

- **A bind on a brand-new project stopped silently, half done.**
  `copy_skills` ended with `[[ -n "$others" ]] && say ...`, listing skills
  the installer does not manage. In a project that has none - which is
  exactly what a new project is - the test failed, so the function
  returned non-zero and `set -e` killed the run right after the skills
  were copied. No pointer, no `setup.sh`, no entry in `recent-projects`,
  and not a word printed. Every project it had been exercised against had
  project-local skills, so the bug was invisible until a genuinely new
  repo hit it.

- **An aborted run now says so.** A `trap ... ERR` reports the exit code
  and line, states that nothing after that point ran, and names the
  pointer and `setup.sh` if they are missing. A `set -e` exit used to
  produce no output at all, which is how the above went unnoticed.

- **`node` is no longer required.** `merge_json` was the only user of it
  and now uses `python3`, which the installer needs anyway; `python3` is
  checked up front rather than mid-bind. The pointer is written via a
  temporary file and `os.replace`, so an interrupted run cannot leave a
  truncated one. Node remains a maintainer-only dependency for the
  YouTrack app's tests, which run in YouTrack's sandbox, not here.

- **Binds verify themselves.** `verify_bind` checks the pointer,
  `setup.sh` and the skills directory at the end of the GitHub,
  tracker-less and YouTrack flows, and reports plainly when a project is
  not actually set up.

## [2026.08.08.1]

Nothing yet.

## [2026.08.08]

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
