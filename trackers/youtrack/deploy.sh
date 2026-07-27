#!/usr/bin/env bash
# Validate and upload the story-tools app to YouTrack.
#
# Reads credentials from (first found wins):
#   $YOUTRACK_HOST / $YOUTRACK_API_TOKEN   (native to the youtrack-app CLI)
set -euo pipefail

# This script lives in trackers/youtrack/ next to the app it deploys.
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -z "${YOUTRACK_HOST:-}" ]]; then
  # connection selection: $YOUTRACK_CONNECTION, else the machine's only one
  candidates=( )
  [[ -n "${YOUTRACK_ENV_FILE:-}" ]] && candidates+=("$YOUTRACK_ENV_FILE")
  conn="${YOUTRACK_CONNECTION:-${YOUTRACK_PROFILE:-}}"
  [[ -n "$conn" ]] && candidates+=("$HOME/.agents/story-tools/connections/$conn.env")
  conns=( "$HOME"/.agents/story-tools/connections/*.env )
  [[ ${#conns[@]} -eq 1 && -f "${conns[0]}" ]] && candidates+=("${conns[0]}")
  for f in "${candidates[@]}"; do
    # shellcheck disable=SC1090
    [[ -f "$f" ]] && { source "$f"; break; }
  done
fi

# Map common alternative var names from the env file.
YOUTRACK_HOST="${YOUTRACK_HOST:-${YOUTRACK_URL:-${YT_HOST:-}}}"
YOUTRACK_API_TOKEN="${YOUTRACK_API_TOKEN:-${YOUTRACK_TOKEN:-${YT_TOKEN:-}}}"

if [[ -z "$YOUTRACK_HOST" || -z "$YOUTRACK_API_TOKEN" ]]; then
  echo "error: set YOUTRACK_HOST and YOUTRACK_API_TOKEN (or provide $ENV_FILE)" >&2
  exit 1
fi
export YOUTRACK_HOST YOUTRACK_API_TOKEN

cd "$SELF_DIR"
npx --yes --package @jetbrains/youtrack-apps-tools youtrack-app validate app
npx --yes --package @jetbrains/youtrack-apps-tools youtrack-app upload app

echo
echo "Uploaded. NOTE: if tool names changed, re-add/re-enable the MCP connection"
echo "in your client. Endpoint: ${YOUTRACK_HOST%/}/mcp?customToolPackages=story-tools"
