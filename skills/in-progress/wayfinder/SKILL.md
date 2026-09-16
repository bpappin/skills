---
name: wayfinder
description: Chart a chunk of work too big for one session as a map of decision issues on the tracker, then resolve them one at a time until the way to the destination is clear. Use when an idea is too large or too foggy to slice into stories yet - "this is a big one", "I don't know where to start", "we need to work out the shape first", "plan this out". Not for breaking an agreed plan into stories; that is to-issues.
license: MIT
compatibility: Requires a connection to the project's issue tracker (see the tracker binding; YouTrack today).
metadata:
  author: bpappin
  version: "1.0"
---

# Wayfinder

An idea has arrived that is too big for one session and too foggy to slice: the way from here to the **destination** is not visible yet. This skill charts that way as a **map** on the tracker - one issue whose children are **decision issues**, each a question whose resolution is a decision - and works them one at a time until nothing is left to decide.

Adapted from the `wayfinder` skill in `mattpocock/skills`, rewired onto story-tools conventions: decisions land as RADs and ADRs in the docs tree, and the build is handed to `to-prd` and `to-issues` once the way is clear.

**Tracker dispatch:** read `.agents/config/story-tools.json` → `tracker.type` (absent → `youtrack`) and use that binding:

- `youtrack` → [references/tracker-youtrack.md](references/tracker-youtrack.md)
- `github` → not yet; the frontier needs typed blocking links, and the GitHub binding writes `Depends on #N` as body text. Say so and offer to chart on YouTrack, or to work the map by hand.

## Chart decisions, not the build

Wayfinder produces **decisions**. It never produces build slices: when the way is clear, `to-prd` writes the requirement and `to-issues` cuts the vertical slices. The pull to start building is the signal that the map is finished and it is time to hand off.

That split is why a map is worth keeping. A story carries acceptance criteria and is picked up by `story-workflow`; a decision issue carries a question and is resolved by a RAD or an ADR. Mixing them puts questions on a board that expects deliverables.

## The map

The map is one issue, and it is an **index, not a store**. Each decision lives in exactly one place - its own issue, and the document that issue produced - so the map only gists and links. Open decisions are not listed; they are found by querying its children.

```markdown
## Destination
<what the end of this map looks like: the requirement, the decision, or the change this effort is finding its way to. One or two lines. Every session reads this before choosing anything.>

## Notes
<the domain, the skills each session should use, standing preferences for this effort>

## Decisions so far
- <issue ID + title>: <one-line gist> → <RAD/ADR ID and title>

## Not yet specified
<in-scope fog: questions you can see coming but cannot phrase sharply yet>

## Out of scope
<ruled beyond the destination, with the closed issue that held it>
```

**Refer to issues by title, not by bare ID.** A wall of IDs is unreadable; a title with its ID beside it reads at a glance.

## Decision issues

Each is a child of the map, sized to one session, and its body is the question:

```markdown
## Question
<the decision or investigation this resolves>

## Resolves into
<RAD, ADR, or "a note on the map" - what artifact this produces>
```

A session **claims** one by assigning it to the driving developer before any work, so parallel sessions skip it. An open, unassigned child is unclaimed.

Blocking uses the tracker's typed link, so the tracker itself shows what is takeable. A decision is **unblocked** when every issue it depends on is resolved. The **frontier** is the open, unblocked, unclaimed children.

## Types, and which skill resolves each

Every decision is **HITL** (worked with a person, who speaks for themselves) or **AFK** (the agent alone) - the same split `to-issues` uses. A HITL decision only resolves through that exchange; an agent that answers its own questions has broken it.

| Type | HITL/AFK | Resolved by | Lands as |
|---|---|---|---|
| Research | AFK | `to-rad` | A RAD in `docs/knowledge/research/` |
| Proof of concept | AFK | `to-rad` (POC mode) | A RAD, with what was tried and what it showed |
| Grilling | HITL | `grill-with-docs` | A RAD, or an ADR if the answer hardens |
| Task | either | no skill - do the work | A note on the map: what was done, and any fact later decisions depend on |

A recommendation that hardens into a commitment becomes an ADR (`to-adr`). That is the normal end of a grilling decision, and the ADR - not the issue comment - is the durable record.

## Fog of war

The map is **deliberately incomplete**. Beyond the live decisions lies fog: questions you can tell are coming but cannot pin down, because they hang on questions still open. Resolving one clears the fog ahead of it, and whatever is now sharp enough graduates into new issues.

**The test is whether you can state the question precisely now, not whether you can answer it.** Sharp enough to state → an issue, even if it is blocked. Not sharp → leave it in **Not yet specified**, and do not pre-slice it: one patch of fog may graduate into several issues, or none.

## Out of scope

Fog only gathers *toward* the destination. Work beyond it is not fog - it is out of scope, and it gets its own section. When an issue turns out to sit past the destination, close it and leave one line saying why, linking the closed issue. It never appears in **Decisions so far**, which records the route actually walked.

Out-of-scope work never graduates. If the destination is redrawn, that is a fresh map.

## Charting a map

1. **Name the destination.** Use `grill-with-docs` to pin down what this map is finding its way to. The destination fixes the scope, so it is settled first.
2. **Map the frontier.** Grill again, **breadth-first** - fan out across the whole space rather than deep on one thread - surfacing the open questions and the ones takeable now. **If no fog surfaces**, the way is already clear: stop, say so, and point at `to-prd` or `to-issues` rather than building a map nobody needs.
3. **Create the map issue** with Destination and Notes filled in, Decisions-so-far empty, and the fog written into **Not yet specified**.
4. **Create the decisions you can state now** as children, then wire the blocking links in a second pass, once they all have IDs.
5. **Stop.** Charting is one session's work and resolves nothing.

## Working a map

The user names a map, and optionally a decision. Without one, you choose - **never resolve more than one per session**, research excepted.

1. Read the map. The low-resolution view only; fetch a child's body when you need it.
2. Choose from the frontier, and **claim it first**, before any work.
3. Resolve it with the skill its type names. Read closed siblings on demand rather than up front.
4. Record it: write the RAD or ADR, comment the answer on the issue with a link to that document, resolve the issue, and append one line to **Decisions so far**.
5. Update the map: create any newly sharp decisions, graduate the fog they came from (clearing it from **Not yet specified**), and rule anything now past the destination out of scope. If the answer invalidates other decisions, change or close them.

Expect other sessions to be editing the tracker at the same time.

## When the map is done

No open children, nothing left in **Not yet specified**, and the destination reachable. Hand off: `to-prd` writes the requirement from the decisions, `to-issues` cuts the slices, and the map stays as the trail of how the shape was found. Do not close the map's children to "tidy up" - a closed decision is the record.
