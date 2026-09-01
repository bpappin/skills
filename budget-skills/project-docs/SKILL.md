---
name: project-docs
description: Decide where a document belongs in a repo's docs/ tree, name it so it is findable, and keep the sections coherent as the tree grows. Filing only - no publishing, no sync, no tracker. Use when placing a new document, creating a section, or tidying a docs tree that has drifted. Triggers - "where should this go", "file this", "what section", "our docs are a mess".
license: MIT
compatibility: Standalone. Filing conventions only - no network, no scripts, no tracker.
metadata:
  author: bpappin
  version: "1.1"
---

# Project Docs

Where a document belongs, and what to call it. This skill owns filing and nothing else - the authoring of each document type has its own skill (`to-adr`, `to-prd`, `to-rad`, `to-wiring`).

There is no publishing step here and no sync. A document is filed when it is in the right directory with the right name, and that is the whole of it.

## Filing a document

Ask what the document *is*, not what prompted it. The same conversation can produce a decision, an investigation and a requirement, and they file in three different places.

- It records **one hard-to-reverse choice** and what was rejected → `decisions/`
- It works a question toward a recommendation, and nothing is settled → `research/`
- It states **what must be built** and how anyone would know it works → `requirements/`
- It describes **how a thing IS**, and gets updated in place → `specifications/`
- It is an external fact the project must live with → `reference/`
- It tells someone **how to do** something → `guides/`

If two fit, the document is probably two documents. Split it rather than filing a hybrid nobody can find.

## Sections

| Directory | What belongs there |
|---|---|
| `decisions/` | Architecture decision records. One hard-to-reverse choice each; append-only history |
| `requirements/` | PRD narratives and the stories that implement them |
| `specifications/` | How a thing IS - architecture, component specs; updated in place |
| `research/` | Investigations - question, trail, findings. Postmortems and worked case studies belong here |
| `reference/` | External facts: vendors, regulations, domain material - and the **Domain Glossary**, the project's canonical terms |
| `guides/` | How-to - onboarding, environment, CI |
| `testing/` | Durable test plans and protocols |
| `compliance/` | Legal and regulatory rules the work must satisfy |
| `documents/` | Informational pages explaining what the project is and how the pieces relate. Also the honest home for something that fits nothing else |

**These are starting points, not a required tree.** Match what the project already has rather than renaming its directories to fit this table. A project with three documents needs two directories, not nine - add a section when something has nowhere honest to go, never in advance.

**Point `AGENTS.md` at the glossary.** If the project has a domain glossary, name its path in `AGENTS.md` at the repo root. Agents read root files reliably and find nothing else without a path.

## Naming

**Never put spaces or title case in a path.** Lowercase, hyphenated, and stable: `session-scoping.md`, not `Session Scoping.md`.

**Anything that gets cited carries an ID.** The name is `TYPE-NNNN-short-slug.md` - `ADR-0004-session-scoping.md`, `PRD-0003-draft-visibility.md`, `RAD-0023-signal-enrichment.md`, `STY-0042-drafts-are-private.md`.

**The number is an identifier, not a position in a sequence.** It says *which document this is*, not where it falls in an order - so it carries no claim that the document is append-only, finished, or superseded by a higher number. That distinction is what lets a living document have one: a PRD gets corrected in place for a year and keeps `PRD-0003` throughout, because the ID names the document rather than a version of it.

**`ADR-0004` is the handle people cite** - in a commit message, in a code comment, in a conversation, in another document's References - and it has to work with no directory in front of it. A bare `0004` does not: there is a story 4 and a decision 4 and they get cited in the same sentence. Zero-pad so the files sort. Assign the next unused number for that type, and **never reissue one**: an ID that has been cited belongs to that document permanently, including after the document is superseded, abandoned or deleted.

| Prefix | For | Written by |
|---|---|---|
| `ADR-` | Decisions | `to-adr` |
| `PRD-` | Requirements | `to-prd` |
| `RAD-` | Research logs | `to-rad` |
| `STY-` | Stories | `to-stories` |

**A project that keeps another cited document type gives it a prefix too** - `SPC-` for specifications is the usual next one. The test is whether anything ever needs to point at it: if a story, a brief or a code comment will name it, it needs an ID, and adding the prefix later means every existing reference to it is wrong.

**Date nothing.** A specification is a living document; a date in its name guarantees it looks stale while being current, and guarantees a second copy the first time someone updates it.

**Give every document an H1 that matches what it is.** The filename is how it is found; the H1 is how a reader knows they found the right thing.

## Creating a document

Read the section before writing into it. Match the numbering, the naming and the shape of what is already there - a document that follows a different convention than its five neighbours is harder to find than one filed slightly wrong.

If the section does not exist yet, creating a **new top-level directory is a person's call, not an agent's.** It claims the project has a kind of knowledge it did not have before. Sub-groups inside an existing section are free - they inherit their parent's meaning and assert nothing new - but subdivide only when a section has actually grown enough to need it, which is uncommon and never on the first document of a kind.

## There is no design section

Design splits three ways and none of them is a knowledge document:

- **`DESIGN.md` at the repo root** - the design *system*: tokens, components, the rationale and the do's and don'ts. It sits beside `AGENTS.md` because it is agent-facing wiring.
- **`docs/design/`** - design *records*: a decision about a particular screen or flow, with mockups attached. Mostly not prose, and it is the working pile rather than the thing someone looks up.
- **A decision that happens to be about design** files in `decisions/` like any other.

## No status frontmatter

Do not put `status: draft` or `status: approved` in a document. It is always wrong within a week, nobody updates it, and a reader who trusts it is misled by something the repo itself contradicts. If a document is provisional, say so in its own words in the opening paragraph, where a reader will actually see it.

## Adopting over a legacy tree

Do not reorganise a docs tree as an opening move. Read what is there, work out what the existing convention *is* - there usually is one, even if unstated - and write it down. File new documents to that convention.

Move something only when it is actually misfiled, and move it on its own rather than as part of a sweep. A large reorganisation breaks every link pointing into the tree, and links are the thing nobody checks. When you do move a file, grep for its old path and fix what pointed at it - in the same change, not as a follow-up.
