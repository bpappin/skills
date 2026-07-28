# How This Documentation Works

<!-- This is docs/README.md - the front door of the documentation system.
     It publishes to the knowledge base as a top-level article beside
     Product Development and Product Management. Adapt the placeholders
     to the project; keep it readable by someone on their first day. -->

Everything about this project lives in one of three places, and each
thing lives in exactly **one** of them. That single rule is the whole
system - everything below is just its consequences.

## The three places

**The issue tracker** owns *work*: stories, bugs, ideas, anything with a
status that will someday be "done". If it tracks progress, it is an
issue - never a document.

**Product Management** (a knowledge-base section) owns *what informs the
work*: legal mandates, business requirements, support knowledge, design
direction, translations. Written and organized by the people who own
those things, directly in the knowledge base - no repository access
needed.

**Product Development** (the repository's `docs/` tree, mirrored here in
the knowledge base) owns *what was decided and built*: architecture
decisions, specifications, research, developer guides, test plans.
Written by developers and their agents alongside the code it describes.

The boundary between the last two is **what vs how**: a rule about what
must be true (a HIPAA mandate) is Product Management; the procedure for
how this project satisfies it is Product Development. The two link to
each other freely - following a link is always fine, editing is only
done on the side that owns the document.

## Why it works this way

Every copy of a fact eventually disagrees with the original - that is
how documentation dies. So this system allows exactly one writable home
per document and generates every other view of it. Articles marked
**Generated** (the banner at the top) are views: editing them does
nothing durable, because the next publish restores the original. Edit
the real one - the banner tells you where it lives - or ask, and someone
will move the change to the right place.

## Adding a document

- **You work in the knowledge base** (analyst, designer, support,
  translator): create it in the right Product Management section. If it
  really belongs to the development side - definitions, technical
  material - put it in **For Development**, and it will be filed into
  the repository properly (the draft is then removed; the published
  copy replaces it).
- **You work in the repository**: file it under `docs/development/` per
  the taxonomy (`adr/` for decisions, `spec/` for standing specs,
  `reference/` for external facts, `guides/` for how-tos ...). If it
  belongs to Product Management - a new mandate, business material -
  it is created as an article there instead, and returns to the
  repository as a read-only copy under `docs/product/`.
- **It's work, not knowledge**: it is an issue. Say "record this for
  later" to any agent and it lands in the backlog for triage.

## The map

| You are looking at | It is | Edit it? |
|---|---|---|
| An issue / story | The work itself | Yes - the tracker owns work |
| A Product Management article | Source material | Yes, if your team owns that section |
| A Product Development article | Generated mirror of the repo | No - edit the repo file (or ask) |
| `docs/development/...` in the repo | The source of the mirror | Yes - developers and agents |
| `docs/product/...` or `docs/stories/...` in the repo | Generated snapshots | No - they refresh by pull |

Questions about where something goes: <!-- name the owner/channel -->.
