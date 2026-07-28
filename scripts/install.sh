#!/usr/bin/env bash
# story-tools installer.
#
#   ./install.sh              guided setup / settings review (start here)
#   ./install.sh --user [--connection <name>]
#   ./install.sh --project <dir> [--connection <name>] [--yt-project <KEY>] [--readonly] [--copy]
#   ./install.sh --list | --show | --help
#
# Everything lives under one well-known root:
#   ~/.agents/story-tools/connections/<name>.env   one server + your token for it
#   ~/.agents/skills/                              user-level skills
#   <project>/.agents/                             per-project: skills + pointer (commit it)
# Re-running shows every stored value and lets you change any of them.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS=("$REPO_DIR/skills/stories/story-workflow" "$REPO_DIR/skills/stories/story-reconcile"
        "$REPO_DIR/skills/stories/to-issues" "$REPO_DIR/skills/stories/triage"
        "$REPO_DIR/skills/docs/project-docs" "$REPO_DIR/skills/docs/to-prd" "$REPO_DIR/skills/docs/to-research"
        "$REPO_DIR/skills/docs/grill-with-docs" "$REPO_DIR/skills/docs/regulatory-compliance" "$REPO_DIR/skills/docs/to-wiring"
        "$REPO_DIR/skills/sessions/handoff" "$REPO_DIR/skills/sessions/housekeeping")
AGENTS_HOME="$HOME/.agents"
CONF_DIR="$AGENTS_HOME/story-tools"
CONN_DIR="$CONF_DIR/connections"

say()  { printf '%s\n' "$*"; }
step() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

# one-time migration from older layouts
for old in "$HOME/.config/story-tools" "$CONF_DIR/profiles"; do
  if [[ -d "$old" ]] && ls "$old"/*.env >/dev/null 2>&1; then
    mkdir -p "$CONN_DIR"
    mv -n "$old"/*.env "$CONN_DIR"/ 2>/dev/null || true
  fi
done

name_from_url() { echo "$1" | sed -E 's#https?://##; s#[/:.].*##'; }
list_connections() { ls "$CONN_DIR"/*.env 2>/dev/null | sed -E 's#.*/(.*)\.env#\1#' || true; }

load_connection() {  # $1 = name; sets YOUTRACK_URL/TOKEN/PROJECT
  local f="$CONN_DIR/$1.env"
  [[ -f "$f" ]] || return 1
  # shellcheck disable=SC1090
  source "$f"
  [[ -n "${YOUTRACK_URL:-}" && -n "${YOUTRACK_TOKEN:-}" ]]
}

save_connection() {  # $1 name
  umask 077; mkdir -p "$CONN_DIR"
  { echo "YOUTRACK_URL=${YOUTRACK_URL%/}"
    echo "YOUTRACK_TOKEN=$YOUTRACK_TOKEN"
    echo "MCP_SERVER=${MCP_SERVER:-youtrack}"
    [[ -n "${YOUTRACK_PROJECT:-}" ]] && echo "YOUTRACK_PROJECT=$YOUTRACK_PROJECT"
  } > "$CONN_DIR/$1.env"
  chmod 600 "$CONN_DIR/$1.env"
}

resolve_server() {  # always youtrack-<nickname>: explicit per server, no cross-pollination
  MCP_SERVER="youtrack-$PROFILE"
}

ask() {  # ask "prompt" "current" -> echoes answer (Enter keeps current)
  local v
  read -rp "  $1${2:+ [$2]}: " v
  echo "${v:-$2}"
}

verify_token() {  # $1 url, $2 token -> echoes login or fails
  curl -sfS -m 10 -H "Authorization: Bearer $2" "$1/api/users/me?fields=login" 2>/dev/null \
    | sed -E 's/.*"login":"([^"]*)".*/\1/'
}

yt() {  # yt METHOD PATH [JSON] -> body on stdout; fails on HTTP error
  local method="$1" path="$2" data="${3:-}"
  curl -sfS -m 15 -X "$method" "${YOUTRACK_URL%/}$path" \
    -H "Authorization: Bearer $YOUTRACK_TOKEN" -H "Content-Type: application/json" \
    ${data:+-d "$data"}
}

check_app() {  # sets APP_CHECK = installed | missing | unauthorized | unreachable
  local code body
  body="$(mktemp)"
  code=$(curl -sS --max-time 20 --http1.1 -o "$body" -w "%{http_code}" \
    -X POST "${YOUTRACK_URL%/}/mcp?customToolPackages=story-tools" \
    -H "Authorization: Bearer $YOUTRACK_TOKEN" -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' 2>/dev/null) || code="000"
  APP_VERSION=""
  if grep -q '"story_' "$body"; then
    APP_CHECK="installed"
    APP_VERSION=$(grep -o 'story-tools v[0-9][0-9.]*' "$body" | head -1 | sed 's/story-tools v//')
  elif [[ "$code" == "401" || "$code" == "403" ]]; then APP_CHECK="unauthorized"
  elif [[ "$code" == "200" ]]; then APP_CHECK="missing"
  else APP_CHECK="unreachable"
  fi
  rm -f "$body"
}

merge_json() {  # <file> <dot.path> <json-value>
  command -v node >/dev/null || { say "error: node is required" >&2; exit 1; }
  mkdir -p "$(dirname "$1")"
  node -e '
    const fs = require("fs");
    const [file, path, value] = process.argv.slice(1);
    let root = {};
    if (fs.existsSync(file)) { const raw = fs.readFileSync(file, "utf8").trim(); if (raw) root = JSON.parse(raw); }
    let n = root;
    const keys = path.split(".");
    for (const k of keys.slice(0, -1)) n = n[k] = n[k] || {};
    n[keys[keys.length - 1]] = JSON.parse(value);
    fs.writeFileSync(file, JSON.stringify(root, null, 2) + "\n", {mode: 0o600});
  ' "$1" "$2" "$3"
}

read_pointer() {  # $1 dir, $2 key -> value or empty
  local f="$1/.agents/config/story-tools.json"
  [[ -f "$f" ]] || f="$1/.agents/youtrack.json"   # pre-rename location
  [[ -f "$f" ]] || return 0
  sed -nE 's/.*"'"$2"'": *"?([^",}]+)"?.*/\1/p' "$f" | head -1
}

# ---------- step: credentials (create or review) ----------

setup_connection() {  # $1 = optional preselected name; sets PROFILE + creds vars
  PROFILE="${1:-}"
  local existing; existing="$(list_connections)"

  if [[ -n "$PROFILE" ]]; then
    say "  This project is bound to connection '$PROFILE'."
    PROFILE="$(ask "Use which connection? (name, or 'new' for another server)" "$PROFILE")"
  elif [[ -n "$existing" ]]; then
    say "  Existing connections: $(echo "$existing" | tr '\n' ' ')"
    local n; n="$(echo "$existing" | head -1)"
    PROFILE="$(ask "Use which connection? (name, or 'new' to add another server)" "$n")"
  fi
  [[ "$PROFILE" == "new" ]] && PROFILE=""

  local cur_url="${PRE_URL:-}" cur_project="" have_token=""
  if [[ -n "$PROFILE" ]] && load_connection "$PROFILE"; then
    cur_url="$YOUTRACK_URL"; cur_project="${YOUTRACK_PROJECT:-}"; have_token="yes"
  fi

  YOUTRACK_URL="$(ask "Full YouTrack URL (e.g. https://yt.example.com or https://acme.youtrack.cloud)" "$cur_url")"
  [[ -n "$YOUTRACK_URL" ]] || { say "error: URL is required" >&2; exit 1; }

  # a different URL is a different server: NEVER overwrite the reviewed connection
  if [[ -n "$PROFILE" && -n "$cur_url" && "${YOUTRACK_URL%/}" != "${cur_url%/}" ]]; then
    say "  That's a different server than connection '$PROFILE' ($cur_url) -"
    say "  creating a NEW connection for it ('$PROFILE' is left untouched)."
    PROFILE=""; have_token=""; unset YOUTRACK_TOKEN MCP_SERVER YOUTRACK_PROJECT
  fi

  say "  Token: YouTrack > Profile > Account Security > New token."
  say "  REQUIRED SCOPE: \"YouTrack\" only (not YouTrack Administration)."
  say "  Your account needs Contributor-level permissions in the projects you work in."
  say "  (Deploying the story-tools app is separate and needs an admin token.)"
  local t
  read -rsp "  Token${have_token:+ [Enter = keep current]} (input hidden): " t; echo
  [[ -n "$t" ]] && YOUTRACK_TOKEN="$t"
  [[ -n "${YOUTRACK_TOKEN:-}" ]] || { say "error: token is required" >&2; exit 1; }

  local login
  if login="$(verify_token "${YOUTRACK_URL%/}" "$YOUTRACK_TOKEN")" && [[ -n "$login" ]]; then
    ok "token verified - authenticated as '$login'"
  else
    say "  error: could not authenticate against ${YOUTRACK_URL} - check URL and token." >&2
    exit 1
  fi

  local newname suggested
  suggested="${PROFILE:-$(name_from_url "$YOUTRACK_URL")}"
  while :; do
    newname="$(ask "Connection nickname (this server + your token; shared by every repo that uses it)" "$suggested")"
    # never silently replace a DIFFERENT server's connection that happens to share the name
    if [[ "$newname" != "$PROFILE" && -f "$CONN_DIR/$newname.env" ]]; then
      local other_url; other_url="$(sed -n 's/^YOUTRACK_URL=//p' "$CONN_DIR/$newname.env")"
      if [[ "${other_url%/}" != "${YOUTRACK_URL%/}" ]]; then
        local yn; yn="$(ask "Connection '$newname' already exists for $other_url. Replace it with this server? (y/N)" "n")"
        [[ "$yn" =~ ^[Yy]$ ]] || { suggested=""; continue; }
      fi
    fi
    break
  done
  if [[ -n "$PROFILE" && "$newname" != "$PROFILE" && -f "$CONN_DIR/$PROFILE.env" ]]; then
    rm -f "$CONN_DIR/$PROFILE.env"
    warn "connection renamed '$PROFILE' -> '$newname' (old agent entries are inert)"
  fi
  PROFILE="$newname"
  resolve_server

  save_connection "$PROFILE"
  ok "connection saved: $CONN_DIR/$PROFILE.env (chmod 600)"
}

# ---------- step: server setup (app + link type + tag) ----------

offer_deploy() {  # $1 = reason line already printed by caller
  [[ -f "$REPO_DIR/trackers/youtrack/app/manifest.json" ]] || return 0
  local yn; yn="$(ask "Deploy the app now with this token? (needs admin permission) y/N" "n")"
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    if YOUTRACK_HOST="${YOUTRACK_URL%/}" YOUTRACK_API_TOKEN="$YOUTRACK_TOKEN" "$REPO_DIR/trackers/youtrack/deploy.sh"; then
      ok "app deployed"
    else
      warn "deploy failed - see the output above for the actual cause"
      say "  If it mentions 403/permissions: the token lacks global Update Project /"
      say "  Low-level Admin Write - ask a YouTrack admin to run trackers/youtrack/deploy.sh."
    fi
  else
    say "  An admin can deploy later: cd $REPO_DIR && ./trackers/youtrack/deploy.sh"
  fi
}

setup_server() {
  local repo_ver=""
  [[ -f "$REPO_DIR/trackers/youtrack/app/manifest.json" ]] && \
    repo_ver=$(sed -nE 's/.*"version": *"([^"]+)".*/\1/p' "$REPO_DIR/trackers/youtrack/app/manifest.json" | head -1)
  check_app
  case "$APP_CHECK" in
    installed)
      if [[ -n "$APP_VERSION" && "$APP_VERSION" == "$repo_ver" ]]; then
        ok "story-tools app v$APP_VERSION installed - up to date with this repo"
      elif [[ -n "$APP_VERSION" ]]; then
        warn "story-tools app v$APP_VERSION installed; this repo has v$repo_ver"
        offer_deploy
      else
        warn "story-tools app installed, version unknown (predates v0.3.1); repo has v$repo_ver"
        offer_deploy
      fi;;
    unauthorized)
      warn "the token authenticates but cannot reach the MCP endpoint (HTTP 401/403)"
      say "  Check the token scope is \"YouTrack\" - then re-run this setup.";;
    unreachable)
      warn "could not verify the MCP endpoint (network/timeout) - skipping the app check"
      say "  Verify later with: cd $REPO_DIR && ./trackers/youtrack/smoke.sh";;
    missing)
      warn "MCP endpoint reachable, but the story-tools app is not installed"
      say "  The skills still work (fallback mode, built-in tools only)."
      offer_deploy;;
  esac

  # 'discovered from' link type - create if missing (status-aware)
  local lt
  if lt="$(yt GET "/api/issueLinkTypes?fields=sourceToTarget" 2>/dev/null)"; then
    if grep -qi "discovered from" <<<"$lt"; then
      ok "link type 'discovered from' exists"
    elif yt POST "/api/issueLinkTypes?fields=id" \
        '{"name":"Discovery","sourceToTarget":"discovered from","targetToSource":"discovered","directed":true}' >/dev/null 2>&1; then
      ok "link type 'discovered from' created"
    else
      warn "could not create link type 'discovered from' (needs admin) - until it exists, discovered work links as 'relates to' + tag"
    fi
  else
    warn "could not read link types (check token scope) - skipped link-type setup"
  fi

  # Workflow tags - create the full reserved set if missing, shared with
  # All Users where the token allows (a tag created ad hoc by one account
  # is otherwise invisible to teammates).
  local tags wf_tag created=0 shared=0
  if tags="$(yt GET "/api/tags?fields=name&\$top=500" 2>/dev/null)"; then
    local all_users_id
    all_users_id="$(yt GET "/api/groups?fields=id,name&\$top=50" 2>/dev/null \
      | python3 -c 'import json,sys; gs=json.load(sys.stdin); print(next((g["id"] for g in gs if g.get("name")=="All Users"),""))' 2>/dev/null || true)"
    for wf_tag in needs-triage needs-info ready-for-agent ready-for-human \
                  wontfix triaged discovered needs-gherkin; do
      if grep -q "\"$wf_tag\"" <<<"$tags"; then
        continue
      fi
      local body="{\"name\":\"$wf_tag\"}"
      if [[ -n "$all_users_id" ]]; then
        body="{\"name\":\"$wf_tag\",\"readSharingSettings\":{\"permittedGroups\":[{\"id\":\"$all_users_id\"}]},\"updateSharingSettings\":{\"permittedGroups\":[{\"id\":\"$all_users_id\"}]}}"
      fi
      if yt POST "/api/tags?fields=id" "$body" >/dev/null 2>&1; then
        created=$((created+1)); [[ -n "$all_users_id" ]] && shared=$((shared+1))
      elif yt POST "/api/tags?fields=id" "{\"name\":\"$wf_tag\"}" >/dev/null 2>&1; then
        created=$((created+1))
      else
        warn "could not create tag '$wf_tag' - create it in YouTrack before the workflow first needs it"
      fi
    done
    if [[ "$created" -gt 0 ]]; then
      if [[ "$shared" -gt 0 ]]; then
        ok "workflow tags created ($created) and shared with All Users"
      else
        ok "workflow tags created ($created) - owned by your account; share them if teammates will use them"
      fi
    else
      ok "workflow tags all present"
    fi
  else
    warn "could not read tags (check token scope) - skipped tag setup"
  fi
}

# ---------- step: agent registration ----------

register_agents() {
  resolve_server
  local server="$MCP_SERVER" mcp_url="${YOUTRACK_URL%/}/mcp?customToolPackages=story-tools"
  local auth="Bearer $YOUTRACK_TOKEN" found=0

  if command -v claude >/dev/null; then
    claude mcp remove --scope user "$server" >/dev/null 2>&1 || true
    claude mcp remove --scope user "youtrack" >/dev/null 2>&1 || true   # pre-nickname-era entry
    claude mcp add --scope user --transport http "$server" "$mcp_url" \
      --header "Authorization: $auth" >/dev/null \
      && ok "Claude Code: '$server' (user scope)" && found=1 \
      || warn "Claude Code registration failed - run 'claude mcp add' manually"
  fi

  if [[ -d "$HOME/.gemini" ]] || command -v gemini >/dev/null; then
    merge_json "$HOME/.gemini/settings.json" "mcpServers.$server" \
      '{"httpUrl":"'"$mcp_url"'","headers":{"Authorization":"'"$auth"'"}}'
    ok "Gemini CLI: ~/.gemini/settings.json"; found=1
  fi

  local vsc=""
  case "$(uname -s)" in
    Darwin) vsc="$HOME/Library/Application Support/Code/User";;
    Linux)  vsc="$HOME/.config/Code/User";;
  esac
  if [[ -n "$vsc" && -d "$vsc" ]]; then
    merge_json "$vsc/mcp.json" "servers.$server" \
      '{"type":"http","url":"'"$mcp_url"'","headers":{"Authorization":"'"$auth"'"}}'
    ok "VS Code / Copilot: user mcp.json"; found=1
  fi

  if [[ -d "$HOME/.copilot" ]] || command -v copilot >/dev/null; then
    merge_json "$HOME/.copilot/mcp-config.json" "mcpServers.$server" \
      '{"type":"http","url":"'"$mcp_url"'","headers":{"Authorization":"'"$auth"'"}}'
    ok "Copilot CLI: ~/.copilot/mcp-config.json"; found=1
  fi

  if [[ -d "$HOME/.codex" ]] || command -v codex >/dev/null; then
    local toml="$HOME/.codex/config.toml"; mkdir -p "$HOME/.codex"
    if [[ -f "$toml" ]] && grep -q "^\[mcp_servers\.$server\]" "$toml"; then
      ok "Codex: already configured (edit $toml to rotate the token)"
    else
      printf '\n[mcp_servers.%s]\ncommand = "npx"\nargs = ["-y", "mcp-remote", "%s", "--header", "Authorization:${AUTH_HEADER}"]\nenv = { "AUTH_HEADER" = "%s" }\n' \
        "$server" "$mcp_url" "$auth" >> "$toml"
      chmod 600 "$toml"
      ok "Codex: ~/.codex/config.toml"
    fi
    found=1
  fi
  [[ "$found" == 0 ]] && warn "no supported agents detected on this machine - MCP endpoint: $mcp_url"

  for base in "$AGENTS_HOME/skills" "$HOME/.claude/skills"; do
    mkdir -p "$base"
    for s in "${SKILLS[@]}"; do rm -rf "$base/$(basename "$s")"; cp -R "$s" "$base/"; done
  done
  ok "skills (user-level): ~/.agents/skills + ~/.claude/skills"
  say "  Agents already running need a restart / MCP reload to pick this up."
}

# ---------- step: project binding (project-attached mode) ----------

attach_project() {  # $1 dir, $2 yt_project, $3 readonly(true|""), $4 mode
  local dir="$1" yt_project="$2" readonly_flag="$3" mode="${4:-link}"
  mkdir -p "$dir/.agents/skills"
  for s in "${SKILLS[@]}"; do
    local name; name="$(basename "$s")"
    rm -rf "$dir/.agents/skills/$name"
    cp -R "$s" "$dir/.agents/skills/$name"
    for agent_dir in .claude .github; do
      mkdir -p "$dir/$agent_dir/skills"
      rm -rf "$dir/$agent_dir/skills/$name"
      if [[ "$mode" == "copy" ]]; then cp -R "$s" "$dir/$agent_dir/skills/$name"
      else ln -s "../../.agents/skills/$name" "$dir/$agent_dir/skills/$name"; fi
    done
  done
  ok "skills attached: .agents/skills (+ .claude/.github symlinks)"

  rm -f "$dir/.agents/youtrack.json" "$dir/.agents/config/story-tools.json"   # regenerate cleanly
  merge_json "$dir/.agents/config/story-tools.json" "tracker" '{
    "type": "youtrack",
    "connection": "'"$PROFILE"'",
    "mcpServer": "'"${MCP_SERVER:-youtrack}"'",
    "url": "'"${YOUTRACK_URL%/}"'"'"${yt_project:+,
    \"project\": \"$yt_project\"}${readonly_flag:+,
    \"readOnly\": true}"'
  }'
  ok "pointer: .agents/config/story-tools.json - commit .agents/ .claude/ .github/ with the repo"
}

pick_project() {  # sets PROJECT_DIR/PROJECT_NAME (may be empty = user-level only)
  PROJECT_DIR=""; PROJECT_NAME=""
  local recent=""; [[ -f "$CONF_DIR/recent-projects" ]] && recent="$(head -1 "$CONF_DIR/recent-projects")"
  local dir; dir="$(ask "Project repo to set up (path; Enter for user-level setup only)" "$recent")"
  [[ -z "$dir" ]] && { say "  user-level setup only - bind a project later with --project <dir>"; return; }
  dir="${dir/#\~/$HOME}"
  [[ -d "$dir" ]] || { warn "$dir is not a directory - continuing with user-level setup only"; return; }
  PROJECT_DIR="$(cd "$dir" && pwd)"
  PROJECT_NAME="$(basename "$PROJECT_DIR")"
  ok "project: $PROJECT_NAME ($PROJECT_DIR)"
  if [[ -f "$PROJECT_DIR/.agents/config/story-tools.json" || -f "$PROJECT_DIR/.agents/youtrack.json" ]]; then
    say "  existing story-tools config found - its values prefill the next steps"
  fi
}

enable_time_tracking() {  # $1 = YouTrack project key; best-effort, never fatal
  local key="$1" pid settings enabled est spent
  pid=$(curl -sS -m 15 -H "Authorization: Bearer $YOUTRACK_TOKEN" \
      "${YOUTRACK_URL%/}/api/admin/projects?fields=id,shortName&query=$key" 2>/dev/null \
    | sed -nE 's/.*\{"id":"([^"]+)","shortName":"'"$key"'".*/\1/p' | head -1)
  # tolerate field-order differences
  [[ -z "$pid" ]] && pid=$(curl -sS -m 15 -H "Authorization: Bearer $YOUTRACK_TOKEN" \
      "${YOUTRACK_URL%/}/api/admin/projects?fields=shortName,id&query=$key" 2>/dev/null \
    | sed -nE 's/.*"shortName":"'"$key"'","id":"([^"]+)".*/\1/p' | head -1)
  if [[ -z "$pid" ]]; then
    say "  time tracking: could not look up project $key (needs admin read) - enable it"
    say "  manually if you want spent-time logging: Project Settings > Time Tracking."
    return 0
  fi
  settings=$(curl -sS -m 15 -H "Authorization: Bearer $YOUTRACK_TOKEN" \
      "${YOUTRACK_URL%/}/api/admin/projects/$pid/timeTrackingSettings?fields=enabled,estimate(field(name)),timeSpent(field(name))" 2>/dev/null)
  if [[ "$settings" == *'"enabled":true'* ]]; then
    say "  time tracking: already enabled on $key"
  else
    local code
    code=$(curl -sS -m 15 -o /dev/null -w "%{http_code}" -X POST \
      -H "Authorization: Bearer $YOUTRACK_TOKEN" -H "Content-Type: application/json" \
      -d '{"enabled":true}' \
      "${YOUTRACK_URL%/}/api/admin/projects/$pid/timeTrackingSettings?fields=enabled" 2>/dev/null)
    if [[ "$code" == 200 ]]; then
      say "  time tracking: enabled on $key (story_log_work records session time)"
    else
      say "  time tracking: could not enable on $key (HTTP $code - usually needs project"
      say "  admin). Enable manually: Project Settings > Time Tracking. Skipping."
      return 0
    fi
    settings=$(curl -sS -m 15 -H "Authorization: Bearer $YOUTRACK_TOKEN" \
      "${YOUTRACK_URL%/}/api/admin/projects/$pid/timeTrackingSettings?fields=enabled,estimate(field(name)),timeSpent(field(name))" 2>/dev/null)
  fi
  [[ "$settings" != *'"estimate":{"field"'* ]] && \
    say "  note: no Estimation field attached yet - add one under Project Settings >"
  [[ "$settings" != *'"estimate":{"field"'* ]] && \
    say "  Time Tracking if you want estimates on stories (the to-issues skill sets them)."
  return 0
}

bind_project_interactive() {  # uses PROJECT_DIR/PROJECT_NAME from pick_project
  [[ -z "$PROJECT_DIR" ]] && { say "  no project selected - skipped"; return; }
  # collision check: already bound to a DIFFERENT connection?
  local bound_conn bound_url
  bound_conn="$(read_pointer "$PROJECT_DIR" connection)"
  [[ -z "$bound_conn" ]] && bound_conn="$(read_pointer "$PROJECT_DIR" profile)"
  bound_url="$(read_pointer "$PROJECT_DIR" url)"
  if [[ -n "$bound_conn" && "$bound_conn" != "$PROFILE" ]]; then
    warn "'$PROJECT_NAME' is currently bound to connection '$bound_conn'${bound_url:+ ($bound_url)}"
    local yn; yn="$(ask "Rebind it to '$PROFILE' (${YOUTRACK_URL%/})? (y/N)" "n")"
    [[ "$yn" =~ ^[Yy]$ ]] || { say "  binding left unchanged - re-run and pick connection '$bound_conn' to update it"; return; }
  fi
  local cur_key cur_ro yt_project ro
  cur_key="$(read_pointer "$PROJECT_DIR" project)"; cur_key="${cur_key:-${YOUTRACK_PROJECT:-}}"
  cur_ro="$(read_pointer "$PROJECT_DIR" readOnly)"
  yt_project="$(ask "Project ID in YouTrack for '$PROJECT_NAME' (short key, e.g. EVO)" "$cur_key")"
  BOUND_KEY="$yt_project"
  ro="$(ask "Read-only? Agents propose changes but never write (y/N)" "${cur_ro:+y}")"
  [[ "$ro" =~ ^[Yy] ]] && ro="true" || ro=""
  attach_project "$PROJECT_DIR" "$yt_project" "$ro" link
  enable_time_tracking "$yt_project"
  # remember for next run (most recent first, deduped)
  mkdir -p "$CONF_DIR"
  { echo "$PROJECT_DIR"; grep -vxF "$PROJECT_DIR" "$CONF_DIR/recent-projects" 2>/dev/null || true; } \
    > "$CONF_DIR/recent-projects.tmp" && mv "$CONF_DIR/recent-projects.tmp" "$CONF_DIR/recent-projects"
}

# ---------- flows ----------

wizard() {
  say "story-tools setup - credentials, server, agents, project. Re-run any time:"
  say "current values are shown in [brackets]; Enter keeps them. No secrets ever"
  say "land in a repo."
  step "1/4 Project"
  pick_project
  local pre_profile=""
  if [[ -n "$PROJECT_DIR" ]]; then
    pre_profile="$(read_pointer "$PROJECT_DIR" connection)"
    [[ -z "$pre_profile" ]] && pre_profile="$(read_pointer "$PROJECT_DIR" profile)"
    PRE_URL="$(read_pointer "$PROJECT_DIR" url)"
  fi
  step "2/4 YouTrack connection (server + your token)"; setup_connection "$pre_profile"
  step "3/4 Server setup";           setup_server
  step "4/4 Agent registration";     register_agents
  [[ -n "$PROJECT_DIR" ]] && { step "Attach to $PROJECT_NAME"; bind_project_interactive; }
  step "Done - next steps"
  if [[ -n "$PROJECT_DIR" ]]; then
    say "  1. Commit the setup so teammates inherit it:"
    say "       cd $PROJECT_DIR && git add .agents .claude .github && git commit -m 'story-tools'"
    say "  2. Restart your agentic coding environment (Claude Code, Gemini CLI,"
    say "     VS Code/Copilot, Codex ...) so it loads the '$MCP_SERVER' MCP server"
    say "     and the project skills."
    say "  3. The skills, in the order most existing projects use them:"
    say ""
    say "     project-docs     \"where should this doc go\" / \"sync the docs\""
    say "                      (two-way sync with the tracker knowledge base)"
    say "     story-reconcile  \"reconcile the gaps with the tracker\""
    say "                      (migrates legacy GAP/AC files into stories, in approved batches)"
    say "     story-workflow   \"work on ${BOUND_KEY:-ABC}-123\" / \"what am I working on?\""
    say "                      \"that's done, check it off\" / \"is this story done?\""
    say ""
    say "     Also installed: to-prd, to-issues, to-research, triage, grill-with-docs,"
    say "     to-wiring, regulatory-compliance, handoff, housekeeping."
  else
    say "  1. Restart your agentic coding environment so it loads the '$MCP_SERVER' MCP server."
    say "  2. Bind a repo when ready: ./scripts/install.sh --project <dir>"
  fi
  say ""
  show
}

user_mode() {
  local profile="${1:-}"
  if [[ -n "$profile" ]] && load_connection "$profile"; then
    PROFILE="$profile"
  else
    setup_connection "$profile"
  fi
  register_agents
}

project_mode() {
  local dir="" profile="" mode="link" yt_project="" readonly_flag=""
  dir="$(cd "$1" && pwd)"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --connection|--profile) profile="$2"; shift 2;;
      --yt-project) yt_project="$2"; shift 2;;
      --readonly) readonly_flag="true"; shift;;
      --copy) mode="copy"; shift;;
      *) say "unknown option: $1" >&2; exit 1;;
    esac
  done
  if [[ -z "$profile" ]]; then
    profile="$(read_pointer "$dir" connection)"
    [[ -z "$profile" ]] && profile="$(read_pointer "$dir" profile)"
    if [[ -z "$profile" ]]; then
      local profiles; profiles="$(list_connections)"
      if [[ "$(echo "$profiles" | grep -c .)" == "1" ]]; then profile="$profiles"
      else say "Pick an instance with --profile <name>. Configured:"; say "${profiles:-  (none - run ./scripts/install.sh first)}"; exit 1; fi
    fi
  fi
  load_connection "$profile" || { say "error: connection '$profile' not found - run ./scripts/install.sh" >&2; exit 1; }
  PROFILE="$profile"
  resolve_server
  local prev; prev="$(read_pointer "$dir" connection)"; [[ -z "$prev" ]] && prev="$(read_pointer "$dir" profile)"
  [[ -n "$prev" && "$prev" != "$PROFILE" ]] && warn "rebinding: this project was bound to connection '$prev', now '$PROFILE'"
  [[ -z "$yt_project" ]] && yt_project="$(read_pointer "$dir" project)"
  [[ -z "$yt_project" ]] && yt_project="${YOUTRACK_PROJECT:-}"
  attach_project "$dir" "$yt_project" "$readonly_flag" "$mode"
}

show() {
  cat <<EOF
Where everything lives:
  Connections:      $CONN_DIR/<name>.env  (one server + your token, chmod 600)
  User skills:      ~/.agents/skills (+ ~/.claude/skills copy)
  Per project:      <repo>/.agents/skills + <repo>/.agents/config/story-tools.json (committed;
                    .claude/ and .github/ symlink into .agents/ - the project carries
                    its own workflow, teammates only ever run this installer once)
  Agent MCP config: each agent's own user config (claude mcp / gemini settings /
                    VS Code mcp.json / copilot mcp-config / codex config.toml)
EOF
}

case "${1:-}" in
  "") if [[ -t 0 ]]; then wizard; else sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; fi;;
  --setup) wizard;;
  --user) shift; profile=""; [[ "${1:-}" == "--connection" || "${1:-}" == "--profile" ]] && profile="$2"; user_mode "$profile";;
  --project) shift; [[ $# -ge 1 ]] || { say "usage: install.sh --project <dir> [--connection <name>] [--yt-project <KEY>] [--readonly] [--copy]" >&2; exit 1; }; project_mode "$@";;
  --list) list_connections;;
  --show) show;;
  --help|-h|*) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//';;
esac
