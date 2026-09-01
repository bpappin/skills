---
name: to-stories
description: Break a plan, spec, or PRD into independently-grabbable stories using tracer-bullet vertical slices, written as markdown files in the repo. Use when the user wants to turn a plan into implementation stories and the project has no issue tracker, or the tracker is not reachable from here. Triggers - "break this down", "turn this into stories", "what are the slices", "make tickets for this".
license: MIT
compatibility: Standalone. No tracker, no network, no scripts - stories are files in the repo.
metadata:
  author: bpappin
  version: "1.1"
---

# To Stories

Break a plan into independently-grabbable stories using vertical slices (tracer bullets), written as markdown files under `docs/stories/`. No tracker, nothing to connect, nothing to sync.

The story body format here is **identical** to the one the tracker-backed skills use. That is deliberate: a project that later adopts a tracker moves its stories by pasting the body, not by rewriting it.

## Where stories live

One file per story, `docs/stories/STY-NNNN-short-slug.md`, IDs assigned from `0001` upward and zero-padded so the files sort.

**`STY-0042` is the story's identity and its citation handle** - what a blocker names, what a commit message references, what a PRD's table lists. The type prefix is what makes it unambiguous with no path in front of it: a bare `0042` collides with decision 42 and research log 42, and those get cited in the same sentences. Never reissue an ID; a story that is abandoned keeps its own and gets `status: dropped`.

If the project already keeps stories somewhere else, use that. Match what is there rather than introducing a second convention.

## Process

### 1. Gather context

Work from what is already in the conversation. If the user names a PRD, a RAD or a plan file **in this repo**, read it fully first. Read `docs/stories/` to see what exists - both for the next unused ID and to avoid re-cutting a slice that is already written.

**The PRD often does not live here, and that is normal.** Where an architect or a business analyst owns requirements, the source is a document in some other system - a wiki page, a ticket, an attachment, or text pasted into the conversation. Work from whatever you are actually given, and say which it was.

Two things follow from a source you cannot open yourself:

- **Do not infer requirements you were not shown.** If you only have an excerpt, slice the excerpt and say plainly which parts of the source you did not see. A slice invented to fill a gap in a document you could not read is the most expensive kind of wrong, because it looks like it came from the requirements.
- **If the source does not number its requirements, do not mint numbers for it.** Quote the requirement text in `covers:` instead. An `R-3` that exists only in your story is a reference that resolves nowhere, and the next person will go looking for it.

### 2. Explore the codebase

Enough to use the project's own vocabulary in titles and descriptions, and to respect any ADRs covering the area. A story written in words the codebase does not use will be misread by whoever picks it up.

### 3. Draft vertical slices

Each story is a **tracer bullet**: a thin vertical slice cutting through every integration layer end to end, not a horizontal slice of one layer.

- Each slice delivers a narrow but COMPLETE path through every layer it touches - schema, API, UI, tests.
- A completed slice is demoable or verifiable on its own.
- Prefer many thin slices over few thick ones.

Mark each **AFK** (implementable and mergeable without human interaction) or **HITL** (needs a person - an architectural decision, a design review, a judgement call). Prefer AFK where the work allows it.

### 4. Quiz the user

Present the breakdown as a numbered list before writing anything. For each slice: **Title**, **Type** (AFK/HITL), **Blocked by**, **Covers** (which requirements from the source), and a rough **Estimate** (1h / 4h / 1d - calibration data, not a promise).

Ask: is the granularity right? Are the dependencies right? Should any slices merge or split? Iterate until approved. Writing twelve files and then being told the slicing is wrong wastes more than the question costs.

### 5. Write the files

In dependency order, blockers first, so `blocked_by` can reference real numbers.

```markdown
---
id: STY-0007
title: Signed-in user sees their own drafts
status: todo
type: AFK
blocked_by: [STY-0003]
topic: Draft Visibility
estimate: 4h
covers: [R-3, R-4]
---

## Purpose
<Why THIS slice is necessary and what problem it solves - what breaks, or
stays broken, without it. The feature-level why belongs in the PRD; link it
in References rather than restating it, or this becomes a copy that drifts.>

## Specification
<Required behaviour in detail: the contract, edge cases, error and empty
states, boundaries, what happens when an input is absent or malformed.
"None beyond the AC." is a legitimate body for a genuinely trivial slice -
write that rather than padding.>

## Acceptance Criteria
- [ ] Verifiable outcome one
- [ ] Verifiable outcome two

## References
- docs/requirements/PRD-0003-draft-visibility.md
- docs/decisions/ADR-0004-session-scoping.md
```

**Reference the source however it can actually be found again.** A repo path when the source is here; otherwise the ticket key, the page title and its system, or a URL - whatever a reader could paste somewhere and land on the right thing. "The PRD" is not a reference.

**Frontmatter fields.** `status` is one of `todo`, `doing`, `done`, `blocked`, `dropped`. `topic` groups related stories the way a tag would - one shared value across a batch, Title Case, usually the feature name. `blocked_by` is a list of story ids. Everything else is optional; omit a field rather than inventing a value for it.

**Purpose and Specification are prose, not bullet fragments.** A story is read cold - by a new developer, a fresh agent, or you in three months - and these two sections exist so that reader does not reconstruct intent from a checklist. Purpose is required on every story. Specification is required wherever anything is non-obvious, which is most of them.

**Specification says what must be true, not which files to touch.** No file paths, no implementation plans, no layer-by-layer instructions - they date faster than the story and take the approach away from whoever picks it up. The one exception is a snippet that *encodes a decision* - a state machine, a schema, a type shape - trimmed to the decision-rich parts.

**Specification is prose; AC is the checklist.** AC is the completion gate, so Specification must never become a second checklist competing for that role. Every AC item should trace back to something Specification states, but Specification carries the detail that would make a checkbox unreadable.

### 6. Close the loop

If the source was a PRD, add or update its story table with the new numbers and the requirements each covers. Do not modify the source beyond that.

## Working a story afterwards

There is no tracker to hold state, so the file holds it. Set `status: doing` when you start and `status: done` when the AC are all checked. Tick AC boxes in place as they land.

**Do not tick an AC you have not verified.** The checkbox is the only completion signal this set has - there is no board, no query, and nobody reviewing a transition. A story marked done on inspection rather than on evidence is worse than one left open, because it stops being looked at.

If work turns up that is out of scope, do not widen the story. Write a new one and note it in `blocked_by` or `References` as appropriate. Scope discipline is the whole reason for slicing.
