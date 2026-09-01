---
name: to-adr
description: Record a decision as an Architecture Decision Record - the forces, the choice, what was rejected and why. Use the moment a hard-to-reverse choice is made, not later - a library or technology picked over alternatives, an approach settled after weighing trade-offs, a constraint accepted, an earlier decision superseded, or an approach abandoned after it failed. Triggers - "we decided", "we're going with", "let's use X instead of Y", "chose X over Y", "record this decision", "new ADR", "document this trade-off", "why did we do it this way", "supersede that decision", "that approach didn't work".
license: MIT
compatibility: Standalone. Writes an ADR file into the repo; no network, no scripts, no tracker.
metadata:
  author: bpappin
  version: "1.1"
---

# Architecture Decision Records (to-adr)

An ADR captures **why** a choice was made, so the next person - or the next
agent - does not relitigate it, and can tell when the reasons have expired.

This skill is the authoring workflow. If the project-docs skill is also
present it owns where the file goes; if it is not, the step below works it
out from what the repo already does.


> **An ADR is a technical decision, not a capture.** If you are recording
> something you noticed rather than making the call, write it up as a story
> (`to-stories`) instead. Nobody should be pushed into writing one because
> the story they picked up turned out to be thin.

**You own the technical decisions even when you do not own the requirements.** Where an architect or a business analyst hands you a PRD that is already agreed, the choices inside the implementation are still yours - which library, which boundary, which failure mode you decided to accept, what you deliberately did not build. Those are exactly the decisions nobody writes down in that arrangement, because the requirements were someone else's and it feels as though the decisions were too. They were not. An ADR is the right place for them, and being handed the requirements is not a reason to skip it.

## When it is an ADR

Write one when a choice is **hard to reverse** and someone could reasonably
have chosen otherwise. A decision with no alternatives was not a decision.

- **ADR** - why a choice was made. The decision is frozen once accepted; new knowledge means a new ADR that supersedes it, not a rewrite.
- **Spec** - how a thing IS. Updated in place. If you are describing current
  behaviour, that is a spec, not an ADR.
- **Code comment** - why this line is odd. Local, no alternatives weighed.

Do not write one for a reversible or obvious choice. A repo full of
ceremonial ADRs is worse than none, because the real ones stop standing out.

**Write it when the decision lands**, not at the end of the work. The
reasoning is available for about an hour and then it is reconstruction.

## Before writing

1. **Find where ADRs live.** Do not assume. Look for `docs/adr/` or
   `docs/decisions/`. Match whatever is already there - numbering, naming,
   frontmatter. A new ADR that does not match its neighbours is a smell.
   If nothing exists yet, use `docs/decisions/ADR-NNNN-short-slug.md` and
   say so rather than creating a convention silently. `ADR-0007` is the
   handle people will cite; it has to work with no path in front of it.
2. **Read the last two.** They show the house style and may already cover
   this ground.
3. **Check for one to supersede.** If this reverses or narrows an earlier
   decision, that is a relationship to record in both directions.

## Writing it

Start from `assets/templates/adr.md` in this skill and keep to its four
sections.
Take the next unused ADR ID, zero-padded, with a slug in the filename:
`ADR-0007-postgres-over-dynamo.md`.

**Keep the ID out of the heading.** The heading is the title alone —
`# Postgres over DynamoDB`, not `# ADR-0007: Postgres over DynamoDB`. An
index of prefixed titles is unreadable, and the ID is already in the
filename. It belongs on the metadata line:

    # Postgres over DynamoDB

    ADR-0007 · 2026-08-05 · Status: accepted

**Context** - the forces, honestly. What pressure produced this decision.
Include the constraints that were not negotiable, because those are what
change later and make the decision revisitable.

**Decision** - actively phrased, in one or two sentences. "We use X."

**Consequences** - what gets easier, what gets harder, what was given up.
The "harder" list is the one people skip and the one that pays off.

Two things that make the difference between an ADR worth reading and a
formality:

- **Name the alternatives and why each lost.** A decision recorded without
  its rejected options cannot be re-evaluated later; the reader has no idea
  whether the reasons still hold.
- **Record what was tried and failed.** If an approach was attempted and
  abandoned, that is the most valuable content in the document - it is the
  thing a future reader is most likely to try again. Failures are evidence,
  not embarrassment.

State uncertainty where it exists. "We believe X, unverified" ages far
better than false confidence, and tells a reader exactly what to re-check.

## After writing

- **Context and Decision are frozen once accepted; everything else
  accrues.** A changed decision is a new ADR, never an edit to the old
  one - write it, cross-link both ways, and the old gets
  `Status: superseded by ADR-0012`. Editing the original instead leaves a
  record of reasoning nobody ever applied, and quietly repoints every code
  comment and story that cites the old ID at a different decision.
- **Consequences are the exception, and they are the part worth having.**
  What a decision actually cost is learned months later, not on the day it
  was made. Add to Consequences as it becomes known, dated, and leave what
  was already there - a cost that was predicted and a cost that arrived are
  two different facts, and the distance between them is how anyone
  calibrates the next decision. Correcting a broken link, a typo or a
  mis-stated fact is fine on the same grounds: the *decision* is frozen,
  the document is not.
- Point at it from the work it governs - the PRD, the spec, the story's
  `## References`.
- Where a decision constrains a library's public surface, summarise the rule
  in that library's shipped skill and leave the reasoning here. Do not
  re-argue it there.
- Grep for anything that asserted what this ADR reverses, and fix it in
  the same change. A superseded claim left standing in a guide or a README
  outlives the decision that killed it.

## Adopting mid-project

Decisions already made and undocumented are worth recording only where they
are still live and still contested. Write those; do not backfill history for
its own sake. Mark them plainly as reconstructed after the fact, since the
context is remembered rather than captured.
