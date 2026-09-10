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
  # ${arr[@]+...}: an empty array is "unbound" under set -u before bash 4.4
  for f in ${candidates[@]+"${candidates[@]}"}; do
    # shellcheck disable=SC1090
    [[ -f "$f" ]] && { source "$f"; break; }
  done
fi

# Map common alternative var names from the env file.
YOUTRACK_HOST="${YOUTRACK_HOST:-${YOUTRACK_URL:-${YT_HOST:-}}}"
YOUTRACK_API_TOKEN="${YOUTRACK_API_TOKEN:-${YOUTRACK_TOKEN:-${YT_TOKEN:-}}}"

if [[ -z "$YOUTRACK_HOST" || -z "$YOUTRACK_API_TOKEN" ]]; then
  echo "error: set YOUTRACK_HOST and YOUTRACK_API_TOKEN, or name a connection with YOUTRACK_CONNECTION" >&2
  exit 1
fi
export YOUTRACK_HOST YOUTRACK_API_TOKEN

cd "$SELF_DIR"
# Pinned: unpinned, every deploy took whatever the CLI published last, and the
# 1.x release renamed its subcommands out from under this script. --directory
# is not optional - it defaults to dist, not to the app beside this script.
CLI=(npx --yes --package @jetbrains/youtrack-apps-tools@1.0.3 youtrack-app)
"${CLI[@]}" app validate --directory app
"${CLI[@]}" app upload --directory app

echo
echo "Uploaded. NOTE: if tool names changed, re-add/re-enable the MCP connection"
echo "in your client. Endpoint: ${YOUTRACK_HOST%/}/mcp?customToolPackages=story-tools"
