# The Eight-Home Taxonomy

Repo layout (plus root `DESIGN.md` per the Google DESIGN.md spec):

```
docs/
├── product/        GENERATED - mirror of the KB's Product Management zone
│                   (appears at first graduation; never edited, never published)
├── development/    Git-canonical - what the dev side decides and builds:
│   ├── adr/            Decisions - one hard-to-reverse choice each
│   ├── prd/            Requirements - narrative + Stories table of YouTrack IDs
│   ├── spec/           Standing specs - architecture, mandates, component specs
│   ├── design/         Mockups, feature designs, accessibility (AX); icon/ assets
│   ├── research/       Investigations - question, trail, findings
│   ├── reference/      External facts: vendors/, prospects/, regulations/, domain
│   ├── guides/         How-to - onboarding, environment, CI, developer guides
│   └── qa/             Quality Assurance - durable test plans, protocols
├── stories/        GENERATED - tracker snapshot from yt-pull (was docs/youtrack/)
├── outbox/         Outbound artifacts - never published to the KB
└── _archive/       Retired files (reconcile moves GAP-era docs here) - never published
```

**`outbox/`** holds things written FOR someone else: a bug report filed
against a third-party library, correspondence, a proposal draft sent out.
It exists so those artifacts have a home in the repo, but it is not
project knowledge - the publisher always skips it.

## Ownership and graduation

**Rules flow in; decisions flow out.** The knowledge base has two
top-level zones named for who they serve:

- **Product Management** (KB-canonical) - what informs the work: Mandates
  & Compliance, BSA documents, Support, Design Studio, Translations.
  Authored freely in the tracker by their owners.
- **Product Development** (git-canonical) - what was decided and built:
  the generated, read-only mirror of `docs/development/`.

**Cross-zone references are normal and encouraged** - the zones share a
knowledge graph, not a wall. A development doc on how to verify HIPAA
compliance cites the HIPAA mandate it implements; a PM article may point
at the Product Development mirror article for the spec it constrains.
Conventions: development docs cite PM material by its KB article URL
(stable) and, once the pull exists, the `docs/product/...` snapshot path
alongside it (agent-friendly); PM articles cite development docs by their
mirror-article URL. A link never transfers ownership - you edit what your
side owns and follow links for the rest.

Documents may be AUTHORED from either side - a developer can create a
doc destined for Product Management (it's created as an article there,
canonical from birth, and reaches the repo via the `docs/product/` pull),
and KB-side authors drop repo-destined drafts in a **For Development**
section that agents import into `docs/development/` (then remove the
draft). One-time hand-offs at birth; never a second writable copy.

The short lowercase names (`product/`, `development/`, `stories/`) exist
ONLY in the repo tree. The knowledge base always shows the full names:
the publisher titles its root "Product Development" (keep
`docs/development/README.md`'s H1 saying so - it overrides), and the
Product Management section is created under that exact name.

Every area has exactly ONE writable home: the tool of its current author.

- **Solo mode (default):** one developer wearing all hats = everything is
  git-canonical, exactly this taxonomy. Drop a mandate into
  `reference/mandates/` and tell the agent to take it into account -
  no ceremony.
- **Graduation:** when a person who doesn't use the repo becomes the real
  author of an area (legal owns mandates, a designer owns design
  direction, translators own translations), that area graduates: its
  content moves to a section under Product Management (one-time,
  approval-gated), the KB becomes canonical for it, and
  `docs/product/<area>/` appears as a GENERATED read-only
  snapshot - the repo-side mirror of the Product Management zone - so
  agents keep the material in context. Areas graduate independently,
  only when a real owner exists.
- `docs/product/` follows the same rule as `docs/stories/`:
  generated, never edited locally, never published back; refreshed by
  pull. Repo-side docs cite KB-owned material; the response to a rule
  (e.g. a compliance mapping with status) is a dev doc in git even when
  the rule itself is KB-owned.
- Human-facing section names are spelled out: "Quality Assurance", not
  "QA"; accessibility (AX) belongs to Design.

## Subsystems (monorepos)

When one repo holds several systems, split WITHIN each home by subsystem
subdirectory - `docs/development/adr/cms-server/`, `docs/development/guides/android-client/` - so
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
  section. `docs/development/qa/` holds what spans stories: regression plans, manual
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
