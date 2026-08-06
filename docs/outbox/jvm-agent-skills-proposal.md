# Proposal: repository-published Agent Skills for the JVM

**Status: draft v3, circulated for comment.** Not a settled position -
corrections and disagreement welcome, particularly where it describes
someone else's project. · Author: bpappin · revised 2026-08-05

> **What changed.** v1 (2026-08-02) proposed bundling skills inside the
> jar and announcing them with a `MANIFEST.MF` attribute. v2 kept that as
> a fallback beside a published sidecar artifact. **v3 drops in-archive
> bundling entirely** - supporting a mechanism we had just measured as
> broken on Android was incoherent - and adds the part that actually
> matters at scale: how an agent picks the right skill out of hundreds.
> "What we tried" records the whole path, failures included, because the
> failures are the argument.

## The gap

Every current effort to let a library ship an agent skill assumes the
consumer can *see* the files. npm, SPM, Cargo, Go, and NuGet all unpack
dependencies onto disk, so a directory convention works: scan
`node_modules/*/`, find `.agents/skills/<name>/SKILL.md`, done.

The JVM does not unpack. A Gradle or Maven dependency is an archive
sitting in `~/.gradle/caches/modules-2/files-2.1/...` or
`~/.m2/repository/...`. Nothing in the resolved dependency graph is
browsable, so an agent working in a Kotlin, Java, Android, or KMP project
cannot discover a bundled skill at all - no matter which directory
convention the library followed.

This is not a niche. It is Android, all of KMP, and the whole JVM server
ecosystem.

## What already exists, and why it does not cover this

- The [Agent Skills spec](https://github.com/agentskills/agentskills)
  defines what a skill *is* (`SKILL.md` + optional `scripts/`,
  `references/`, `assets/`) but not where a package puts one.
- [library-skills.io](https://library-skills.io/create/) uses
  `.agents/skills/<name>/SKILL.md` inside the installed package, and a
  CLI that symlinks from the unpacked dependency tree. Python and
  JS/TS only.
- [mise #9479](https://github.com/jdx/mise/discussions/9479) and
  [Vercel's skills CLI](https://github.com/vercel-labs/skills) use a
  plain `skills/<name>/SKILL.md`.
- [pnpm RFC #13422](https://github.com/orgs/pnpm/discussions/13422)
  observes that the existing directory conventions each "put an adoption
  step in front of the discovery mechanism", and proposes addressing
  discovery at the package-manager level instead.

All of these assume an unpacked tree. The pnpm point is the one I find
most persuasive, and this document is an attempt to answer it for a
package manager that will never unpack anything.

## What we tried

Three iterations. Each failed in a way that pointed at the next.

### v1 - a bespoke flat file

The first shape was a single file per module,
`.ai-skills/<id>.ai-skill.md`, with `META-INF/ai-skills/` as the JVM
variant. It was written before the Agent Skills spec had settled, and it
was wrong in a way that took a while to see: **it was not a skill.** It
was a markdown file with a suggestive name and a private convention
around it. Any agent that understood skills - which is to say, any agent
that looks for a directory containing `SKILL.md` - walked straight past
it. The only software that could read a v1 file was software written
specifically to read v1 files, which defeats the purpose of shipping one
at all. It also carried a bespoke `skill-id` frontmatter key where the
spec wants `name`, so even a tool that found the file could not identify
it consistently.

The lesson generalises past this one mistake: **a bundled artifact is
only useful if it is the same thing the ecosystem already knows how to
load.** Inventing a container format alongside a perfectly good one buys
nothing and costs a migration. (Ours needed exactly that; the tooling now
ships a migration script for it.)

### v2 - the canonical path, and a manifest attribute

v2 moved to a real Agent Skill directory at
`META-INF/agents/skills/<name>/SKILL.md` and added the
`Agent-Skills: META-INF/agents/skills/` manifest attribute so that
discovery would be an O(1) read of a well-known entry rather than a
pattern-match over an archive.

That part works, and works well, **for jars.** A jar storing its skill at
a deliberately non-standard path was discovered correctly purely from its
manifest declaration. If the JVM were only jars, this document would end
here.

### Where it hit the wall: Android and native

Open question 5 in v1 of this document asked whether the same attribute
and path work unchanged inside an AAR. Measured answer: **no, on three
separate counts.**

- **The manifest attribute cannot reach an AAR.** The Android Gradle
  Plugin's default packaging rules exclude `/META-INF/MANIFEST.MF` and
  `/META-INF/**/MANIFEST.MF` from the nested `classes.jar`, and an AAR
  has no manifest of its own. There is nowhere to put the declaration.
- **On AGP 8, a KMP library's skill is not in the AAR at all.**
  `src/commonMain/resources/` is silently dropped from the Android
  artifact - the JVM jar has the file, the AAR does not, and nothing
  warns. This is
  [KT-46493](https://youtrack.jetbrains.com/issue/KT-46493), open since
  2021. It is fixable with a one-line source-set wiring, or by moving to
  AGP 9's `com.android.kotlin.multiplatform.library` plugin, but a
  convention that depends on every publisher knowing a workaround to an
  open five-year-old bug is not a convention.
- **Kotlin/Native ships nothing.** `commonMain` resources are not
  packaged into klibs at all. Compose Multiplatform works around this
  with a separate `kotlin_resources.zip` artifact - which is, in effect,
  the mechanism proposed below, arrived at independently for the same
  reason.

None of this per-target behaviour is documented by JetBrains or Google.
It was established by building libraries and unzipping the output. That
is itself a finding: **a packaging convention that can only be verified
empirically is not one a spec can safely lean on.**

## Proposal

### 1. Publish the skill as a repository artifact

```
<artifact>-<version>-skills.zip
```

A classified artifact attached to the library's existing coordinates,
containing one or more `<name>/SKILL.md` trees. On a KMP library it hangs
off the **root** module - the skill is platform-independent, so
per-target copies would be N identical files and would force a consumer
to know a target name.

This is not a new mechanism. It is how `-sources` and `-javadoc` have
always worked, and there is direct precedent for non-code metadata at the
same coordinates: every KMP library on Central already publishes
`<artifact>-<version>-kotlin-tooling-metadata.json` by exactly this
route. Central accepts arbitrary classifiers and extensions - the
existence proof is Compose Multiplatform's
`…-kotlin_resources.kotlin_resources.zip`, underscores and dotted
extension included.

What it buys, all of it a direct answer to a failure above:

- **One artifact for every platform.** No AAR nesting, no AGP resource
  wiring, no klib gap, no per-target divergence. The packaging problem
  disappears rather than being worked around.
- **Fetchable without the library.** A plain HTTPS GET, or
  `mvn dependency:get -Dartifact=g:a:v:zip:skills -Dtransitive=false`,
  retrieves the skill and nothing else - not the jar, not the transitive
  graph. This answers "does the library I am *considering* ship a skill?"
  which bundling structurally cannot.
- **No archive scanning at all.** The consumer never opens a jar, never
  opens an AAR, never reads a nested `classes.jar`.

Build-side cost, Gradle:

```kotlin
val skillZip = tasks.register<Zip>("skillZip") {
    archiveClassifier.set("skills")
    from("src/agentSkills")
}
publishing.publications.withType<MavenPublication>().configureEach {
    // on KMP, guard with: if (name == "kotlinMultiplatform")
    artifact(skillZip)
}
```

### 2. Declare it in Gradle Module Metadata where possible

A classifier artifact is discoverable only by constructing its URL -
nothing in the POM or `maven-metadata.xml` records that it exists. Gradle
Module Metadata does record it, as a variant with explicit filenames and
checksums, which is exactly how Gradle consumers fetch sources today
without probing for them.

```kotlin
val skillsElements by configurations.creating {
    isCanBeResolved = false; isCanBeConsumed = true
    attributes { attribute(Usage.USAGE_ATTRIBUTE, objects.named(Usage::class, "ai-skill")) }
    outgoing.capability("$group:$name-skills:$version")
    outgoing.artifact(skillZip)
    // declare NO dependencies - see below
}
(components["java"] as AdhocComponentWithVariants)
    .addVariantsFromConfiguration(skillsElements) { mapToOptional() }
```

Two things learned the hard way. The variant must declare **no
dependencies** - Compose Multiplatform's resources variant declares
three, and requesting it transitively fails because Gradle then looks for
a matching variant of `kotlin-stdlib`, which does not exist. And the
capability must be set **explicitly**; Gradle derives it from the project
name rather than the artifactId, which is
[gradle/gradle#16577](https://github.com/gradle/gradle/issues/16577).

**Known blocker:** this does not currently work on a KMP root module.
`addVariantsFromConfiguration` throws, because
`KotlinSoftwareComponentWithCoordinatesAndPublication` is not an
`AdhocComponentWithVariants`. Compose Multiplatform achieves its
per-target resource variants through Kotlin-plugin internals rather than
a public extension point. **On KMP you get the classifier artifact but
not the variant declaration.** If someone knows the supported route here,
that is the single most useful correction this document could receive.

### 3. Nothing reads the archive

No jar scanning, no AAR scanning, no manifest attribute. Supporting a
mechanism while telling publishers it does not work on Android is
incoherent, there is no installed base to stay compatible with, and
scanning is where all the cost lived - one real cache held 7,462 jars and
555 AARs, each of which would be opened to look for a file that is almost
never there.

The consequence lands on the publisher and is the best argument for it:
**if nothing reads the archive, the skill never has to be a packaged
resource.** It is a directory a Zip task reads.

```
src/agentSkills/<name>/SKILL.md
```

No resource semantics, no per-target packaging behaviour, and the entire
KT-46493 problem disappears for publishers as well as consumers. Inside
the zip the layout is flat - `<name>/SKILL.md` - because `META-INF/` only
ever meant "classpath resource" and it is not one now.

Stated cost: a consumer without tooling has no path at all. Given that
the discovery mechanism *is* the tooling, that is not much of a loss.

### 4. The part that actually matters: choosing among hundreds

Everything above is packaging, and packaging is the easy half. A project
has hundreds of dependencies. Agent skills keep name and description
permanently in context - roughly 100 tokens each - so 300 dependencies
shipping skills is ~30,000 tokens before any work starts. **One skill per
library does not scale**, and paths carry no meaning:
`io.github.aughtone.types/` tells an agent nothing about whether it
handles money or dates.

So: two layers. One small always-present entry whose only job is to
**trigger at the right moment**, and a linked, on-demand **codex** that
maps a need to a library and a path. That shape is not speculative - the
MCP specification documents it as Catalog / Inspect / Execute, Anthropic
and OpenAI both ship deferred tool loading behind a search, and llms.txt
splits index from full text.

Two measurements worth knowing. Deferring behind an index cut context
~85% **and raised** selection accuracy from 49% to 74% - fewer candidates
makes the choice better, so this is not a budget compromise. And across
2,400 agent tasks on documentation sites, *linking* to an index reduced
wrong-path errors as much as inlining it, at a fraction of the tokens.

**Overlap is the domain, not a defect.** The literature treats
semantically overlapping entries as a quality problem to clean up. A real
dependency graph has three HTTP clients and two date libraries because
that is what dependency graphs are. So the valuable index entry is not
"this library does X" but "several of these do X, we reach for that one,
here is why not the others" - and that last part **cannot be harvested**,
because no library knows what else is on your classpath. It is local
knowledge, and it is the part that saves anyone time.

Which makes mis-selection the common case rather than the tail, and
recovery a design surface: name the alternatives inside the entry an
agent lands on, carry negative guidance ("do not use X for Y"), and have
skills instruct the consuming agent to state which one it used - so a
human sees the wrong turn as it happens.

### 5. What a library skill should contain

Discovery is worthless if the bodies do not say what they cover, and this
is unclaimed ground: the spec requires only `name` and `description`, has
no capability or tag field, and library-skills.io explicitly declines to
prescribe content. **Someone should specify this, and it is arguably more
important than the packaging argument above.**

A library skill should carry: a `description` stating what it is for
*and when a caller should reach for it instead of writing their own*;
capabilities in the words a caller would use for the problem, not the
words the API uses ("retry with backoff", not "resilience policies");
the two or three intended usage patterns; the invariants and traps that
look reasonable but are wrong here; **what it is not for**, which is the
field most often missing and the one that makes an entry discriminative
when three libraries overlap; and provenance - repository, canonical
skill URL, resolved version.

What library authors should **not** be asked to do is classify themselves
into a shared capability taxonomy. schema.org's own retrospective gives
the rule - where publishers vastly outnumber consumers, the complexity
belongs with the consumers - and the graveyard is well populated: UDDI,
semantic web service discovery, npm keywords as a quality signal.
Authors write prose; indexers normalise.

## Finding out a sidecar exists

Four routes, measured:

| Route | Verdict |
|---|---|
| Gradle Module Metadata variant | **Best.** Zero probing, exact filenames and checksums. Gradle publishers and consumers only; blocked on KMP roots (above). |
| Consumer declares the sidecar as a dependency | **Best in practice.** Gradle fetches it into the local cache, and discovery becomes local scanning again - no network at query time, works offline. Costs the consumer one configuration block, once. |
| Repository directory listing | Works on Maven Central, CDN-cached, returns the complete file set in one request - strictly cheaper than probing. But undocumented, and **404s on Google Maven**, where roughly half an Android graph lives. |
| 404-probe per coordinate | **Reject.** ~148s for a 374-dependency graph; misses bypass the CDN and hit origin. This is precisely the traffic pattern Sonatype's 2025 consumption limits target. |

One route that looks perfect and is not: `search.maven.org/solrsearch`
with `core=gav` returns the exact published file list in its `ec` field
and batches ~20 coordinates per request. But the index is roughly two
months stale - `guava:33.6.0-jre` returns `numFound=0` while the jar is
live on `repo1`. Since a skill ships with a *new* release, that is
disqualifying for the case that matters.

The prior art all points the same way. Every ecosystem that solved this
shape of problem used repository metadata: npm has the packument and a
dedicated attestations endpoint and never probes; Gradle has Module
Metadata. Every mechanism built on convention-plus-probe produced
inconsistent conventions and 404 traffic - CycloneDX and SPDX cannot even
agree on whether their sidecar is a classifier or an extension, and
sigstore needs the Rekor transparency log to serve as the index its
naming convention does not provide.

**The recommendation follows from that:** declare it in metadata where
metadata exists, let consumers pull sidecars into their cache so
discovery stays local, and treat probing as a fallback of last resort
with mandatory negative caching.

## Reference implementation

Working, tested, MIT, in the `to-library-skill` skill of the story-tools
suite:

- `scripts/metainf-scaffold.sh` - creates the skill at the canonical
  path, prints the manifest snippet, and warns about the AGP 8 resource
  gap.
- `scripts/harvest-dependency-skills.sh` - resolves skills from
  dependencies across npm, SPM, Python, Go, Cargo, NuGet, and the JVM.
  Its JVM archive-scanning is the mechanism this document now argues
  against; it stands as the evidence for why.
- `scripts/index-library-skills.sh` - indexes skills bundled in a
  multi-module repo, flagging any still on the v1 layout.
- `scripts/migrate-library-skills.sh` - migrates v1 flat files to the
  standard directory layout.

Sidecar publication and the codex are **not yet implemented** - they are
proposed here first because the packaging findings above changed what
should be built. The intended delivery is a Gradle plugin rather than
scripts, because a plugin gets the *resolved dependency graph* and lets
Gradle handle variant selection, repository selection and checksums,
which removes every guess a script has to make.

## Open questions

1. **Classifier and extension.** `-skills.zip` reads plainly and matches
   the `-sources` precedent. Alternatives: `-agent-skills.zip`,
   `.skills.zip`.
2. **The KMP root-module variant blocker.** Is there a supported public
   API? (Section 2.)
3. **Attribute or capability for the GMM variant?** Test fixtures use a
   capability and identical attributes; Compose Multiplatform uses a
   bespoke `org.gradle.usage` value and no capability. Both work; the
   ecosystem should pick one.
4. **Should discovery be centralised?** A batch coordinate→skill index
   would solve Google Maven, staleness, and multi-repository coverage in
   one move. It also means someone has to run it, and it is the kind of
   thing better proposed after the publishing convention settles.
5. **Should a library-skill content spec live in the Agent Skills spec**,
   or be demonstrated rather than legislated? The spec is currently
   silent, and the index is only as good as the prose it is built from.
6. **Where should a JVM packaging convention be documented** - in the
   spec, or a companion? The spec is currently silent on packaging for
   every ecosystem, not just this one.

## What I am asking for

Three things. Feedback on the sidecar as the mechanism. An answer to the
KMP root-module variant blocker, if anyone has one - it is the only piece
of this that is currently stuck. And a view on whether library-skill
*content* should be specified at all, because the packaging argument is
the easy half and the field is currently spending all its attention
there.
