#!/usr/bin/env bash
# Smoke-test the MCP endpoint without an agent in the loop:
#   initialize -> tools/list (verifies story_* tools are exposed)
#   optionally: tools/call story_get_focus
#
# Usage: smoke.sh [--call]
set -euo pipefail

if [[ -z "${YOUTRACK_HOST:-}" ]]; then
  candidates=( )
  [[ -n "${YOUTRACK_ENV_FILE:-}" ]] && candidates+=("$YOUTRACK_ENV_FILE")
  conn="${YOUTRACK_CONNECTION:-${YOUTRACK_PROFILE:-}}"
  [[ -n "$conn" ]] && candidates+=("$HOME/.agents/story-tools/connections/$conn.env")
  conns=( "$HOME"/.agents/story-tools/connections/*.env )
  [[ ${#conns[@]} -eq 1 && -f "${conns[0]}" ]] && candidates+=("${conns[0]}")
  for f in "${candidates[@]}"; do
    [[ -f "$f" ]] && { source "$f"; break; }
  done
fi
YOUTRACK_HOST="${YOUTRACK_HOST:-${YOUTRACK_URL:-${YT_HOST:-}}}"
YOUTRACK_API_TOKEN="${YOUTRACK_API_TOKEN:-${YOUTRACK_TOKEN:-${YT_TOKEN:-}}}"
[[ -z "$YOUTRACK_HOST" || -z "$YOUTRACK_API_TOKEN" ]] && { echo "error: missing host/token" >&2; exit 1; }

MCP_URL="${YOUTRACK_HOST%/}/mcp?customToolPackages=story-tools"

rpc() {
  curl -sS -X POST "$MCP_URL" \
    -H "Authorization: Bearer $YOUTRACK_API_TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    ${SESSION_ID:+-H "Mcp-Session-Id: $SESSION_ID"} \
    -d "$1" -D /tmp/mcp-headers.txt
}

echo "== initialize =="
INIT_RESP=$(rpc '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}')
echo "$INIT_RESP" | head -c 400; echo
SESSION_ID=$(grep -i '^mcp-session-id:' /tmp/mcp-headers.txt | awk '{print $2}' | tr -d '\r' || true)

rpc '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null || true

echo "== tools/list (story_* only) =="
rpc '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | grep -o '"name":"[^"]*"' | grep story_ || echo "NO story_* TOOLS FOUND"

if [[ "${1:-}" == "--call" ]]; then
  echo "== tools/call story_get_focus =="
  rpc '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"story_get_focus","arguments":{}}}'
  echo
fi
