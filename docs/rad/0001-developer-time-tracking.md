# What should a time-tracking skill actually do for a developer?

RAD-0001 · 2026-08-08
Keywords: time tracking, worklog, timesheet, hours, billable, invoicing,
          log time, start stop timer, automated timesheet, activity
          inference, daily target, gaps, rejected: evidence-derived hours,
          rejected: tamper-evident ledger, rejected: proportional gap filling

Status: design settled; reached by discussion, not experiment - no
`Measured against:` line. The `worklog` skill that follows from it ships
at stability **experimental**.

## Question

story-tools logs time only where the workflow happens to be present and
reaches a session close. Time is lost when a session ends abruptly, no skill
can detect a gap because nothing reads work items back, and on
GitHub-tracked projects `work.logTime` posts a comment nobody can aggregate.

The narrow question was whether to plug those holes. The real question is
what a time-tracking skill is *for* — because the obvious answer, infer the
hours from what the agent can see, turns out to be the wrong one.

## Trail

### Prior art, and the trap in it

[A published architecture for automating Jira worklogs](https://medium.com/@yogendrachowdary101/how-i-automated-my-daily-jira-worklogs-using-langgraph-llm-agents-1c76e6c3c07e)
reads calendar events, commits, sent mail and ticket comments, fans them
through an agent graph, and produces a draft the developer glances at.

Its useful contribution is the evidence-sources idea. The trap is its
gap-filling: it compares logged time against a daily target and
proportionally distributes the remainder across tasks until the target is
met. That manufactures a total.

The distinction worth preserving is between two different numbers. A day's
total is an **assertion** by the person who worked it. The split across
projects is an **estimate**. Smoothing the split is ordinary and fine;
inventing the total is not, and no amount of evidence entitles a tool to do
it.

### Patterns this has to accommodate

These are common working patterns among developers, not a single person's
habits. Each one rules out a design that looks reasonable in the abstract.

**Time is personal and crosses every repo.** A day contains several
projects plus meetings, invoicing, support and sales that live in no repo at
all. A ledger stored per project cannot answer "where did Thursday go"
without stitching, and non-project time has nowhere to sit. Whatever the
record is, it belongs to the person, not to a codebase.

**A day is a span, not a set of sessions.** You sit down, work, get up for
coffee, come back. The break is inside the working span, not a hole to be
deducted. Tools that model a day as discrete tracked intervals lose to this
immediately, because nobody stops a timer to make tea.

**Much real work leaves no trace.** Reading, thinking, a phone call, a
whiteboard, a conversation. An evidence sweep sees none of it, so absence of
evidence is not evidence of absence — it is the normal condition for a
substantial fraction of the day.

**The record is a working document, not evidence.** People correct their own
logs constantly: *it says three hours but it was five*, *I forgot yesterday
entirely*. Designing for tamper-evidence — auto-commit, immutable history,
timestamps that prove contemporaneity — designs directly against the primary
use. Hand editing is the feature, not drift to be reconciled.

**Gaps are usually noise.** Most employers and clients buy a day's work and
trust it was a day's work; they do not want a play-by-play and do not
audit the minutes. A tool that treats every unaccounted twenty minutes as a
problem is solving for a relationship most developers do not have. Where
stricter substantiation *is* required — R&D tax credits, disputed invoices,
regulated billing — that is a property of the engagement, and it belongs in
how the record is reviewed and submitted rather than in how it is captured.

**Targets are per engagement, not universal.** Paid work often has a daily
quota. Unpaid, internal or open-source work has none, and the day is however
long it was. A day therefore carries a target or carries nothing, and
carrying nothing is an ordinary state rather than a missing field.

**Work is interleaved across projects.** Agent-assisted development makes
this sharper: set a job running on one project, switch to another, come
back. Sometimes the opposite — deliberate focus on one thing while
delegating elsewhere. Attribution cannot be a partition of the day into
disjoint blocks, and the tool has no business trying to make it one.
Whether two projects share an hour, and how that is squared with whoever is
billed, is a judgement about effort that only the person who did the work
can make. Humans account for time and effort differently than a clock does.

**Agents write commits.** This one appears absent from the prior art and is
specific to agent-assisted work. When an agent runs on project A while the
developer attends to B, project A produces commits. Commit density is the
obvious proportional prior for splitting attention, and here it is actively
misleading — it credits the project that had a *machine* on it, not the one
that had a person. Any evidence layer must separate authored work from
agent-produced output, or the record drifts toward whatever was delegated
most.

### Two records, not one

A late correction, and the one most likely to be re-broken. Trackers
already log **effort**: time spent on an issue, recorded on that issue,
answering "how much did this story cost." A **work log** is a different
record: the developer's working time, attributed to a project, answering
"what did I do today" and feeding timesheets and invoicing.

They look alike and are not. Effort is bounded by a story; a working day
contains meetings, several projects, and work no issue covers. Conflating
them produces the two failures that prompted this split — an agent
recording an eleven-hour day as effort on a single issue, and an agent
hunting for "the best home" for a number that no story owns.

So they stay separate, with separate owners. story-workflow keeps
`effort.log`, on the focused issue only, and never picks an issue on the
developer's behalf; if no story is focused there is no effort to record.
The work log belongs to the `worklog` skill and is what the rest of this
document describes.

### What the patterns leave

Taken together they delete most of an ambitious design: reconstruction of
totals from evidence, target-driven allocation, attention-splitting across
interleaved projects, periodic prompting, task-change detection, and gap
detection as a feature.

What survives is small, and small enough to be worth building.

## Findings

**The duration is always asserted, never inferred.** The person says how
long. No evidence sweep produces a total, no target allocates one, no
absence of commits shortens one.

**The agent's value is attribution and summary.** Which project this was —
which a project-scoped agent knows without being told — and a brief account
of what got worked on, drawn from what that project saw in the window:
authored commits, tracker activity, the focused story, session artifacts.
Brief by default.

**Two peer inputs, not a pipeline.** `log 3 hours` is complete on its own
and never requires a start to have happened. Bracketing with start/stop is a
convenience for when it gets used, and the clock supplies the span.

**One proactive behaviour, and it is advisory.** If a span is left open, say
so once, in case it was forgotten. A refusal ends it — the agent does not
close it, switch it, or raise it again. It never manages span state on
someone's behalf.

**The core capability is small: log time, and say what was worked on.**
Everything else is optional convenience. A version that does only those two
things is already useful; a version that does them badly is not rescued by
anything else on the list.

**Detail is free because it stays local.** Two readers want opposite
resolution. The personal copy keeps whatever texture is useful months later;
anything submitted is a coarse roll-up of hours per project per day. The
roll-up is generated, so keeping detail costs nothing.

## Recommendation

Build a `worklog` skill, marked experimental in `metadata.stability`, in the
description, and in a banner at the top of the body.

**Ledger.** Plain markdown, `~/.agents/worklog/YYYY-MM.md`, personal and
cross-project. No git, no auto-commit. Location configurable, with a
per-project override registered in the user config so a day can still be
assembled from a directory that isn't the one holding the file. Entries
carry when, how long, the project, and a short summary. **The project is
the unit of attribution.** A story reference is at most a phrase in the
summary — see the two-records distinction below. Times are optional; a
day-level entry is just a duration.

**Commands.** Assert (`log 3 hours`, optionally against a project, story or
date), and bracket (start / stop). An open span lives in
`~/.agents/worklog/open.json` so any project agent can close one opened
elsewhere.

**Rules.** Starting something else while a span is open does not close it;
the agent may mention the open one, and if the answer is no, both stay open.
Overlap is permitted, because resolving overlap is a human judgement. A
stale open span is never closed silently and never computed at face value —
ask what it actually was, and accept the answer. There is no pause, because
breaks are work.

**Integration.** story-workflow, handoff and housekeeping stop owning time;
they propose a line and hand it over. "Starting on PROJ-123" is already
`focus.set` in story-workflow's vocabulary, so the span and the focus move
together at no cost. Concurrent appends from several project agents go
through a small script with an atomic write, not an agent editing markdown.

**Adapters after the format settles.** An invoicing tool (Freshbooks,
Harvest and similar all expose time-entry APIs), then tracker work items and
a GitHub comment echo. The ledger is the source, pushes are idempotent, and
each entry records where it has been sent. Any invoicing adapter needs API
research before design.

**Not built, deliberately:** gap detection, evidence-derived totals,
periodic prompting, quota allocation, calendar ingestion. Each was
considered and cut.

What would change the answer: wanting the day to reconcile automatically
against a target. That is the single requirement that pulls the whole
inference apparatus back in, and it should be adopted knowingly rather than
by drift.

## References

- ADR-0004 — librarian and codex (same instinct: mechanism in the tool,
  judgement left to the agent or the human)
- story-workflow `## Session time` — the rules this supersedes
