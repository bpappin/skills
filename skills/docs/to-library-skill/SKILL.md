---
name: to-library-skill
description: Generate and maintain the AI-skill a published library ships inside its own artifact, so AI agents in consuming projects know how to use it - and index every such skill in a multi-module repo. Trigger WHENEVER you change core APIs, types, or architectural patterns an external consumer would need to know about. Also - "document this library for AI", "update the bundled skill", "what libraries here ship a skill".
license: MIT
metadata:
  author: bpappin
  version: "4.2"
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
`src/commonMain/resources/META-INF/agents/skills/`. The build packages
it into the resulting artifacts (JAR, XCFramework, NPM tarball); the
consuming AI searches its own dependency folder.*

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
| `META-INF/agents/skills/`, `META-INF/skills/` | JVM jars (our convention; nobody else covers jars) |
| `.ai-skills/<id>.ai-skill.md` | pre-convention, ours - still read, don't author new ones |

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

The harvester reads `Agent-Skills` from `META-INF/MANIFEST.MF` first and
only falls back to a path scan when it is absent - so a declaring jar is
found by reading one small well-known entry, wherever it actually stores
its skills. Comma-separate several roots. Manifest attributes are inert
to tools that do not know them, so adding it breaks nothing.

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

## Quick start (Initialization)

If the embedded skill file does not exist yet, run the appropriate scaffolding script for your source environment:

### Java / Kotlin / KMP
`./scripts/metainf-scaffold.sh <maven_group> <maven_artifact> <optional_source_dir>`

### NPM / JavaScript / TypeScript
`./scripts/npm-scaffold.sh <package_name>`

### Swift / SPM
`./scripts/spm-scaffold.sh <framework_name>`

### Anything else (Python, Go, Rust, .NET, internal modules)
`./scripts/generic-scaffold.sh <skill-id> [PACKAGE_DIR]` - writes
`<PACKAGE_DIR>/.ai-skills/<id>.ai-skill.md`, the standard path for every
non-JVM ecosystem.

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
skill-url:  https://raw.githubusercontent.com/acme/http/main/.ai-skills/acme-http.ai-skill.md
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
> "Scan all project dependencies for AI Skill files in `META-INF/ai-skills/` (for JVM) or `.ai-skills/` (for NPM/SPM) matching this library. Use these to understand the API patterns and governance for this library. If not found in the local dependencies, refer to the repository for the source definitions."

## Relationship to the story workflow

Updating the bundled skill is part of finishing work that changed public
API - not a separate project. When a story touches the public surface,
update the skill within that story and check it off; it is not a reason
to widen scope, and a *missing* skill for some other module is
discovered work, not something to fix inline.

## Discovery Trail
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
