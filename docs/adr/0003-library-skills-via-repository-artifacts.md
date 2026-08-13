# ADR-0003: Library agent-skills ship as repository artifacts (moved)

Date: 2026-08-05 · Moved: 2026-08-12 · Status: superseded by relocation

This decision moved to the project it is about:

**`dependencyskills/dependencyskills` → `docs/adr/0003-library-skills-via-repository-artifacts.md`**

It decides how a library's agent skill travels — published as a classified
repository artifact declared through Gradle Module Metadata, rather than
bundled inside the jar — and records the two approaches abandoned before
it, including the measured Android and native packaging failures.

Nothing here superseded it; it simply belongs with the implementation
rather than with story-tools, which was only ever its birthplace. See
ADR-0005 in that repository for why the project is laid out as it is.
