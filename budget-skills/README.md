# Budget skills

A small, self-contained skill set for places the full package does not fit: a constrained token budget, or an organisation whose review process will not accept the sync tooling.

Copy the directories you want straight into a project's `.agents/skills/` (or `.claude/skills/`). There is no installer, nothing to configure, and nothing to connect. Take one skill or all eleven; none of them needs the others.

## The workflow

Five skills form a spine, and it runs in one direction: **a question becomes a decision, a decision becomes a requirement, a requirement becomes work, and work gets built test-first.**

| Stage | Skill | Answers | Lives in |
|---|---|---|---|
| Research | `to-rad` | "What did we look at, and what do we recommend?" | `docs/research/` |
| Decision | `to-adr` | "What did we settle, and what did we reject?" | `docs/decisions/` |
| Requirement | `to-prd` | "What must we build, and how would we know it works?" | `docs/requirements/` |
| Work | `to-stories` | "What are the slices someone can pick up?" | `docs/stories/` |
| Build | `tdd` | "Does it actually do that?" | the code |

**Not every piece of work needs all five.** A bug fix is a story and a test. A library choice is a RAD and an ADR and nothing else. The spine describes the order things happen in when they happen, not a gate everything has to pass through.

### Who runs what

In a small team one person wears every hat and walks the whole spine. In a larger one the stages belong to different people, and this set is built to be entered at whatever point you actually arrive at — **joining partway is the normal case, not a degraded one.**

| Role | Runs | Hands on |
|---|---|---|
| Business analyst / product manager | `grill-with-docs`, `to-prd` | A PRD, and the PM and commercial briefs derived from it |
| Architect | `to-rad`, `to-adr`, `to-wiring`, `grill-with-docs` | Research logs, decisions, and the integration rules in `WIRING.md` |
| Developer | `to-stories`, `to-adr`, `tdd` | Story files, implementation decisions, working code |
| Anyone, any session | `handoff`, `housekeeping`, `zoom-out`, `project-docs` | — |

**The business analyst or product manager** starts with `grill-with-docs` if the requirement is still vague — it interviews until the fuzzy parts are named, and challenges the words used against the project's domain glossary, which is where most requirement ambiguity actually lives. Then `to-prd` writes the PRD and derives the two audience briefs from it: the product brief in capability and sequencing terms, the commercial brief only when the change alters what someone outside the company can be told or promised. Those are separate documents on purpose. Nobody reads past their own section in a combined one.

**The architect** works the technical questions before anyone commits to an approach. `to-rad` holds a question while it is still open — the options, what was tried, what failed, the recommendation — and it is the only document here allowed to be inconclusive. When a recommendation hardens into a commitment, `to-adr` records it with what was rejected and why. `to-wiring` is the one people forget: it defines how features hook into each other in `WIRING.md`, so a new feature does not silently fail to integrate with the existing ones. An architect may also slice the work with `to-stories`, or leave that to whoever picks it up.

**The developer** usually arrives with the PRD already written and agreed, and runs two skills. `to-stories` slices it into work that can be picked up — this is the common entry point and often the only one. `to-adr` records the decisions that are genuinely theirs: which library, which boundary, which failure mode they chose to accept. Those are your calls even when the requirements are not, and in this arrangement they are exactly the ones nobody writes down, because the requirements were someone else's and it feels as though the decisions were too. Then `tdd` against the slices.

**Everyone** uses the session tools. `handoff` compacts a session so another agent can continue it, `housekeeping` cleans up and prepares the commit, `zoom-out` steps back when the work has lost its shape, and `project-docs` answers where a new document belongs.

### Where the handoffs actually break

**Do not write a PRD for requirements you do not own.** If they are wrong or incomplete, that is feedback to whoever owns them — not a document to author in parallel. A second PRD written by the implementer is how two sources of truth start, and the one that loses is usually the one the business is reading. `to-prd` guards against this explicitly.

**The PRD frequently is not in your repo.** It lives in a wiki, a ticket system, or an attachment, and you may only be given an excerpt. `to-stories` handles that: work from what you are actually given, cite it in a form someone can find again, and say plainly which parts you were not shown rather than inferring the rest. A slice invented to fill a gap in a document you could not read is the expensive kind of wrong, because it looks like it came from the requirements.

**Decisions made upstream need to reach the person implementing.** An ADR the architect wrote is only useful if the story cites it — `to-stories` puts it in `## References`, which is why the IDs matter. A decision nobody references gets rediscovered and re-argued.

**Nothing requires the stage above it to exist.** A team with no formal requirements process runs `to-rad` → `to-adr` → `to-stories` and never writes a PRD. A team handed requirements from outside runs `to-stories` → `tdd` and writes ADRs when a real choice comes up. Both are complete uses of this set.

### What makes each stage different

**A RAD holds what is not decided yet.** Options, the trade-offs, the thing that was tried and failed, the recommendation at the end. It is the only document here allowed to be inconclusive, and that is its value — a RAD that gets rewritten every time the answer changes destroys the trail that made the answer credible. Revisit, do not rewrite.

**An ADR is written the moment a choice hardens**, not afterwards. One hard-to-reverse decision each, with what was rejected and why. The rejected options are the part that pays: they are what stops the same argument being had again in six months by someone who does not know it was already had.

**A PRD says what to build, never whether it is done.** Numbered requirements, non-goals, the discovery trail back to the research. Verification does not live here — it lives on the stories, in their acceptance criteria, because one place has to hold done-ness and a document nobody ticks is not it.

**A story is a vertical slice, not a layer.** Each one cuts through everything it touches — schema, API, UI, tests — so a finished story is demoable on its own. Its `## Acceptance Criteria` checklist is the completion gate and the only completion signal this set has.

**TDD is where the AC get paid off.** Red, green, refactor, one slice at a time.

### How the documents point at each other

Anything that gets cited carries an ID, and the ID carries its type - that string is the handle people use:

```
docs/
  research/      RAD-0023-signal-enrichment.md
  decisions/     ADR-0004-session-scoping.md
  requirements/  PRD-0003-draft-visibility.md
  stories/       STY-0042-drafts-are-private.md
  reference/     domain-glossary.md
WIRING.md          <- feature-to-feature integration rules
AGENTS.md          <- points at the glossary so agents find it
```

A story's `## References` names the PRD. The PRD's Problem section links the RAD that led to it. The ADR is cited by whichever of them it constrains. `ADR-0004` is unambiguous pasted into a commit message with no path in front of it — a bare `0004` is not, because there is a story 4 and a research log 4 and they get cited in the same sentence. The number identifies the document; it is not a position in a sequence, which is why a PRD keeps its ID through a year of corrections.

**Never reissue an ID.** One that has been cited belongs to that document permanently, including after it is superseded, abandoned or deleted.

## What is different about this set

These are not the main skills with parts hidden. They are separate documents that had to be written differently, and they are held to two rules the main set is not.

**No script may touch the network or handle a credential.** Not a style preference — it is what makes this set reviewable. A reviewer can confirm it with a grep instead of by reading six hundred lines of transport code. The main package's sync scripts run 371 to 775 lines each and every one carries a bearer token; none of them are here, and no replacement for them belongs here either. A script that scaffolds a file, formats a document or checks a convention would be fine — as it happens, nothing in this workflow needs one, so the tree contains no scripts at all.

**Every skill stands alone.** No skill here depends on another being installed, on an issue tracker, on an MCP server, or on a knowledge base existing. Each authoring skill carries its own templates rather than pointing at a sibling, so removing any one directory breaks nothing. Where the main set says "run the sync afterwards", these say nothing, because there is nothing to run — the files in git are the record, and a document is done when it is committed.

## Moving to the full package later

The story body format here is **identical** to the tracker-backed version — same `## Purpose`, `## Specification`, `## Acceptance Criteria`, `## References`. A project that later adopts a tracker moves its stories by pasting the body, not by rewriting it. The frontmatter is the part that goes away, because the tracker holds that state instead.

## Relationship to the main package

These are a parallel set, not a subset. The same idea often appears in both, worded for a different situation, and the two can drift — a fix in one does not reach the other on its own.

**If you change a skill in `skills/`, check whether its counterpart here needs the same change.** The reverse holds too. Which of the two is right depends on the change: guidance about how to think usually applies to both, guidance about tooling usually applies to only one.

## Contents

| Skill | What it does |
|---|---|
| `to-rad` | Research log — options, trade-offs, what failed, a recommendation |
| `to-adr` | Decision record — one hard-to-reverse choice, and what was rejected |
| `to-prd` | Requirements — what is being built, plus the PM and commercial briefs |
| `to-stories` | Vertical slices with acceptance criteria, as files in the repo |
| `tdd` | Red-green-refactor, one slice at a time |
| `to-wiring` | Feature-to-feature integration rules, kept in `WIRING.md` |
| `grill-with-docs` | Interview a plan until it stops being vague; sharpen the glossary |
| `project-docs` | Where a document belongs and what to call it — filing only |
| `handoff` | Compact a session into something another agent can pick up |
| `housekeeping` | End-of-session cleanup and commit preparation |
| `zoom-out` | Step back when the work has lost its shape |
