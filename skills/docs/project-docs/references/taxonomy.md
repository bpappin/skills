# The Eight-Home Taxonomy

Repo layout (plus root `DESIGN.md` per the Google DESIGN.md spec):

```
docs/
├── adr/            Decisions - one hard-to-reverse choice each; links research
├── prd/            Requirements - narrative + Stories table of YouTrack IDs
├── spec/           Standing specs - architecture, product mandates, component specs
├── design/         Mockups, feature designs, briefs; icon/ and visual assets
├── research/       Investigations - question, trail, findings (DD + RAD merged)
├── reference/      External facts: vendors/, prospects/, regulations/, domain
├── guides/         How-to - onboarding, environment, CI, developer guides
├── qa/             Durable test plans, protocols, test-user rosters
├── outbox/         Outbound artifacts - never published to the KB
└── youtrack/       GENERATED snapshot from yt-pull - never hand-edited, never published
```

**`outbox/`** holds things written FOR someone else: a bug report filed
against a third-party library, correspondence, a proposal draft sent out.
It exists so those artifacts have a home in the repo, but it is not
project knowledge - the publisher always skips it.

## Subsystems (monorepos)

When one repo holds several systems, split WITHIN each home by subsystem
subdirectory - `docs/adr/cms-server/`, `docs/guides/android-client/` - so
the knowledge base reads "Architecture Decision Records → CMS Server"
instead of jumbling every system together. Rules:

- Create subsystem folders lazily, only in homes where a system actually
  has documents; cross-cutting docs stay at the home's root.
- Name folders after the project's Subsystem field values ("CMS Server" →
  `cms-server/`), and give each a README.md whose H1 matches the field
  value exactly - the KB section and the board field then use the same
  vocabulary.
- Cross-cutting concerns that are Subsystem values (Transport,
  Offline-first) get folders the same way when they accumulate docs.

## The filing rule

1. Tracks work (status, done-ness, task list)? → YouTrack issue, not a file.
2. Otherwise: decision / requirement / standing spec / picture /
   investigation / external fact / how-to / test protocol → the matching
   home above.

And the mirror rule: **the whole tree syncs to YouTrack** - knowledge
publishes to hierarchical knowledge-base articles (`scripts/yt-publish.sh`,
one-way), work lives as issues. Nothing exists only in someone's head or
only on the server.

Distinctions that matter:

- **vendors vs prospects** (both under `reference/`): a vendor is something
  you currently use or integrate (OSM, HMDB) → `reference/vendors/`. A
  prospect is an organization you may approach for collaboration - a
  source you don't want to forget → `reference/prospects/`. The dossier is
  knowledge; the act of reaching out is an issue. When a prospect becomes
  active, its technical material graduates to `vendors/`.
- **spec vs adr**: a spec describes how a thing IS; an ADR records why a
  choice was made. Specs update in place; ADRs are append-only history.
- **research vs reference**: research is your investigation (has a trail
  and a conclusion); reference is someone else's facts you keep locally.
- **qa/ vs story QA**: per-story Gherkin lives in the story's `## QA`
  section. `docs/qa/` holds what spans stories: regression plans, manual
  protocols, test users. QA *runs* are records → YouTrack.

## No status frontmatter

Repo docs carry at most `title`/`date` frontmatter. `id: #NEW`,
`status: WIP`, `type:`, `parent:` blocks are retired - that state now
lives in YouTrack and syncing it is what caused drift.

## Migration map (legacy 15-sector → eight homes)

| Legacy | Goes to |
|---|---|
| `ac/`, `gap/` | YouTrack stories - use the story-reconcile skill (approval-gated) |
| `mandates/`, `architecture/`, `plans/`, `spec/` | `spec/` (work-roadmap "plans" → YouTrack epics, judge per file) |
| `design/`, `icon/` | `design/` (icon as subfolder) |
| `discovery/`, `research/` | `research/` |
| `vendors/`, `regulations/`, `reference/` | `reference/` (vendors/, regulations/ subfolders) |
| `partnerships/` | `reference/prospects/` - they're approach-candidates, not active partners |
| `developer/`, `guides/` | `guides/` |
| `testing/` | `qa/` (runs → YouTrack going forward) |
| `handoff/` | Retire - handoffs become comments on the focused story |
| `outbox/` | Working scratch, outside the taxonomy - leave or archive |
| `mandates/templates/` | Templates ship inside skills, not repos |
