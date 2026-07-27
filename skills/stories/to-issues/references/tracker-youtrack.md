# Tracker Binding: YouTrack (to-issues)

Connection facts from `.agents/config/story-tools.json` (mcpServer names the
MCP server, project names the YouTrack project). Credentials come from the
story-tools installer - never collected in chat.

| Operation | YouTrack command |
|---|---|
| Create a story | `create_issue` (MCP predefined) in the config's project, body in canonical format |
| Link a blocker | `link_issues` with "depends on" (fallback: note the ID under a "Blocked by" line in the body) |
| Link to a parent issue | `link_issues` "subtask of" when the source was an epic/issue; otherwise reference it in `## References` |
| Tag AFK-ready slices | `manage_issue_tags` → `ready-for-agent` |
| Tag strict-rule slices | `manage_issue_tags` → `needs-gherkin` (gates completion on a `## QA` Gherkin section) |
