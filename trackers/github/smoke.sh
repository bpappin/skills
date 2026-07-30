#!/usr/bin/env bash
# Live smoke test for the GitHub tracker binding. Run on a developer
# machine (needs network + a real PAT). Creates ONE scratch issue in the
# target repo, exercises the whole surface, closes it as not planned.
#
# Usage: smoke.sh owner/repo PROJECT_NUMBER [--keep]
#   --keep   leave the scratch issue open (default: close at the end)
#
# Token: $GITHUB_TOKEN, else `gh auth token`, else the story-tools
# github.env connection.
set -uo pipefail   # NOT -e: we want to reach the summary on failures

REPO="${1:-}"; PROJ="${2:-}"; KEEP=0
[[ "${3:-}" == "--keep" ]] && KEEP=1
[[ -n "$REPO" && -n "$PROJ" ]] || { echo "usage: smoke.sh owner/repo PROJECT_NUMBER [--keep]" >&2; exit 1; }
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"; REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
STAGE="$REPO_ROOT/skills/stories/story-workflow/scripts/gh-stage.sh"
PULL="$REPO_ROOT/skills/stories/story-reconcile/scripts/gh-pull.sh"
[[ -x "$STAGE" ]] || STAGE="$REPO_ROOT/skills/story-workflow/scripts/gh-stage.sh"
[[ -x "$PULL" ]] || PULL="$REPO_ROOT/skills/story-reconcile/scripts/gh-pull.sh"

CONN="$(sed -nE 's/.*"connection": *"([^"]+)".*/\1/p' ./.agents/config/story-tools.json 2>/dev/null | head -1)"
if [[ -z "${GITHUB_TOKEN:-}" && -n "$CONN" && -f "$HOME/.agents/story-tools/connections/$CONN.env" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.agents/story-tools/connections/$CONN.env"
fi
if [[ -z "${GITHUB_TOKEN:-}" && -f "$HOME/.agents/story-tools/connections/github.env" ]]; then
  # shellcheck disable=SC1091
  source "$HOME/.agents/story-tools/connections/github.env"
fi
if [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1; then
  GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"
fi
[[ -n "${GITHUB_TOKEN:-}" ]] || { echo "FAIL: no GitHub token" >&2; exit 1; }
export GITHUB_TOKEN

PASS=0; FAILN=0
ok()   { echo "  PASS: $*"; PASS=$((PASS+1)); }
fail() { echo "  FAIL: $*"; FAILN=$((FAILN+1)); }
api()  { curl -sfS -m 20 -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

echo "== 1. token"
LOGIN=$(api https://api.github.com/user | python3 -c 'import json,sys; print(json.load(sys.stdin).get("login",""))' 2>/dev/null)
[[ -n "$LOGIN" ]] && ok "authenticated as $LOGIN" || fail "token rejected"
SCOPES=$(curl -sI -m 20 -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user | tr -d '\r' | sed -nE 's/^[Xx]-[Oo][Aa]uth-[Ss]copes: *(.*)$/\1/p')
case "$SCOPES" in
  *repo*project*|*project*repo*) ok "scopes: $SCOPES";;
  "") echo "  NOTE: no scopes header = fine-grained token; fine with org-owned projects";;
  *) fail "scopes missing repo and/or project: '$SCOPES'";;
esac

echo "== 2. scratch issue"
NUM=$(api -X POST "https://api.github.com/repos/$REPO/issues" -d '{
  "title": "story-tools smoke test (safe to close)",
  "body": "Smoke test issue.\n\n## Acceptance Criteria\n- [ ] smoke item one\n- [x] smoke item two\n"
}' | python3 -c 'import json,sys; print(json.load(sys.stdin).get("number",""))' 2>/dev/null)
[[ -n "$NUM" ]] && ok "created issue #$NUM in $REPO" || { fail "could not create issue (repo scope? SSO authorized?)"; NUM=""; }

if [[ -n "$NUM" ]]; then
  echo "== 3. stage: dry-run, add-to-board, move"
  "$STAGE" "$NUM" "__nonexistent__" --repo "$REPO" --gh-project "$PROJ" --dry-run >/dev/null 2>/tmp/gh-smoke-cols \
    && fail "nonexistent column accepted" \
    || { COLS=$(sed -nE 's/.*Available: (.*)/\1/p' /tmp/gh-smoke-cols); [[ -n "$COLS" ]] && ok "columns listed: $COLS" || fail "no column listing: $(cat /tmp/gh-smoke-cols)"; }
  FIRST=$(echo "${COLS:-}" | cut -d, -f1 | sed 's/^ *//;s/ *$//')
  SECOND=$(echo "${COLS:-}" | cut -d, -f2 | sed 's/^ *//;s/ *$//')
  if [[ -n "$FIRST" ]]; then
    "$STAGE" "$NUM" "$FIRST" --repo "$REPO" --gh-project "$PROJ" >/dev/null 2>&1 \
      && ok "added to board -> $FIRST" || fail "stage to '$FIRST' failed"
    if [[ -n "$SECOND" ]]; then
      "$STAGE" "$NUM" "$SECOND" --repo "$REPO" --gh-project "$PROJ" >/dev/null 2>&1 \
        && ok "moved -> $SECOND" || fail "move to '$SECOND' failed"
    fi
  fi

  echo "== 4. pull snapshot + dimensions"
  TDIR=$(mktemp -d "${TMPDIR:-/tmp}/ghsmoke-XXXXXX")
  mkdir -p "$TDIR/docs/stories"
  ( cd "$TDIR" && printf '{"tracker":{"type":"github","repo":"%s","project":"%s"}}' "$REPO" "$PROJ" \
      > pointer.json && mkdir -p .agents/config && mv pointer.json .agents/config/story-tools.json \
      && "$PULL" "$REPO" docs/stories ) >/dev/null 2>/tmp/gh-smoke-pull || fail "gh-pull failed: $(tail -2 /tmp/gh-smoke-pull)"
  SNAP=$(ls "$TDIR/docs/stories/" 2>/dev/null | grep -c "_") ; DIMS="$TDIR/docs/dimensions.md"
  [[ "${SNAP:-0}" -gt 0 ]] && ok "snapshot files: $SNAP" || fail "no snapshot files"
  if [[ -f "$DIMS" ]]; then
    grep -q "Status (Project field)" "$DIMS" && ok "dimensions.md has Status columns" || fail "dimensions.md missing Status field"
  else fail "no dimensions.md"; fi
  if [[ -n "${SECOND:-}" ]]; then
    grep -rl "state: \"$SECOND\"" "$TDIR/docs/stories/" >/dev/null 2>&1 \
      && ok "snapshot reflects board column '$SECOND'" || fail "snapshot state doesn't show '$SECOND'"
  fi

  echo "== 5. issues-only degradation"
  ( cd /tmp && "$STAGE" "$NUM" "Done" --repo "$REPO" ) >/dev/null 2>&1
  [[ $? -eq 3 ]] && ok "no-project mode exits 3 (graceful)" || fail "no-project mode should exit 3"

  if [[ "$KEEP" != 1 ]]; then
    api -X PATCH "https://api.github.com/repos/$REPO/issues/$NUM" \
      -d '{"state":"closed","state_reason":"not_planned"}' >/dev/null 2>&1 \
      && ok "scratch issue closed (not planned)" || fail "could not close scratch issue"
  fi
fi

echo
echo "SUMMARY: $PASS passed, $FAILN failed"
[[ "$FAILN" -eq 0 ]]
