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

## [2026.09.16]

### Changed

- **`budget-skills/` is now `light-skills/`.** Budget read as cheap; the set is small, self-contained, and built for tight context budgets and strict code review, not a lesser version of anything. The skills themselves never named their directory, so nothing inside them changed. The two pieces of repo tooling that did - the pre-commit version gate and the installer's retired-skill guard - now find a skill by the `SKILL.md` it contains rather than by the tree it sits in, so no future rename touches them. Released entries below keep the old name, as history.
- **An ADR's decision is append-only; the document around it is maintained.** The taxonomy said flatly that ADRs are append-only, so a record that stated something false - a constant since renamed, a claim that was wrong when written - had no repair short of filing a fresh ADR to announce a rename. That is noise, and leaving the wrong sentence standing is worse, because the next reader, usually an agent, takes it as authoritative and acts on it. `to-adr` already allowed the fix; the taxonomy and `to-rad` contradicted it, and the taxonomy is what a filing agent reads. All three now say the same thing. A rename, typo or dead link is corrected silently; a substantive correction gets a dated line under a new `## Corrections` section at the foot of the record, which the ADR template now carries. Two edits are explicitly not corrections: rewording the Decision, which is a new ADR that supersedes, and rewriting Context with hindsight, which destroys the evidence of what was known at the time. `Status:` stays the decision's standing and never becomes a correction log - nothing in the suite parses that line, so the convention is settled here rather than invented per project. Raised by a project that hit it. project-docs 1.37, to-adr 1.4, to-rad 1.5, light-skills project-docs 1.9, to-adr 1.2, to-rad 1.4.

## [2026.09.11]

### Changed

- **`handoff` writes to the system's temporary directory in both skill sets - never into the repo, and never onto a tracker story.** The budget version appended the handoff to the story file being worked, which gets committed; the main version posted it as a comment on the focused story, which on a public repository is world-readable the moment it posts. Either way a summary of a live conversation - the moment names, credentials and verbatim quotes slip into text - landed somewhere permanent, and a handoff is stale by the next session anyway; what should outlive a session already has a home on the story. Both now match the upstream skill they were adapted from: temporary directory only, a "Suggested skills" section, and a rule to redact keys, tokens, passwords and personal information. The main version keeps its step that proposes logging the session's time. handoff 1.2, budget-skills handoff 1.3.

### Fixed

- **The budget research template's example ADR link had no `ADR-` prefix**, contradicting the naming convention the same set teaches; it was missed when story ids were renamed. budget-skills to-rad 1.3.

## [2026.09.10]

### Fixed

- **The installer executed a command while writing the user-level skill manifest.** A backtick in that file's text was escaped one level too far, so the heredoc ran `./install.sh --clean-user` instead of printing it. From any other directory it failed harmlessly and left `Remove them with \.` in `~/.agents/skills/MANAGED.md`; started from `scripts/`, it re-ran the installer mid-install and stopped at an unexplained `Remove them? [y/N]`, the list it was asking about swallowed into the file. It is printed now, and the next refresh rewrites the damaged line. The other generated files were already escaped correctly.
- **Deploying the YouTrack app failed with `"validate" is now "app validate"`.** `deploy.sh` ran the apps CLI unpinned, and its 1.x release renamed the subcommands. It now uses the new syntax, pinned to 1.0.3, and names the app directory explicitly because the new default is `dist`. Run by hand with no connection configured, it also crashed before its own error message: an empty array is unbound under `set -u` in the bash 3.2 that macOS ships, and the message it would have reached named a variable that was never set.
- **`yt-sync.sh` duplicated every edited article when the sync state and the current run spelled the knowledge-base path differently.** `KB_DIR` is accepted as `./docs/knowledge`, `docs/knowledge` or an absolute path, and paths were compared as raw strings, so state recorded under one spelling never matched a tree walked under another. An unedited file was rescued by the content match that detects local moves; an edited one was not, so it was pushed to its article *and* created again as a new one, with the local file then renamed to the duplicate's id. Every path is now rebuilt on one canonical form, resolved through symlinks, so existing state migrates on the next run with no re-bootstrap - and state that already records two articles at one file stops with an error rather than letting one overwrite the other. The dry run did list the duplicates under `New:`; the plan is only a warning if it is read whole. project-docs 1.36. The first attempt at this, in 1.35, named its path function the same as an existing text-normalising function further down the script, which replaced it before the state was read - so every project whose state recorded the default `./docs/knowledge` spelling planned the duplication on every edit, a regression from the release before. It was tested by extracting the function and running it alone, which is exactly the one situation in which the later definition cannot replace it; it is now tested by running the whole script against a faked tracker. A project that refreshed to 1.35 should refresh again, and read a dry run, before syncing.

## [2026.09.09]

Nothing yet.

## [2026.09.07]

### Fixed

- **The record-type list is short on purpose, and the recogniser matches it exactly.** `GUIDE-` and `SPEC-` are both gone: a guide is a `DOC-` in `guides/` and a specification is a `DOC-` in `specifications/`. The directory already says what a document is *about*; a prefix's job is to say how to *read* it. That is what `RAD-`, `ADR-` and `PRD-` do and why they cannot collapse into each other - a research log may be inconclusive, a decision is settled, a requirement is normative, and two of them on the same subject must still be read differently. A specification and an informational page are both descriptive prose maintained in place, so the distinction was subject matter, which is what directories are for. Stories are `STRY-`. The rule that *generates* prefixes is fixed in the same change, because it is what produced both: both taxonomies told a project that a cited document type earns a prefix, which conflates needing an identifier with needing a new one. Everything cited needs an identifier and `DOC-` is one; a new prefix is earned only by a document that must be READ differently from the existing types. The taxonomy no longer calls a specification purely descriptive: it may be binding, and where a project says so in the section's README, code contradicting it is a bug in the code rather than a stale document. That framing - not the prefix - is what a normative document actually needed, and the old wording invited a reader to correct the document to match the code. The reason for the short list is recorded rather than left implicit: too many prefixes make a messy system, and they are not needed - which outranks any individual case for adding one. The wiki sync's prefix set is now exactly the documented conventions and nothing else - an extra spelling kept "just in case" is documentation whether or not it is meant to be, because an agent reading the source treats anything there as blessed. project-docs 1.34, budget-skills project-docs 1.8.
- **The record-type prefixes are written down.** `taxonomy.md` said "numbering is per record type" and then named only `DOC-` and `RAD-`, so a project filing its first specification had nothing to follow and coined its own - which is how a near-miss against the wiki sync's recognised set became possible at all. `ADR-`, `PRD-`, `RAD-`, `DOC-` and `STRY-` are now listed in both taxonomies, with the reason a *living* document carries an identifier at all: a record's title is fixed the day it is written, but a specification's drifts as its subject sharpens, and under a pure-title filename every retitle is a rename and a dead inbound link. Raised by a project that had invented `SPEC-` and `GUIDE-` independently. project-docs 1.29, budget-skills project-docs 1.3.
- **Shortening wiki page names is now opt-in, with a migration path.** Dropping the record id renames every affected page, which breaks inbound links to a wiki that already exists - a migration, not a fix, and not something to arrive unannounced in a refresh. Off by default; `"wikiShortPageNames": true` in the pointer turns it on, `--short-page-names` previews it for one run, and a sync that finds ids in page names prints what the option does and what it costs. A wiki created fresh can enable it before the first sync and pay nothing.
- **`updates.check` is now asked, with a recommendation, and defaults to off.** The prompt states the trade-off rather than presenting a bare default: solo, yes - fixes reach you as they land; on a team, no, because every developer's setup pulling independently lands a different revision at a different time and those conflict in the tracked `.agents/` tree. Let one person update the repo for everyone.
- **The update prompt now carries the same reasoning as the setup question.** The setup answer was given once, possibly by somebody else, possibly months ago; the person who meets an actual update is the one best placed to decide they do not want the check. It appears only when an update is genuinely available, and says how to turn the check off.
- **`write_updates_config` never preserved an existing choice, on any path.** Its comment says "ask once, preserve thereafter", but all three `attach_project_*` paths delete the pointer before it reads - so it always saw an empty value and always took the default. Invisible while the default matched the value almost everyone had; the moment the default changed it would have silently flipped every GitHub project on its next refresh. The prior value is now read before the delete. Found by installing into a real project and noticing a `true` become `false`.
- **An unrecognised id-shaped prefix is now reported instead of silently declined.** The recognised set is closed on purpose - matching the id *shape* instead would swallow a real title, publishing `reference/ISO-8601-dates.md` as "Reference-Dates" with the identifying part gone. But a closed set fails badly on a near miss: a project writing a prefix one letter from a recognised one keeps its ids and cannot tell a deliberate refusal from a bug. Unrecognised prefixes are now listed at the end of a run, so the next case arrives as a line of output rather than as a bug report. Found by the project it happened to. project-docs 1.27, budget-skills project-docs 1.2. `SPC-` is gone entirely: it was never a convention, it appeared once in a sentence with a typo in it, and nothing used it.
- **`--dry-run` was not a faithful preview of link resolution.** `push_page()` returned on the dry-run guard *before* the `wikify()` that records a link with no wiki page, so only pages some other path happened to wikify were analysed - under-reporting 2 against 12 on a real 13-page tree. The guard now sits below the analysis: analyse always, write never.
- **A GitHub wiki page showed its title twice, worst first.** GitHub renders the page name, derived from the path, above the document's own H1 - so a record id in the filename became `Research RAD 0001 Identifier And Text Normalization` over `# Normalizing for blind matching`. The id is dropped from the page name and stays in the filename and the body. Two documents that would then collide on one page name is now a hard error naming both files, rather than a silent overwrite. The prefixes are a closed set, because `^[A-Z]{2,5}-\d{2,}-` also eats `ISO-8601-dates.md`.
- **"Everything under `docs/knowledge/` is published" meant two very different things.** A YouTrack KB is behind auth; a GitHub wiki inherits the repo's visibility, so on a public repo it is the open web, immediately, irreversibly. The taxonomy no longer implies the tracker decides, the GitHub binding carries the rule, and the sync states which model you are in on every run - a document is read once, the sync runs every time something is filed. All three reported from another project over the peer channel. project-docs 1.26.
- **`gh-wiki-sync.sh` blamed "the token" without saying which token.** It resolves a credential from four places in order - the environment, the pointer's connection env, `github.env`, then `gh auth token` - and a stale PAT in a connection env silently beats a working `gh` login. The failure message then sent the reader to the credential they knew about rather than the one in use. It now names the source it actually resolved. The probe also dropped `curl -f`, so a 401 is reported as a rejection with its status and distinguished from an unreachable API, which previously collapsed into the same "check the token" message. Reported from another project over the peer channel; the reporter lost minutes to exactly this. project-docs 1.25.
- **`--register` did different things depending on which script you ran.** The copy shipped as `.agents/setup.sh` tried the YouTrack connection and fell back to GitHub; the installer's own arm was YouTrack-only and errored out on a GitHub connection. The GitHub binding documents this flag for rotating a GitHub token, so the advice was correct on one script and wrong on the other. The installer now does the same fallback, and the help says the flag covers whichever tracker the connection is.
- **A GitHub connection whose name already began with `github-` registered as `github-github-<name>`.** The MCP server name is derived from the connection name, and the connection arrives in two shapes: a project bind builds it as `github-<dir>`, a refresh derives it bare from the directory. Two of the four sites that build the server name stripped the prefix first and two did not, so which shape you got decided whether the name doubled. All four now go through one `gh_server_name` helper. The connection name still names the credential file; only the server name is derived.
- **Step 5 of `to-issues` described a refusal that its own procedure could not produce.** Adding a topical value and applying one to an issue are different calls - `--push-tags` hits the label-creation endpoint on GitHub and the field's value set on YouTrack, and creates by design, while a rejection can only come from applying a value the tracker does not know. The paragraph ran the two together, so an agent following the procedure met a failure mode that procedure cannot reach. They are now separated, with the rule stated so it holds either way: never apply a value that is not already on the project's list, because some trackers refuse and others create it silently, and the silent one is worse. to-issues 1.16.

## [2026.09.01.1]

Nothing yet.

## [2026.09.01]

### Fixed
- **Two retired skills were still sitting in `skills/`.** `to-research` and `to-design` were in `RETIRED_SKILLS` and superseded by `to-rad` and `to-ux`, so they were pruned from bound projects - but the directories remained readable and copyable in the source tree, and `to-research` was duly copied into a new skill set by someone reading the tree instead of the list. Both are deleted, and `install.sh` now warns when any name in `RETIRED_SKILLS` still has a directory under `skills/` or `budget-skills/`, so the next one cannot sit there quietly. The `supersedes:` frontmatter on `to-rad` and `to-ux` stays, since it is the record of where each went.

### Added

- **`budget-skills/` - a parallel skill set for places the full package does not fit.** Eleven skills covering the RAD -> ADR/PRD -> Stories -> TDD spine plus filing, wiring and the session tools, held to two rules the main set is not: no script may touch the network or handle a credential, and every skill stands alone with no dependency on another skill, a tracker, an MCP server or a knowledge base. Copied into a project by hand; there is no installer. It is not a subset - the documents had to be written differently, and `to-stories` (stories as markdown files under `docs/stories/`) and a filing-only `project-docs` are new. The story body format is deliberately identical to the tracker-backed version, so a project that later adopts a tracker moves its stories by pasting rather than rewriting. AGENTS.md carries the rule that a change to one set means checking its counterpart in the other; nothing enforces it.

- **The image guidance said how to get a picture into the knowledge base and nothing about whether it could be read once there.** Both targets have a dark theme, so a diagram drawn on an assumed white page renders its dark text on a dark ground and the labels vanish - with nothing to suggest they were ever there, which is the worst way for it to fail. An image must now paint its own opaque background, SVG or alpha PNG alike. The rule says not to reach for a `prefers-color-scheme` media query instead, because an embed renders in an `<img>` that cannot see the host page: the query would follow the reader's operating system while the page follows a theme they set separately, trading a predictable failure for an unpredictable one. It sits in the taxonomy rather than in either tracker binding - it is a fact about the image file, not about YouTrack or the wiki.
- **Step 5 of `to-issues` said an approved topical tag should be confirmed "before it is written" and never said who writes it.** An agent that hit a tracker refusing a value that did not exist yet could read that as a permission it lacked, ask a human to add the value by hand, and publish the stories with the field empty - having followed the step as written. It now says the writing is the agent's to do once confirmed, that the binding holds the procedure, that a refusal of a value that does not exist is not a permissions problem, and that a short list from the dimensions tool is not evidence the set is small - the tool does not return tags on every binding. to-issues 1.14.

## [2026.08.30]

Nothing yet.

## [2026.08.27]

Nothing yet.

## [2026.08.26]

### Fixed

- **Refreshing a tracker-less project asked which YouTrack instance to
  use.** `project_mode` branched on GitHub and then fell through to the
  YouTrack path, so a plain `install.sh` in a project whose pointer says
  `tracker.type: none` went looking for a connection it has no reason to
  want, and exited demanding `--profile`. The tracker-less bind is now its
  own function shared by the wizard and by a refresh. It also stops
  deleting the whole pointer: that file carries `snapshot`, `updates` and
  roles besides the tracker, and a refresh has no business discarding
  them.

- **A here-document nested inside `$( )` broke the script on macOS.**
  bash 3.2 - what macOS ships as `/bin/bash` - cannot parse that, and
  desynchronises rather than failing where the problem is, so it reported
  a syntax error four hundred lines further down. The scan now runs as its
  own statement. Every other embedded python block in the script was
  already at statement level; this was the only one that was not.

- **A compound `local` declaration killed the tracker-less setup path.**
  `local dir="$1" f="$dir/docs/_config.yml"` looks like it reads
  left to right, but `local` is a builtin: bash expands every argument
  before the builtin runs, so `$dir` resolved against the outer, unset
  name and `set -u` aborted the script. It only fires where no caller had
  already set `dir` globally, which is why the `none` tracker path found
  it first - the wizard died in `write_pages_config`, before
  `ship_setup` and `verify_bind` could run, leaving a project with skills
  but no `.agents/setup.sh`. Both occurrences fixed; the suite was swept
  for the pattern and there were no others.

### Changed

- **Knowledge section directories are plain lowercase words.**
  `taxonomy.md` said section names are spelled out - "Architecture
  Decision Records", never "adr" - without distinguishing the KB title
  from the path, so a tracker-less project grew
  `docs/knowledge/Product Requirements/`, spaces and all. The sync never
  needed that: it reads each section's README H1 and only falls back to
  the directory stem. Titles stay spelled out; directories are now
  `decisions/`, `requirements/`, `specifications/`, `research/`,
  `reference/`, `guides/`, `testing/`, `compliance/`, `support/` -
  readable without knowing the jargon. Subsystem directories follow the
  same rule. These are starting points: a project's existing layout wins.

### Added

- **The installer offers to rename knowledge sections that predate that
  change.** It recognises the variants in the wild - title case with
  spaces, underscores, hyphens, and the abbreviations - previews every
  rename, and asks. `git mv` where possible, so history survives. It
  leaves synced trees alone, because there the directory name is derived
  rather than chosen: structure flows down only, and the sync moves anything
  it finds to `<ID>_<title-slug>`. A local rename there is futile before it
  is dangerous. It says so, and points at the real fix - rename the article
  in the tracker and the tree follows. Markdown still pointing at the old
  paths is reported, never rewritten - an unattended sweep across a docs
  tree is the kind of damage found months later. Design and accessibility
  sections are flagged rather than renamed: that content was split
  between `DESIGN.md`, `compliance/` and `docs/design/`, so there is no
  single target and a person decides.

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
