# How should stakeholder comments reach a PRD or a story?

RAD-0002 · 2026-08-13
Keywords: comments, stakeholder feedback, product management, non-technical,
          change request, PRD adjustment, incorporate comments, triage
          source, needs-review, marker convention, rejected: REQUEST:
          prefix, rejected: incorporation contract in story-workflow

Status: design settled by discussion, not experiment - no
`Measured against:` line. Nothing implemented yet.

## Question

Ticket bodies are the source of truth: `Purpose`, `Specification`,
`Acceptance Criteria`, and PRDs on epics. Feedback arrives as **comments**,
which no skill folds back in. A comment does not change the body, so the
spec drifts from the discussion beneath it, and an agent picking the ticket
up cold never sees it.

The narrow question was whether a skill should read comments. The real
question is how a **non-technical stakeholder** — product management, a
client, anyone who will never edit a structured body — asks for an
adjustment to a PRD or a story and can tell that it landed.

## Trail

### The gap is ragged, not uniform

Worth stating precisely, because it changes what has to be built:

- `get-story-context.js` does not read comments at all.
- `to-prd` never mentions them.
- `triage` step 1 already says "read the full issue (body, comments,
  roles…)" — so triage reads them today, informally.
- story-workflow's **GitHub** binding specifies `story.context` as
  `get_issue` (+ comments); the **YouTrack** binding does not.

So this is one missing binding operation surfacing as several different
symptoms. `comments.read` in each `tracker-*.md` is the first piece of work
and everything else depends on it.

### The marker convention, and why it fails here

The obvious design is a marker: a stakeholder prefixes `REQUEST:` on
anything they want acted on, and the agent incorporates those.

It fails on the population it exists to serve. The people whose feedback is
being captured are the ones least likely to learn a convention, and the
[pnpm RFC](https://github.com/orgs/pnpm/discussions/13422) names the general
failure exactly: a mechanism like this "puts an adoption step in front of
the discovery mechanism." A stakeholder who forgets the prefix has their
request silently ignored, which is the status quo with extra ceremony.

It is also the same mistake as requiring a human to paste a priming prompt:
the mechanism only works when someone remembers to do something first.

A marker survives as an **optional accelerator** — it costs nothing to
honour `REQUEST:` when present — but it cannot be the gate.

### What actually arrives

Input is unbounded, from three words to a diatribe, and none of it is
structured. The shapes that matter:

- **One comment, several asks** — or none.
- **A rant** carries one real request wrapped in frustration and context.
- **Three words** ("make it faster") is under-specified.
- **A question is often a requirement in disguise** — "does this work
  offline?" usually means it must.
- **Agreement and thanks** carry no change at all.
- **Machinery comments** (`Effort: 2h`, agent briefs) are not feedback.

Nothing here is parseable. Classification is judgement, and judgement lives
in skill prose — the same split the suite already uses everywhere else:
mechanism in the tool, judgement in the agent.

### Why this is triage, not a new contract

A comment is something that arrived and needs deciding about. That is
exactly what `triage` is: a state machine over an inbox, with roles,
`needs-info`, `needs-triage`, route-to-story, `wontfix`, and a standing rule
to confirm before acting.

Treating comments as a new **source** for that machine, rather than as a new
"incorporation workflow", inherits the ambiguity handling, the human
confirmation step and the reply discipline instead of respecifying them.

### Where incorporation must NOT happen

**Inside `story-workflow`.** That skill exists to hold scope still: the AC
checklist is the scope, and anything else routes to a new linked issue. A
step that rewrites the body of the focused story mid-flight breaks the
invariant the skill is for.

story-workflow's job is to **surface** comments on the focused story and
route anything actionable outward — to discovered work, or back to triage.
It never applies.

### Propagation needs a guard

When an incorporated change alters a PRD requirement, child story ACs must
follow or the PRD and the stories diverge. But rewriting the AC of a story
that is in progress or already done is worse than the drift it fixes.

Only unstarted stories are edited in the same pass. Anything focused or
completed is flagged for a human.

## Findings

**The reply is the product, not a courtesy.** A non-technical commenter
cannot read a diff of a structured body. What they can read is "you asked
for X, it is now requirement R4, here is what changed" — or "I could not
tell whether you meant A or B." For this audience the reply *is* the visible
mechanism; everything else happens somewhere they do not look.

**Propose, do not apply.** Given unbounded input and an audience that cannot
review the result, an agent that guesses wrong and edits silently is a worse
failure than one that misses a request. Ambiguity produces one question
back, never a guessed requirement.

**Reduce, never paste.** What lands in the body is the request restated in
canonical form. The tone, the context and the frustration stay in the
comment where they belong.

**A tag is needed, and it should mean one thing.** Two candidate meanings:
"there is unincorporated feedback here" (an inbox signal, set by anything
that reads comments, cleared on incorporation or dismissal) and "a proposed
change awaits human approval" (a gate, which implies somewhere to store the
proposal). Take the first; there is nowhere to store a pending proposal, and
`ready-for-human` already covers the second if it is ever wanted.

**Any new tag is reserved-set plumbing.** It must be added to
`RESERVED_TAGS` in `story-lib.js` or `topicalTags` treats it as topical and
`add_discovered_work` inherits it onto every new issue — so discovered work
would be born needing review. The installer's `ensure_labels` reserved set
needs it too, since tags map 1:1 to labels on GitHub.

**This content cannot be script-tested.** It wants eval cases spanning three
words to a diatribe, and critically including comments that must produce
**no** edit. An agent that finds a requirement in "nice work everyone" is
the failure that matters.

## Recommendation

1. **Add `comments.read` to every tracker binding.** Nothing else can be
   written until the capability exists in the tables. This is mechanism.

2. **Comments become a triage source.** `triage` classifies and routes;
   nothing new is specified that triage already does.

3. **`to-prd` owns the body rewrite** when routing says a PRD changes,
   including canonical-format restatement and child-story AC propagation
   under the unstarted-only guard.

4. **`story-workflow` surfaces only.** Comments on the focused story are
   read and reported; actionable ones route out as discovered work.

5. **`story-reconcile` gains comment drift.** Comment-driven divergence
   between local docs and the tracker is what that skill is for.

6. **Judgement goes in skill prose**, covering: reduce don't paste; one
   comment may hold several asks or none; questions are often requirements;
   under-specified means one question back; agreement produces no edit;
   machinery comments are skipped; the reply mirrors the commenter's own
   words.

7. **A tag for unincorporated feedback**, added to `RESERVED_TAGS` and to
   the installer's reserved label set in the same change.

## Open questions

1. **The tag's name.** `needs-review` reads as *code* review in a developer
   tool. The suite's established pattern is `needs-<the thing that is
   missing>` — `needs-gherkin`, `needs-info` — and what is missing here is
   incorporation, not review. Unresolved.

2. **The approval gate.** Whether incorporation of a scope or AC change
   requires explicit approval before the body is written, and from whom.
   Leaning: conversational confirmation, per triage's existing rule, rather
   than a stored proposal.

3. **Whether a sweep exists.** A scheduled pass over tickets carrying the
   tag, versus incorporation only on human request. Auto-incorporation
   without a trigger is out of scope either way.

4. **Comment provenance in the body.** Whether the Authors/History line
   records "incorporated comments" with a date, and whether that is worth
   the churn on a document that already has git history behind it.

## References

- `skills/stories/triage/SKILL.md` — the state machine this reuses
- `skills/stories/story-workflow/SKILL.md` — the scope invariant this must
  not break
- `trackers/youtrack/app/story-lib.js` — `RESERVED_TAGS`, `topicalTags`
- [pnpm RFC #13422](https://github.com/orgs/pnpm/discussions/13422) — the
  adoption-step-before-the-mechanism critique
