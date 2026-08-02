# Proposal: JVM packaging and manifest-declared discovery for Agent Skills

**Status: draft, circulated for comment.** Not a settled position -
corrections and disagreement welcome, particularly where it describes
someone else's project. · Author: bpappin · 2026-08-02

## The gap

Every current effort to let a library ship an agent skill assumes the
consumer can *see* the files. npm, SPM, Cargo, Go, and NuGet all unpack
dependencies onto disk, so a directory convention works: scan
`node_modules/*/`, find `.agents/skills/<name>/SKILL.md`, done.

The JVM does not unpack. A Gradle or Maven dependency is a jar sitting
in `~/.gradle/caches/modules-2/files-2.1/...` or `~/.m2/repository/...`.
Nothing in the resolved dependency graph is browsable, so an agent
working in a Kotlin, Java, Android, or KMP project cannot discover a
bundled skill at all — no matter which directory convention the library
followed.

This is not a niche. It is Android, all of KMP, and the whole
JVM server ecosystem.

## What already exists, and why it does not cover this

- The [Agent Skills spec](https://github.com/agentskills/agentskills)
  defines what a skill *is* (`SKILL.md` + optional `scripts/`,
  `references/`, `assets/`) but not where a package puts one.
- [library-skills.io](https://library-skills.io/create/) uses
  `.agents/skills/<name>/SKILL.md` inside the installed package.
- [mise #9479](https://github.com/jdx/mise/discussions/9479) and
  [Vercel's skills CLI](https://github.com/vercel-labs/skills) use a
  plain `skills/<name>/SKILL.md`.
- [pnpm RFC #13422](https://github.com/orgs/pnpm/discussions/13422)
  observes that the existing directory conventions each "put an
  adoption step in front of the discovery mechanism", and proposes
  addressing discovery at the package-manager level instead - an
  `agentNotice` field announced at install time.

All of these assume an unpacked tree. The pnpm point is the one I find
most persuasive, and also the hardest to generalise: a `package.json`
field does nothing for Maven or Gradle.

## Proposal

Three parts. They compose, and each is useful without the others.

### 1. A canonical path inside the artifact

```
META-INF/agents/skills/<name>/SKILL.md
```

Mirrors the shape everyone has converged on
(`<dir>/<name>/SKILL.md`) and puts it where JVM metadata belongs. No
leading dot: hidden directories inside an archive are unconventional and
buy nothing. `<name>` should be the library's own coordinates
(`one.aughtone.types`) because the namespace is flat once a consumer
merges skills from every dependency.

In KMP, authoring once in
`src/commonMain/resources/META-INF/agents/skills/` packages into the
JAR, XCFramework, and NPM tarball from a single source.

### 2. A manifest attribute that ANNOUNCES it

```
Agent-Skills: META-INF/agents/skills/
```

A single `MANIFEST.MF` attribute, comma-separated if a jar carries
several roots. This is the part that answers pnpm's objection without
needing a package manager to change: the jar declares its own skills, so
a consumer reads one small, well-known entry rather than pattern-matching
an entire archive — or worse, every archive in a cache.

It also decouples discovery from the path. A library that already ships
skills somewhere else keeps its layout and adds one line; the convention
in part 1 becomes a default rather than a requirement.

Build-side cost is one line:

```kotlin
// Gradle (Kotlin DSL)
tasks.jar { manifest { attributes("Agent-Skills" to "META-INF/agents/skills/") } }
```

```xml
<!-- Maven -->
<archive><manifestEntries>
  <Agent-Skills>META-INF/agents/skills/</Agent-Skills>
</manifestEntries></archive>
```

Manifest attributes are inert to every tool that does not know them, so
this is backward compatible by construction.

### 3. Optional: a sidecar artifact

Publish the skills additionally as a classified artifact —
`<artifact>-<version>-skills.jar` (or `.zip`) — so a consumer can fetch
skills from the repository *without downloading the dependency*. This
matters for tooling that wants to answer "does this library I am
considering ship a skill?" before adding it, and for environments where
the jar is large or not yet resolved.

Not required. Parts 1 and 2 stand alone.

## Reference implementation

Working, tested, MIT, in the `to-library-skill` skill of the story-tools
suite:

- `scripts/metainf-scaffold.sh` — creates the skill at the canonical
  path and prints the Gradle/Maven manifest snippet.
- `scripts/harvest-dependency-skills.sh` — resolves skills from
  dependencies across npm, SPM, Python, Go, Cargo, NuGet, and the JVM.
  For jars it reads `Agent-Skills` from `MANIFEST.MF` when present and
  falls back to a path scan when not.
- `scripts/index-library-skills.sh` — indexes skills bundled in a
  multi-module repo.

Verified: a jar storing its skill at a deliberately non-standard
`META-INF/custom-skills/` was discovered correctly *purely from the
manifest declaration*, which is the behaviour part 2 is meant to buy.

Cost of the scan fallback, for context: coordinates come from the cache
path, so only jars matching declared dependencies are opened, and
"opening" reads the zip central directory rather than extracting. It
works, but it is a workaround — a manifest read is O(1) per jar and
needs no heuristics.

## Open questions

1. **Attribute name.** `Agent-Skills` follows `MANIFEST.MF` convention
   (`Implementation-Title`, `Bundle-SymbolicName`). Alternatives:
   `X-Agent-Skills`, `AI-Skills`.
2. **Path vs. explicit list.** A directory prefix is simpler; an
   explicit list of `SKILL.md` paths avoids any walking at all.
3. **Transitive dependencies.** Without resolving the build's real
   classpath, a scanner can only match declared dependencies. Should a
   consuming build expose its resolved graph, or should the tool ship a
   Gradle init script?
4. **Should this live in the spec at all**, or in a JVM-specific
   companion document? The spec is currently silent on packaging for
   every ecosystem, not just this one.
5. **Android/AAR.** An AAR is a different container; does the same
   attribute and path work unchanged inside `classes.jar`, or does the
   AAR need its own entry?

## What I am asking for

Feedback on parts 1 and 2, and a decision on where a JVM packaging
convention should be documented. I am happy to write the spec text, and
the implementation already exists to point at.
