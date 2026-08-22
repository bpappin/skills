# What should a local tracker snapshot actually hold?

RAD-0004 · 2026-08-18
Keywords: snapshot, docs/stories, sync, incremental pull, since, delta,
          deletion sweep, retired stories, closed issues, working set,
          just-in-time fetch, write-if-changed, merge conflicts, rejected:
          full pull every time, rejected: local index of everything

Status: design settled by discussion, not experiment - no
`Measured against:` line. The cheap parts are built (see below); the
incremental fetch and the retention rule are not.

## Question

The snapshot under `docs/stories/` began as "the tracker, on disk" - every
issue, refreshed wholesale on every pull. That worked for one person and
broke as soon as two people pulled: 299 files in one project, 140 in
another, rewritten in full whether or not anything had changed.

The immediate defects are fixed. The question underneath them is what the
snapshot is *for*, because the answer decides what belongs in it.

## Trail

### Three defects, decreasing in obviousness

**The generation date was stamped into every file**, so every pull dirtied
every file even when nothing upstream had moved. Fixed: the date lives in
`INDEX.md` alone, and a story file changes only when the issue changed.

**Every file was rewritten unconditionally.** Identical rewrites are
invisible to git, so this was not a conflict problem - but it throws away
git's stat cache (the next `git status` re-hashes everything), destroys
mtimes, and wakes every watcher and folder-sync client. Fixed: content is
compared before writing, and a pull that changes nothing touches nothing.

**Every issue is fetched every time.** Neither script is incremental:
YouTrack pages the whole project, GitHub walks `state=all`. On a mature
project that is over a thousand issues re-fetched to rewrite a handful.
Not fixed.

### Deletions are the awkward half of incremental

`since` answers *what changed*. It cannot answer *what no longer exists*:
a deleted issue simply stops appearing, and an incremental result cannot
distinguish that from "unchanged".

So the two questions need separate mechanisms and separate cadences. The
existence check is an **ID-only sweep** - on YouTrack genuinely cheap,
since fields are selectable and the bodies are all the weight - diffing
the IDs the tracker lists against the files present.

**Deletion is rare.** Trackers retire tickets rather than removing them,
and retirement is a state change that `since` already catches. So the
sweep is a safety net, not routine: weekly, or on demand.

That rarity implies a guard. **A large delta is evidence of something
other than deletion** - a credential that lost project access, a changed
project key, a visibility rule, a pull aimed at the wrong project. Removing
several hundred local files because a token quietly lost permission would
look exactly like a mass deletion to the script. So: remove a handful
without ceremony, and above roughly a tenth of the snapshot, stop and make
it explicit.

The script also cannot tell deletion from lost visibility, so it should say
"no longer visible" rather than "deleted". The action is the same; the
difference matters to whoever goes looking.

### The snapshot is the working set, not the archive

The sharper question is why retired stories are cached at all.

A completed story's outcome is **already in front of you, compiled and
running**. Its reasoning, where anyone recorded it, is in an ADR or a RAD -
which is what those are for, and why they are committed rather than synced.
The story body was connective tissue while the work was in flight; once the
work landed, that job is done.

What is *not* recoverable from the code is what has not happened yet.

So four records, one purpose each:

| Record | Holds | Lives |
|---|---|---|
| the code | what was done | the repository |
| ADRs / RADs | why it was decided | `docs/knowledge/`, committed |
| the tracker | everything, permanently | the tracker |
| the snapshot | **what is coming** | `docs/stories/`, disposable |

The snapshot is the only one of the four that is disposable, and that
follows from the division rather than being a convenience.

### Nothing is hidden by pruning

An earlier version of this design kept every retired issue in `INDEX.md` -
id, title, state - so a pruned story stayed discoverable.

That is redundant. **The tracker is the index**, and it is queryable. The
reference is already in front of you: a story saying `depends on PROJ-100`
carries the pointer, and resolving it is a lookup rather than a search.
Keeping a second, partial copy of an authoritative list is exactly the
duplication this whole document is removing.

What survives from that argument is one line, not hundreds of rows: the
index header must say what it contains, so that an agent failing to find an
ID concludes *not cached* rather than *does not exist* and files it again.

### Retention follows the snapshot mode

Pruning retired bodies is safe only where they can be fetched on demand -
which is precisely what `snapshot: synced` assumes and `snapshot:
committed` denies. A project that committed its snapshot did so to have it
readable with no tracker; silently emptying it of history breaks the reason
it exists.

So retention is not a separate setting. **Synced prunes; committed keeps
everything.**

## Findings

**Most of the pain was three mechanical defects, not the design.** Two are
fixed and cost nothing conceptually. Worth remembering the order: the date
stamp was 90% of the conflict damage and a one-line change.

**`since` and existence are different questions.** Conflating them produces
either a full pull every time (today) or silent drift (naive incremental).

**Rarity is a design input, not a footnote.** Because deletion is rare, the
sweep can be lazy - and because it is rare, a large result means something
else is wrong and should stop rather than proceed.

**A cache of finished work competes with better records.** The code says
what was done and the ADR says why; a retired story body is the weakest of
the three and the only one being duplicated.

**The acceptance criteria are the exception worth naming.** What "done"
meant for a slice is not visible in the code. It is a real question when
reworking an area - and it is one fetch by an ID already in hand, which is
not worth caching hundreds of files to serve.

## Recommendation

1. **Built already:** date out of the per-file template; write only when
   content differs, index and dimensions included.
2. **Incremental fetch.** `since` the last pull, from state held per
   developer in `~/.agents/story-tools/pull-state.json` - keyed like the
   roles file, because a committed timestamp reintroduces the conflict.
3. **Rebuild `INDEX.md` from the frontmatter on disk**, not from the API
   response. This is what makes incremental safe.
4. **A periodic ID-only sweep** for existence: weekly by default,
   `--sweep` to force, `--full` for the old behaviour. Above ~10% of the
   snapshot it stops and requires `--force`.
5. **Prune retired bodies under `synced`**: keep open, referenced-by-open,
   and recently resolved (30 days, tunable). Keep everything under
   `committed`.
6. **Say so in the index header** - what this contains, and that the
   tracker has the rest.

## Open questions

1. **What counts as referenced?** Link types are unambiguous; free-text
   `PROJ-123` mentions in a body are a scan and a judgement about how far
   to follow the chain. One hop, probably.
2. **Is 30 days right for recently-resolved?** Picked by feel. It wants to
   cover the QA-and-follow-up tail, which is per-team.
3. **`story-reconcile` compares local documents against the tracker.** With
   retired bodies absent by design, its "missing locally" logic must not
   report that as drift.
4. **Does the sweep belong in the pull at all**, or in a separate command?
   Folding it in means it runs when someone happens to pull; separating it
   means it runs when someone remembers.

## References

- `skills/stories/story-reconcile/scripts/yt-pull.sh`,
  `gh-pull.sh` - where all of this lands
- `skills/stories/story-reconcile/SKILL.md` - conflict resolution rules,
  and the `snapshot` mode
- RAD-0003 - roles; the same instinct that per-developer state does not
  belong in a shared repo
