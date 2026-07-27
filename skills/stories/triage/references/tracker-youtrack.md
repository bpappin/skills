# Tracker Binding: YouTrack (triage)

Connection facts from `.agents/config/story-tools.json`; credentials from
the story-tools installer - never collected in chat.

| Triage operation | YouTrack command |
|---|---|
| Query buckets | `search_issues` - e.g. `project: {KEY} has: -{tag}` for untriaged, `tag: needs-triage`, `tag: needs-info` |
| Read an issue fully | `get_issue` (+ comments) |
| Apply category/state roles | `manage_issue_tags` - the role names ARE the tag names (`bug`, `enhancement`, `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`) |
| Post triage notes / briefs | `add_issue_comment` |
| Put AC into the description | `story_add_ac` per item, or careful `get_issue` → edit → `update_issue` (canonical `## Acceptance Criteria` section) |
| Close (wontfix) | `update_issue` state |

Tags are created on first use; share them with the team in YouTrack so
everyone sees the same triage state. If the team later prefers a custom
"Triage" field over tags, only this table changes.
