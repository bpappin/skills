# ADR-0001: YouTrack owns stories and AC; local docs keep decisions and requirements

Date: 2026-07-26 · Status: accepted

## Context

The previous system tracked ADRs, PRDs, per-PRD acceptance criteria, and GAP
files locally, with a "sync" skill mirroring gaps and AC into YouTrack. The
sync was fragile (two sources of truth drifting), the GAP system was hard to
follow, and agent sessions suffered scope creep because current-task scope
was never explicit anywhere.

## Decision

- YouTrack is the single source of truth for stories, acceptance criteria,
  and task status. No local story/AC/GAP files, no sync.
- ADRs and PRDs remain local repo docs. PRDs reference story IDs; stories
  reference ADR/PRD paths in a `## References` section.
- Tooling is a "YouTrack-hosted hybrid": the built-in Cloud MCP server's
  predefined tools for standard operations, plus a custom app (`story-tools`)
  of `aiTool` workflow rules for the workflow-specific operations
  (focus, AC updates, scope-guard, completion gating).
- Agent-agnostic by construction: any MCP client connects to
  `https://<instance>.youtrack.cloud/mcp?customToolPackages=story-tools`.
  Claude gets a thin skill on top; other agents get the same behavior from
  the tool descriptions alone.

## Consequences

- The sync skill is retired; a whole failure class (drift) disappears.
- Open GAP items must be migrated to YouTrack stories once (one-time cost).
- Story/AC edits require YouTrack access; offline work loses task tracking
  (acceptable — code work is the offline activity, not tracking).
- Custom tool logic lives in YouTrack's workflow JS sandbox: limited
  language services, deploy-to-test loop. Mitigated by keeping the parser
  dependency-free and unit-tested locally (`tests/`).
