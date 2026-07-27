# Token & Permission Requirements

YouTrack permanent tokens carry a *scope* (which service the token may talk
to); what the token can actually do within that scope is governed by the
permissions of the user it belongs to. Follow least privilege: use a
day-to-day token for agents, and a separate admin token only for deploys.

## Day-to-day agent token (the one in youtrack.env)

Create in YouTrack: Profile → Account Security → New token.

| Requirement | Value |
|---|---|
| Token scope | **YouTrack** (only — do not add YouTrack Administration) |
| User permissions in target projects | Read Issue, Create Issue, Update Issue, Link Issues, Apply Command, Add/Use Tags — the standard **Contributor/Developer** role covers all of these |

This is sufficient for every `story_*` tool and the predefined MCP tools.
Custom aiTools run "with the same level of access as the user working with
them", so the token's user must be able to see and edit the issues in the
projects you work in — nothing more.

## Read-only teams

Three enforcement layers, strongest first:

1. **Token from a read-only account** (the hard guarantee). Create a
   dedicated account holding only a read-level role in the relevant projects
   (the built-in Observer role, or a custom role with just Read Issue), and
   issue the agent token from it. MCP tools run with that user's
   permissions, so *every* write — including the predefined
   `create_issue`/`update_issue` tools — fails server-side. See
   [default roles](https://www.jetbrains.com/help/youtrack/cloud/default-roles.html).
2. **App setting** `Read-only mode` (Administration → Apps → Story Tools →
   Settings): the `story_*` write tools refuse and return the proposed
   change so the agent hands it to a human. Instance-wide, admin-controlled.
3. **Project pointer** `"readOnly": true` in `.agents/config/story-tools.json`
   (`install.sh --project <dir> --readonly`): tells skills/agents not to
   attempt writes at all.

Layer 3 is advice, layer 2 governs our tools, layer 1 governs everything —
use layer 1 whenever the policy actually matters.

## Deploy token (scripts/deploy.sh — uploading the app)

Uploading an app requires one of, per JetBrains' quick-start guide:

- **Update Project** permission granted at the global level, or
- **Low-level Admin Write** permission

Scope: YouTrack. In practice this means a system-admin-ish account; keep
this token out of agent env files — deploy.sh accepts it via
`YOUTRACK_API_TOKEN` for the one command that needs it.

## One-time admin setup (web UI, no token)

- Create the directed issue link type **discovered from** (Administration →
  Issue Link Types). Until it exists, `story_add_discovered_work` falls back
  to `relates to` + a `discovered` tag.
- Optionally create the `needs-gherkin` tag.
- After any deploy that adds/renames tools: re-add or re-enable the MCP
  connection in each agent so it re-fetches the tool list.

## Verifying a token

```
curl -s -H "Authorization: Bearer $YOUTRACK_TOKEN" \
  "$YOUTRACK_URL/api/users/me?fields=login" 
```

A 200 with your login means scope + auth are good; a 403 on specific
operations later means missing *project permissions*, not a bad token.
