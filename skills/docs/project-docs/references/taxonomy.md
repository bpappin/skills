# Filing Conventions

Structure is not prescribed - it is whatever the knowledge base shows,
arranged by humans in YouTrack, mirrored down by the sync. What follows
are conventions and starting points, not a required tree.

## Repo layout around the mirror

```
docs/
├── README.md       Git-native front door - explains this system (never synced)
├── knowledge/      THE MIRROR - two-way sync domain, whole project KB
│   └── .yt-sync/       sync state + merge bases (commit; never hand-edit)
├── stories/        GENERATED issue snapshot (story-reconcile) - never synced
├── outbox/         Outbound artifacts (third-party bug reports, letters) -
│                   written FOR someone else, not project knowledge
└── _archive/       Retired files - kept out of the mirror on purpose
```

Pure agent instructions stay at the repo root (`AGENTS.md`,
`WIRING.md`). Indexes and doc-system notes the agent maintains live at
the `docs/` root. None of that syncs.

## Suggested starting sections

Sections are just top-level articles; create the ones the project needs
and let the owners rearrange freely. Names are spelled out for humans -
"Architecture Decision Records", never "adr"; "Quality Assurance",
never "QA"; accessibility (AX) belongs with Design.

| Section | What belongs there |
|---|---|
| Architecture Decision Records | One hard-to-reverse choice each; append-only history |
| Product Requirements | PRD narratives + Stories tables of tracker IDs (never AC) |
| Specifications | How a thing IS - architecture, component specs; update in place |
| Design & Accessibility | Mockups, feature designs, AX direction |
| Research | Investigations - question, trail, findings |
| Reference | External facts: vendors, prospects, regulations, domain material - and the **Domain Glossary** (the project's canonical terms; `AGENTS.md` at the repo root points at it so agents find it without a path) |
| Developer Guides | How-to - onboarding, environment, CI |
| Quality Assurance | Durable test plans and protocols (QA *runs* are issues) |
| Mandates & Compliance | Legal/regulatory rules the work must satisfy |
| Support | Support knowledge, runbooks, customer-facing material |

Every section directory's `README.md` is the section article's body:
one or two sentences on what lives there and who reads it, so both KB
readers and filing agents get the same guidance. Write one whenever you
create a section.

**Subsystems (monorepos):** split WITHIN a section by subsystem
subdirectory, named exactly after the project's Subsystem field values
("CMS Server" → a "CMS Server" child article), lazily - only where a
system actually has documents. The KB then reads "Architecture Decision
Records → CMS Server" and the board field uses the same vocabulary.

## Distinctions that matter

- **spec vs adr**: a spec describes how a thing IS; an ADR records why a
  choice was made. Specs update in place; ADRs are append-only.
- **research vs reference**: research is your investigation (trail and
  conclusion); reference is someone else's facts kept close.
- **vendors vs prospects** (both under Reference): a vendor you use or
  integrate today; a prospect you may approach - the dossier is
  knowledge, the act of reaching out is an issue. Prospects graduate to
  vendors when they become active.
- **Quality Assurance vs story QA**: per-story Gherkin lives in the
  story's `## QA` section; the KB section holds what spans stories.
- **Mandate vs procedure**: the rule ("PIPEDA requires consent") and the
  project's response ("how we check for it") are separate documents that
  cite each other. Both live in the KB; they just sit in different
  sections with different audiences.

## No status frontmatter

Docs carry at most `title`/`date` frontmatter. `id:`, `status:`,
`type:`, `parent:` blocks are retired - that state lives in the
tracker, and syncing it is what caused drift in the legacy system.

## Adopting over a legacy docs tree

1. Decide the section layout in YouTrack (create the top-level articles,
   or accept the suggestions above).
2. Move legacy knowledge files into `docs/knowledge/` under the matching
   section directories, then run the first sync with `--force` - each
   file is adopted and pushed up as a new article. (Alternatively:
   paste content into YouTrack by hand and let a clean first sync pull
   everything down.)
3. Work-tracking legacy docs (`ac/`, `gap/`, statused QA runs,
   handoffs) are NOT knowledge - hand those to the story-reconcile
   skill; that migration has its own approval gate.
4. Strip any `<!-- GENERATED -->` banners left over from the retired
   one-way publisher; the sync then pushes the clean copies up.
