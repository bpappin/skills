# Budget skills

A small, self-contained skill set for places the full package does not fit: a constrained token budget, or an organisation whose review process will not accept the sync tooling.

Copy the directories you want straight into a project's `.agents/skills/` (or `.claude/skills/`). There is no installer, nothing to configure, and nothing to connect. That is the point.

## What is different

These are not the main skills with parts hidden. They are separate documents that had to be written differently, and they are held to two rules the main set is not.

**No script may touch the network or handle a credential.** Not a style preference - it is what makes this set reviewable. A reviewer can confirm it with a grep rather than by reading six hundred lines of transport code. The main package's sync scripts are 371 to 775 lines each and every one of them carries a bearer token; none of them are here, and no replacement for them belongs here either. A script that scaffolds a file, formats a document or checks a convention is fine. If a workflow genuinely needs the network, it does not belong in this set.

**Every skill stands alone.** No skill here depends on another being installed, on an issue tracker, on an MCP server, or on a knowledge base existing. Where the main set says "run the sync afterwards", these say nothing, because there is nothing to run. Where the main set publishes a story to a tracker, these write a markdown file. A project can take one skill and leave the rest.

## The workflow

The spine is the same as the full package, because it is the part that was already script-free:

**RAD** - work a hard question until it lands on a recommendation. **ADR** - record a decision once it hardens. **PRD** - state what is being built. **Stories** - break it into slices someone can pick up. **TDD** - build each slice test-first.

Around that sit the small tools that make long sessions survivable, and the filing rules that keep documents findable.

## Relationship to the main package

These are a parallel set, not a subset. The same idea often appears in both, worded for a different situation, and the two can drift - a fix in one does not reach the other on its own.

**If you change a skill in `skills/`, check whether its counterpart here needs the same change.** The reverse holds too. Which of the two is right depends on the change: guidance about how to think usually applies to both, guidance about tooling usually applies to only one.

## Contents

| Skill | What it does |
|---|---|
| `to-rad` | Research and development log - options, trade-offs, what failed, a recommendation |
| `to-adr` | Architecture decision record - one hard-to-reverse choice, and what was rejected |
| `to-prd` | Product requirements - what is being built and how anyone would know it works |
| `to-stories` | Break a plan into vertical slices, written to markdown files in the repo |
| `tdd` | Red-green-refactor, one slice at a time |
| `to-wiring` | Feature-to-feature integration rules, kept in `WIRING.md` |
| `to-research` | Capture research so a later reader can tell what was checked from what was assumed |
| `grill-with-docs` | Verify a claim against documentation rather than recollection |
| `project-docs` | Where a document belongs, and the templates - filing only, no sync |
| `handoff` | Compact a session into something another agent can pick up |
| `housekeeping` | End-of-session cleanup and commit preparation |
| `zoom-out` | Step back when the work has lost its shape |
