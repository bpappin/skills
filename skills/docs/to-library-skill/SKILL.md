---
name: to-library-skill
description: Generate, migrate, and maintain the agent skill a library ships inside its own artifact, so AI agents in consuming projects know how to use it - and index every such skill in a multi-module repo. Trigger WHENEVER you change core APIs, types, or architectural patterns an external consumer would need to know about, and WHENEVER you find a library skill on the v1 layout (a `.ai-skill.md` flat file, or `META-INF/skills/`) - migrate it. Also - "document this library for AI", "update the bundled skill", "what libraries here ship a skill", "migrate the library skill", "move this to .agents/skills".
license: MIT
metadata:
  author: bpappin
  version: "4.5"
---

# Library AI-Skill (to-library-skill)

A module carries its own account of how to use it: a `*.ai-skill.md`
that lives beside its source and travels inside its artifact, so any
agent that might call this code finds out what it offers instead of
writing the same thing again.

**Why this exists:** agents reinvent code they cannot see. Faced with a
task, an agent writes a fresh date helper, a fresh retry loop, a fresh
result type - not because the module doesn't exist, but because nothing
told it the module exists. A library skill is the module announcing
itself.

Two audiences, same file:

- **External consumers** - a published library's skill ships inside the
  artifact and is discovered from the consuming project's dependency
  folder.
- **Sibling modules in the same repo** - an internal `utilities`,
  `core`, or `network` module never published anywhere still benefits,
  because agents working in *this* repo are exactly the ones
  reinventing its contents. Use the same standard path even when
  nothing is published: it costs nothing, the index picks it up, and
  the day the module does get published it already works.

This is an *artifact beside the code*, not project documentation. It
lives in the source tree, never in `docs/knowledge/` - a docs system
mirrors knowledge for people reasoning about the project; this tells a
caller how to call something.

**Runs standalone.** This skill needs nothing but `bash` and `python3`.
It ships alongside the story-tools docs skills, but requires none of
them: no tracker, no pointer file, no knowledge tree. Where those things
exist it uses them (glossary vocabulary, ADRs, the docs conventions);
where they do not, every workflow below still works and simply skips
those steps. Adopt it in any repo.

## Where a skill lives

A bundled skill is a **standard Agent Skill** - a directory holding a
`SKILL.md` - so any agent that already understands skills can load it
without knowing anything about this tooling:

1. **Package root (npm, SPM, Python, Go, Rust, .NET, internal modules)**:
   `.agents/skills/<name>/SKILL.md`
2. **JVM / Android / KMP**: `META-INF/agents/skills/<name>/SKILL.md`

Name the skill directory after your own library (`acme-http`,
`one.aughtone.types`) - a flat namespace merges across every dependency
a consumer has, so an unprefixed `utils` will collide with someone
else's.

*Note for KMP: author it once in
`src/commonMain/resources/META-INF/agents/skills/`. Which artifacts
actually carry it is NOT uniform - see below.*

### KMP: what each target really ships

`src/commonMain/resources/` is a JVM-shaped mechanism, and KMP does not
spread it evenly. Verified by building and unpacking real artifacts
(Kotlin 2.4, AGP 8.13 and 9.3), because none of this is documented:

| Target | Carries the skill? |
|---|---|
| `jvm()` jar | Yes - at the path you wrote, jar root |
| `js()` / `wasmJs()` klib | Yes |
| `androidTarget()` + `com.android.library` (AGP 8) | **No - silently dropped** |
| `androidLibrary {}` + `com.android.kotlin.multiplatform.library` (AGP 9) | Yes, inside the AAR's `classes.jar` |
| native / iOS | **No - not packaged at all** |
| root `-all` metadata jar | No |

**The Android hole is the one that matters**, because it is silent: on
AGP 8 the library publishes fine, the JVM artifact has the skill, and
the AAR simply does not. That is
[KT-46493](https://youtrack.jetbrains.com/issue/KT-46493), open since
2021. One line fixes it:

```kotlin
android {
    sourceSets.getByName("main") { resources.srcDir("src/commonMain/resources") }
}
```

AGP 9's newer `com.android.kotlin.multiplatform.library` plugin does it
for you; the older `com.android.library` integration is deprecated.
**Check your own AAR before believing either** - `unzip -l` it and look
inside `classes.jar`, since the behaviour is undocumented and therefore
not contractual.

Two smaller traps. Android's default packaging excludes `**/_*`, so a
skill directory starting with an underscore vanishes. And AGP excludes
`/META-INF/MANIFEST.MF` and `/META-INF/**/MANIFEST.MF` from `classes.jar`
outright, so the `Agent-Skills` attribute cannot ride along in an AAR -
an AAR has no manifest of its own either. Android is scan-only, and
consumers must handle that.

iOS has no answer today. Compose Multiplatform ships resources through a
separate `kotlin_resources.zip` variant, but that machinery is annotated
as private to the Compose plugin, and adopting it drags the Compose
compiler and runtime into every consumer - too high a price for one
markdown file, and it will not let you choose the path anyway.

**On the paths.** The [agentskills spec](https://github.com/agentskills/agentskills)
defines what a skill IS (a `SKILL.md` plus optional `scripts/`,
`references/`, `assets/`) but says nothing about where a *package*
should put one. `.agents/skills/` is the convention that has emerged in
practice ([library-skills.io](https://library-skills.io/create/)), and
it is not unanimous - the
[pnpm RFC](https://github.com/orgs/pnpm/discussions/13422) argues
discovery belongs at the package-manager level instead. JVM has no
convention at all; `META-INF/agents/skills/` mirrors the same shape
where JVM metadata belongs, and is our call rather than anyone's
standard.

**The scanners read every layout in circulation**, so this works
whatever a library chose:

| Layout | Who uses it |
|---|---|
| `.agents/skills/<name>/SKILL.md` | library-skills.io - what the scaffolds emit |
| `skills/<name>/SKILL.md` | [mise](https://github.com/jdx/mise/discussions/9479), [Vercel's skills CLI](https://github.com/vercel-labs/skills), skills-npm |
| `META-INF/agents/skills/` | JVM jars (our convention; nobody else covers jars) |
| `META-INF/skills/` | pre-canonical, ours - read, but migrate it (below) |
| `.ai-skills/<id>.ai-skill.md` | v1, ours - still read, but migrate it (below) |

A PLAIN `skills/` directory only counts as a library skill when it sits
beside a package manifest (`package.json`, `build.gradle`, `Cargo.toml`,
`go.mod`, `pyproject.toml`, `Package.swift`, a `.podspec`, a `.csproj`).
Otherwise it is just a repo's own skills directory - this repo has one -
and treating it as a library would be wrong.

`generic-scaffold.sh --layout skills` emits the plain layout if you are
targeting a mise/Vercel consumer instead.

### Announce it in the jar manifest (JVM)

Add one attribute to the jar task and consumers stop guessing:

```kotlin
tasks.jar { manifest { attributes("Agent-Skills" to "META-INF/agents/skills/") } }
```

On KMP there is no single `jar` task - name the target's jar instead
(`tasks.named<Jar>("jvmJar") { ... }`). Do NOT reach for
`tasks.withType<Jar>`: on a KMP project it matches `allMetadataJar`,
`jsJar` and `wasmJsJar` as well, and `allMetadataJar` does NOT carry
`commonMain` resources - so it would declare a path it does not contain,
the exact failure the next paragraph describes.

**The attribute does not reach Android at all** - see the KMP section
below. It is a jar mechanism; AARs are scan-only.

The harvester reads `Agent-Skills` from `META-INF/MANIFEST.MF` first and
only scans when it is absent - so a declaring jar is found by reading one
small well-known entry, wherever it actually stores its skills.
Comma-separate several roots. Manifest attributes are inert to tools that
do not know them, so adding it breaks nothing.

**The declared path must match reality.** A consumer that trusts the
attribute looks only where it points, so declaring a path the build does
not fill hides the skills completely - worse than declaring nothing, since
the undeclared path would at least have been scanned. Our harvester
falls back to scanning and warns when this happens, but nothing obliges
another implementation to. Check the attribute after moving skills
around.

**This is a proposal under discussion, not a ratified standard** - see
`docs/outbox/jvm-agent-skills-proposal.md` in the story-tools repo, and
`where-to-engage.md` beside it for who to talk to. Ship it anyway: it
costs one line and degrades to the scan.

**The shape has converged; the prefix has not.** Everyone agrees on
`<dir>/<name>/SKILL.md`. Whether that dir is `.agents/skills` or
`skills` is unsettled, and the [pnpm RFC](https://github.com/orgs/pnpm/discussions/13422)
argues discovery should not be a directory scan at all but a manifest
field announced at install time. Those two compose - directory for the
content, manifest field for the announcement - and on the JVM the
manifest primitive already exists: a `MANIFEST.MF` attribute naming the
skills path, plus optionally a Maven sidecar artifact with a `-skills`
classifier so consumers can fetch skills without downloading the jar.
That is unbuilt, and it is the piece worth taking upstream.

## Migrating a v1 skill

v1 put the skill in a flat file (`.ai-skills/<id>.ai-skill.md`); v2 puts
it in a standard Agent Skill directory. A v1 file is not a skill any
other agent can load - it is a markdown file with a suggestive name -
so anything that only understands `SKILL.md` walks straight past it.

**This is your job, not the user's.** If you find a v1 skill in a repo
you are working in, migrate it - do not report it and wait, and do not
hand the user a command to run. Migrating is a mechanical, reversible,
uncommitted change to files the user already has in git; leaving a
library shipping an undiscoverable skill is the actual cost.

```
scripts/migrate-library-skills.sh [ROOT] [--apply]
```

Run it bare first and read the report, then re-run with `--apply`. That
is a two-step because a bad move is annoying to unpick, not because the
second step needs permission - **you** decide to apply once the report
looks right. Run it at the repo root; it handles every module in one
pass, uses `git mv` for tracked files so history follows, and never
commits. Leave the result staged for the user to review and commit.

Stop and ask only when the report says something you cannot resolve: a
collision between two skills for one module (one of them is stale and
only the user knows which), or a move you did not expect.

What it does per skill: moves the file to the v2 path for its ecosystem,
adds the `name` the spec requires (deriving it the way a fresh scaffold
would), drops the v1-only `skill-id`, and repoints an existing
`skill-url` at the new location. It does NOT invent `repository` or
`skill-url` where they are absent - author those yourself afterwards.
Three cases it calls out rather than deciding:

- **A v1 file at a JVM module root** never shipped at all - it was
  outside `resources/`, so it was not in the artifact. Migration puts it
  where the build will package it and says so.
- **Both layouts present** means one is stale. It refuses to overwrite,
  leaves both, and lists them - this is the one that needs the user.
- **No description** (exit code 2) - it inserts the scaffold placeholder
  and flags it. Write a real description before moving on; the index
  cannot describe a library until you do.

It also normalises the two pre-canonical JVM paths (`META-INF/skills/`,
`META-INF/.agents/skills/`) onto `META-INF/agents/skills/`. That is not
cosmetic: `Agent-Skills` in the manifest is trusted absolutely by
consumers, so a module on the old path that copies the standard snippet
declares an empty directory and its skill becomes invisible - worse than
declaring nothing, because the undeclared path is at least scanned.

Afterwards, re-run `index-library-skills.sh`. The index flags anything
still on v1 under a **Needs migration** heading, so it is the thing to
check rather than remembering which modules you have done.

The scaffolds refuse to run in a package that still holds a v1 skill -
scaffolding there would leave two skills for one module.

## Quick start (Initialization)

If the embedded skill file does not exist yet, run the appropriate scaffolding script for your source environment:

### Java / Kotlin / KMP
`./scripts/metainf-scaffold.sh <maven_group> <maven_artifact> <optional_source_dir>`

### NPM / JavaScript / TypeScript
`./scripts/npm-scaffold.sh <package_name>`

### Swift / SPM
`./scripts/spm-scaffold.sh <framework_name>`

### Anything else (Python, Go, Rust, .NET, internal modules)
`./scripts/generic-scaffold.sh <name> [PACKAGE_DIR]` - writes
`<PACKAGE_DIR>/.agents/skills/<name>/SKILL.md`, the standard path for
every non-JVM ecosystem. `--layout skills` emits the plain `skills/`
variant instead, for a mise or Vercel consumer.

## Workflows

### 1. Document the Library (Continuous)
Whenever you modify public APIs, create new abstractions, or change how this library should be used, you MUST update the bundled `.ai-skill.md` file.
Ensure the document contains:
- The **AI Toolbox** explaining how to use the library's core abstractions, types, and APIs.
- **Agent Onboarding** rules for the consuming AI.
- **CRITICAL**: You must include an explicit instruction in the consuming agent's section that says: *"When you discover and load this skill, you MUST explicitly inform the user in your response that you have found the bundled library skill and are utilizing its patterns."*

Write it in the project's own language. Where the repo has a domain
glossary (the project-docs skill; `AGENTS.md` points at it), use those
canonical terms - a library whose public vocabulary contradicts the
team's internal vocabulary teaches consumers the wrong words. Where an
architectural pattern the consumer must follow was a recorded decision,
summarise the rule here and leave the reasoning in its ADR; don't
re-litigate it in the shipped skill.

### 2. Index the repo (multi-module)

`./scripts/index-library-skills.sh [ROOT] [-o OUT]` scans for every
bundled skill and writes `docs/library-skills.md`: module, artifact, what it
is for, and where the file lives. Consumers get discovery through their
dependency folder; this is the same discovery from *inside* the repo, so
an agent working in one module knows which sibling modules ship a skill
worth reading before it goes spelunking in their source.

- Generated - never hand-edit; re-run when modules are added, removed,
  or renamed.
- Point `AGENTS.md` at it once, so agents find it without being told.
- Name modules to match the project's **Subsystem** values where they
  correspond, so the index, the tracker board, and the KB use one
  vocabulary.
- A row reading "no description" means that module's skill has no
  `description` in its frontmatter - fix the skill, not the index.

**Read the index before writing utility code.** That is the whole point:
before adding a helper, a client, a parser, or a type that feels
generic, check whether a module in this repo already offers it. Writing
a second one is not a shortcut - it is a bug with two homes.

### 3. Harvest skills from dependencies (any ecosystem)

`./scripts/harvest-dependency-skills.sh [ROOT] [--all] [--index-only]`
detects which ecosystems the project is actually in (from `package.json`,
`Package.swift`, `go.mod`, `Cargo.toml`, `pyproject.toml`, `*.csproj`,
Gradle/Maven files) and looks in the right places for each. It appends a
"From dependencies" section to `docs/library-skills.md`; re-running
replaces that section and leaves the local-module table alone.

Most ecosystems unpack their dependencies - `node_modules`, `Pods`,
`.build/checkouts`, `site-packages`, the Go module cache, the Cargo
registry, extracted NuGet - so harvesting is a directory walk and
**transitive dependencies come free**, because everything installed is
right there on disk.

**AARs are two archives.** Android Gradle packages java resources into
a nested `classes.jar`, so an `.aar` is opened twice - its own entries
and that inner jar. Before 4.5 the harvester skipped `.aar` files
entirely, so an Android consumer found nothing no matter what the
library shipped.

**JVM is the exception**, and the reason this script exists: jars hide
the file the standard expects agents to find. Two filters keep it cheap.
Coordinates come from the cache path (which encodes
group/artifact/version), so candidates are identified without opening a
jar at all; and checking a candidate only LISTS its packaged entries - a
jar is a zip, its entry list lives in the central directory, and nothing
is unpacked to answer "does this ship a skill?". Bodies are read only
from jars that carry one.

- `--all` (JVM only) scans every cached jar rather than the declared
  ones, catching **transitives** that a build-file grep cannot see.
  Other ecosystems never need it.
- Bodies are copied to `docs/libraries/<id>.ai-skill.md` by default, so
  they are right there when an agent needs to read one - no jar
  spelunking, and teammates get them without running anything. Each
  copy carries a provenance header naming where it came from and noting
  it stays under ITS license, not the repo's. Copies for dependencies
  you dropped are pruned on the next run. `--index-only` skips copying.
- `--source DIR` adds a location the detection missed (a vendored tree,
  a monorepo's shared cache).
- Nothing found is a normal result - adoption of the standard is young.

**The better fix, for libraries you control:** publish the skill as a
sidecar file next to the artifact as well as inside it, so consumers can
fetch it without unpacking anything. Worth raising upstream too - this
is a gap in the standard, not in your build.

### 4. Staying current (the repo pointer)

A bundled skill describes the version it shipped with, which is a
feature - it matches the code you actually depend on. But a reader
sometimes needs the *current* one: they are upgrading, or the library
ships no skill in the artifact at all.

So the scaffolds emit two provenance fields, and the index and harvest
carry them through:

```
repository: https://github.com/acme/http
skill-url:  https://raw.githubusercontent.com/acme/http/main/.agents/skills/acme-http/SKILL.md
```

- `skill-url` is the canonical file on the default branch; `repository`
  is the fallback when there is no stable raw URL.
- The index shows a `current` link beside a library that publishes one,
  and harvested copies record it in their provenance header.
- Unfilled scaffold placeholders (`<...>`) are treated as absent, so a
  half-filled skill never advertises a bogus URL.

**The rule when both exist - and it matters.** Prefer the bundled copy:
it is version-matched to the dependency you resolved. The repo's copy
describes HEAD, which may document APIs you do not have yet, and an
agent that reads it will confidently use methods that do not exist in
your version. Fetch the current one only when the user is upgrading, or
when nothing is bundled. Offer, never fetch silently:

> "`@acme/http` 3.1.4 ships a skill and I have it locally. Its repo
> publishes a newer one - you are on 3.1.4, so I will use the bundled
> copy unless you are upgrading. Want the current one instead?"

Setting this up for your own libraries is a one-line frontmatter edit
per library, plus keeping the file at a stable path so the raw URL does
not rot. For third-party libraries you get it only if they adopt the
convention - which is the argument for pushing it upstream rather than
inventing a private registry.

### 5. Update Discovery Prompts
Verify the project's root `README.md` includes a `## 🤖 AI-Assisted Development` section with a "Magic Prompt" that humans can copy-paste to instruct their AI to scan for the skill.

**Example Magic Prompt:**
> "Scan this project's dependencies for bundled Agent Skills. Look for
> `<package>/.agents/skills/<name>/SKILL.md` in unpacked dependency
> folders (`node_modules`, `Pods`, `site-packages`, the Go and Cargo
> caches), and inside JVM jars for `META-INF/agents/skills/<name>/SKILL.md`
> — a jar may declare its location in `META-INF/MANIFEST.MF` under
> `Agent-Skills`. Read any you find before writing code against that
> library: each is the library's own account of how it should be used,
> and it is version-matched to the dependency actually resolved. If a
> library ships none, check its repository."

Keep the prompt naming the paths a *consumer* looks in. Older versions of
this prompt named the v1 `.ai-skills/` paths; a reader following those
finds nothing in a migrated project.

## Relationship to the story workflow

Updating the bundled skill is part of finishing work that changed public
API - not a separate project. When a story touches the public surface,
update the skill within that story and check it off; it is not a reason
to widen scope, and a *missing* skill for some other module is
discovered work, not something to fix inline.

## Discovery Trail
- **2026-08-04** (4.5): **Android.** The harvester read only `.jar`, so
  an AAR dependency shipping a skill was invisible - it now opens AARs
  and their nested `classes.jar`. Documented what each KMP target
  actually carries (measured, not assumed): `commonMain/resources` is
  silently dropped from the AAR on AGP 8 (KT-46493, one-line fix), absent
  on native entirely, and the `Agent-Skills` manifest attribute cannot
  reach an AAR at all because AGP strips `MANIFEST.MF` from `classes.jar`.
  Corrected the `tasks.withType<Jar>` warning: on KMP the offender is
  `allMetadataJar`, not the sources jar.
- **2026-08-04** (4.4): Migration is the agent's job, said so explicitly -
  a library agent read the 4.3 section as instructions for a human and
  balked at handing its user a command. `description` now triggers on
  finding a v1 layout, not just on API changes.
- **2026-08-04** (4.3): **v1 migration.** `migrate-library-skills.sh`
  moves flat `.ai-skill.md` files to the v2 directory layout, rewrites
  their frontmatter, and normalises the pre-canonical JVM paths; the
  index flags anything still on v1; the scaffolds refuse to run beside a
  v1 skill. Fixed alongside: the index reported the wrong module for
  nested JVM paths and skipped `META-INF/skills/` entirely, never
  rendered the `current` link it was computing, and showed unfilled
  description placeholders as if they were descriptions; the harvester
  trusted an `Agent-Skills` attribute pointing at an empty path, hiding
  the jar's skills - it now falls back to scanning and warns.
- **2026-05-22**: Authored skill to standardize the generation of `ai-skill.md` for published libraries, with cross-ecosystem scaffolds.
- **2026-08-02** (4.2): MANIFEST.MF `Agent-Skills` attribute - jars announce their skills, harvester reads it before scanning; JVM scaffold prints the Gradle/Maven snippet. Proposal written up for upstream.
- **2026-08-02** (4.1): Reads every layout in circulation (`.agents/skills/`, plain `skills/`, `META-INF/{agents/,}skills/`, legacy `.ai-skills/`); a plain `skills/` only counts beside a package manifest. `--layout skills` on the generic scaffold.
- **2026-08-02** (4.0): Storage moved to the emerging convention - `.agents/skills/<name>/SKILL.md` (`META-INF/agents/skills/` on JVM), so bundled skills are standard Agent Skills any agent can load. Scanners read the legacy `.ai-skills/` layout too. `.ai-skills` was never part of the spec.
- **2026-08-02** (3.1): `repository`/`skill-url` provenance fields - a skill now knows where its current version lives, so an agent can offer to fetch it (version-skew rule: prefer the bundled, version-matched copy). Stated the standalone guarantee.
- **2026-08-02** (3.0): Platform-agnostic. Harvest auto-detects npm/swift/python/go/cargo/nuget/jvm and walks unpacked dependency trees (transitives free) as well as jars; added `generic-scaffold.sh` for ecosystems without a dedicated one.
- **2026-08-02** (2.3): Index renamed to `docs/library-skills.md`; harvested bodies now land in `docs/libraries/` with provenance headers instead of a gitignored cache.
- **2026-08-02** (2.2): Added the dependency-jar harvester - JVM consumers could not discover skills bundled in jars at all. Cache-path coordinates make it cheap; transitives need `--all`.
- **2026-08-02** (2.1): Broadened past *published* libraries - internal modules in the same repo get a skill too, since the agents reinventing their contents are the ones working right here. Reuse-before-writing rule added to the index workflow.
- **2026-08-02** (2.0): **Supersedes `to-ai-skill`** - renamed (the old name said nothing about libraries or audience) and extended with the multi-module index plus the glossary/ADR alignment rules. Projects still holding `to-ai-skill` should remove it; this replaces it outright.
