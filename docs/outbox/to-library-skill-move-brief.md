# Moving the library-skill skill into the plugin repo

Working note, not a deliverable. Written 2026-08-11, before the repo
reorganisation. Delete once the move is done and the skill is rewritten.

## What is moving

`skills/docs/to-library-skill` (v4.5, 455 lines, 7 scripts) leaves the
story-tools repo and becomes a companion skill packaged with the build
plugins.

**Destination (decided 2026-08-12):** `dependencyskills/dependencyskills`,
a monorepo under its own GitHub org, Maven namespace `org.dependencyskills`,
canonical domain `dependencyskills.org`. This supersedes the earlier
`agent-skills-gradle` / `-maven` / `-ivy` split and the
`io.github.aughtone` coordinates - every plugin id, group and package
below reads against the new namespace, not the old one.

**The name stays `to-library-skill`.** It says what the skill produces,
matches the suite's `to-<output>` pattern, and does not collide with the
plugin id (`io.github.aughtone.agent-skills`) or the repo name, which
`to-agent-skills` would have. If it ever does change, note that the
frontmatter `name` must equal the parent directory exactly - lowercase
letters, digits and hyphens - so both move together.

## Why it needs rewriting, not just moving

The skill is still entirely on the model ADR-0003 dropped. It currently
teaches:

- authoring into `META-INF/agents/skills/<name>/SKILL.md` as a packaged
  resource
- declaring `Agent-Skills` in the jar manifest
- a scanner that reads every layout in circulation, opening jars and AARs

ADR-0003 §5 dropped all of that: no archive scanning, no manifest
attribute, the skill is not a packaged resource at all. Applying the
current skill to a library produces the layout you already rejected.

## What the rewritten skill teaches

1. **Author at `src/agent-skills/<name>/SKILL.md`.** Not a resource - a
   plain directory a Zip task reads. Lowercase and hyphens throughout;
   the old `src/agentSkills` is a case-sensitivity trap (works on macOS
   and Windows, fails on Linux CI, and git can end up tracking two
   entries differing only by case).
2. **Apply the plugin** - id under `org.dependencyskills` (exact id TBD
   with the repo layout; NOT the old `io.github.aughtone.agent-skills`) -
   and what the extension offers: `enabled`, `skillsDir`, `classifier`,
   `publish`, `strict`.
3. **Publish the sidecar** - `<artifact>-<version>-skills.zip` on the
   library's existing coordinates, declared as a Gradle Module Metadata
   variant. Flat layout inside the zip: `<name>/SKILL.md`.
4. **The KMP root-module caveat** - `addVariantsFromConfiguration` throws
   on a KMP root component, so the plugin falls back to a plain classified
   artifact and warns. The zip publishes; only the `.module` line is
   missing, so consumers must name the classifier by hand until it is
   solved.
5. **What a library skill should contain** - description, capabilities in
   the caller's words, usage patterns, invariants and traps, what it is
   NOT for, provenance. This is the part the spec leaves unclaimed and
   the part the codex is built from; keep it and expand it.
6. **Validation** - the plugin already enforces spec rules, filesystem
   rules and length rules at build time. The skill should point at it
   rather than restate it.

## What to delete

Everything supporting in-archive bundling: the `META-INF` scaffold, the
manifest-attribute section, the "shape has converged, prefix has not"
discussion, and the layout table listing every convention in circulation.
That table exists to serve a scanner that no longer exists.

`scripts/metainf-scaffold.sh` goes with it.

## What to keep

**Both migration paths.** v1 (`.ai-skills/<id>.ai-skill.md`) and v2
(`META-INF/agents/skills/`) exist in real libraries today, including
yours, and `migrate-library-skills.sh` is the tool that retires them.
Migration is now v1/v2 → sidecar, so the destination changes but the
detection does not.

**`index-library-skills.sh`** for multi-module repos.

## Ecosystems: keep them (question resolved)

Earlier framing was "narrow it to JVM". That was wrong. A KMP library is
not a JVM library with extra targets - it **is** an SPM package for iOS
consumers and **is** an npm package for JS and wasm consumers, published
through those channels from the same source. Dropping the SPM and npm
scaffolds would ship a skill that a library's iOS consumers cannot see.

This sharpens the thesis rather than blurring it. SPM checks out source
and npm unpacks into `node_modules`, so the file is *visible* in both and
a directory convention already works. Maven and Gradle never unpack. One
library, three channels, one of which is broken - and that one is the gap.

### One authoring location, N publication channels

`src/agent-skills/<name>/SKILL.md` is the source. From there:

| Channel | Mechanism | State |
|---|---|---|
| Maven / Gradle | sidecar zip + GMM variant | plugin, built |
| SPM | file committed at the conventional path; SPM checks out source | needs a mirror step |
| npm | conventional path, and listed in package.json `files` or it is not in the tarball | needs a mirror step |

The plugin zips today; it does not emit. Open: whether mirroring is the
plugin's job or a scaffold's. SPM may need nothing beyond the file being
committed in the right place, which argues for a scaffold; npm needs a
manifest edit, which argues for tooling.

## Retirement sequence in story-tools

Two separate steps, and only the first is safe to do early.

**Done (2026-08-11):** removed from `SKILLS` in `install.sh`, with a
comment saying why. New and re-run installs no longer place it. Existing
copies are untouched and keep working - nothing is deleted.

**Still to do, in this order:**

1. New repo publishes the plugin with the skill packaged.
2. Verify a consuming project gets the skill by applying the plugin.
3. Add `to-library-skill` to `RETIRED_SKILLS` so existing copies are
   cleaned up on the next install run. Not before - that mechanism
   deletes, and deleting before the replacement is installable leaves a
   hole.
4. Leave a pointer in the story-tools README saying where it went.

The source tree keeps `skills/docs/to-library-skill/` until the move is
complete; it is simply no longer installed.

## Related decisions from this session

- **Skill first.** The skill carries the build-system install template -
  the `plugins { }` block, the version catalog entry, the extension
  defaults - so applying the skill is what causes the plugin to exist in
  the build. This resolves the bootstrap objection to co-locating them: a
  skill packaged only inside the plugin would arrive too late to install
  it. The repo doubling as a Claude Code plugin marketplace (as KSafe
  does) serves the skill with no build involvement, while the Gradle
  plugin packages the same file so the two cannot drift.
- **One repository** for the plugins, so the convention - classifier,
  variant attributes, capability format, zip layout - lives once with
  shared conformance fixtures. A test that publishes with one
  implementation and consumes with another is the point, and it cannot
  exist across three repos. Settled as `dependencyskills/dependencyskills`.
- **The design record should follow the project.** ADR-0003 and ADR-0004
  are decisions *about this project*, currently sitting in story-tools
  because that is where they were written. Move them into the new repo
  with stubs left behind, and take `jvm-agent-skills-proposal.md` with
  them - it is the public face of the same argument. Cheaper before the
  repo has contents than after, and it means the reasoning lands before
  the code that assumes it.
- **Ivy needs justification.** Reserving a module for symmetry is not the
  same as someone needing it.
- **The plugin should publish its own skill through its own mechanism.**
  If that does not work end to end, the convention is not ready for
  anyone else.
- **Path segments are lowercase, digits and hyphens.** Gradle DSL
  identifiers (`agentSkills { }`) are Kotlin, not paths - camelCase is
  correct there and should stay.

## Where the reasoning lives

**Moved 2026-08-12** into `dependencyskills/dependencyskills`; redirect
stubs remain here.

- `docs/adr/0003-library-skills-via-repository-artifacts.md` - the
  sidecar decision, why bundling was dropped, the constraints
- `docs/adr/0004-librarian-and-codex.md` - discovery at scale, why one
  skill per library does not work
- `docs/proposal.md` (was `docs/outbox/jvm-agent-skills-proposal.md`) -
  the public argument behind both
- `docs/adr/0005-repository-structure.md` - new, records the repo layout
  and the three splits rejected on the way to it

Coordinates in the moved copies were retargeted from `io.github.aughtone`
to `org.dependencyskills`, and `src/agentSkills` to `src/agent-skills`.
The decisions themselves are unchanged.

The background argument - the measured packaging findings and the
assertions still needing verification - lives separately in the author's
writing workspace and stays there. It is raw material for an article, a
different artifact with a different audience.
