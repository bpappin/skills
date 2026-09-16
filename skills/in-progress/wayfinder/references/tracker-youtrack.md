# Tracker Binding: YouTrack (wayfinder)

Connection facts from `.agents/config/story-tools.json` (`mcpServer` names the MCP server, `project` the YouTrack project). Credentials come from the story-tools installer - never collected in chat.

A map needs three things from a tracker: a parent/child relationship, a typed blocking link, and an assignee. YouTrack has all three natively, so nothing here invents a convention.

## Operation map

| Operation | YouTrack command |
|---|---|
| Create the map | `create_issue` in the config's project, body in the map format. Set Type to `Epic` if the project has that value, otherwise leave Type as it lands - **read the project's values first** (`story_project_dimensions`, or `.agents/config/dimensions.md`) and never write one you have not read |
| Create a decision | `create_issue`, body in the decision format, then link it to the map (below) |
| Link a decision to its map | `link_issues` with `subtask of`, child → map. This parent link **is** the grouping; no tag is needed to hold the map together |
| Link a blocker | `link_issues` with `depends on`, blocked → blocker |
| List the map's children | `get_issue` on the map and read its links; the `subtask` side lists every child. Do not guess a search syntax for parentage - the links on the map are the authority |
| Compute the frontier | From those children: open, with every `depends on` target resolved, and no assignee. First in map order wins |
| Claim a decision | `change_issue_assignee` to the driving developer (`get_current_user` for your own account) - the session's first write, before any work |
| Record an answer | `add_issue_comment` on the decision: the answer, and the ID and title of the RAD or ADR it produced |
| Resolve a decision | `update_issue` - Stage/State to the project's resolved values, read from the dimensions as above |
| Update the map | `update_issue` on the map description: append one line to `## Decisions so far`, and clear the graduated patch from `## Not yet specified` |
| Rule out of scope | `update_issue` to resolve the issue, then one line under `## Out of scope` on the map naming why, with the closed issue |
| Group several maps | The **Topical Tags** field, values listed in `.agents/config/dimensions.md`. Reuse one before adding; to add, append a line to `.agents/config/topical-tags.md` and run `story-reconcile/scripts/yt-pull.sh --dimensions-only --push-tags` |

## Editing the map description

The map is one description that several sessions write to, and `update_issue` replaces it whole. Read it immediately before you write, change only the lines you came to change, and re-read to confirm. Never tidy the rest of the description while appending a decision - that is how a concurrent session's line disappears.

## What the reserved tags do and do not mean

Do not tag decisions `ready-for-agent` or `triaged`. Those belong to the story workflow: `ready-for-agent` means an agent can implement and merge it, and a decision is not implementable work. A decision issue is found through its map, not through the story queue.

## Detecting what is available

Check your tool list. No YouTrack tools → the MCP connection is not set up: tell the user once how to connect (`.agents/setup.sh` in a bound project, else the story-tools installer) and never collect credentials yourself. The `story_*` app tools are not required here; this binding uses only YouTrack's built-in MCP tools, so a project without the app can still chart a map.
