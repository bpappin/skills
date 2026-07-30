#!/usr/bin/env bash
# Live smoke test for the GitHub wiki docs sync. Run on a developer
# machine (needs network + a real PAT with Contents RW + an INITIALIZED
# wiki - create the Home page once in the web UI first).
#
# Exercises the two-way flow in a scratch KB dir (never touches your
# real docs/knowledge), and cleans its scratch pages off the wiki at the
# end unless --keep.
#
# Usage: smoke-wiki.sh owner/repo [--keep]
#
# Token: $GITHUB_TOKEN, else the story-tools connection env, else
# `gh auth token`.
set -uo pipefail   # NOT -e: we want to reach the summary on failures

REPO="${1:-}"; KEEP=0
[[ "${2:-}" == "--keep" ]] && KEEP=1
[[ -n "$REPO" ]] || { echo "usage: smoke-wiki.sh owner/repo [--keep]" >&2; exit 1; }
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"; REPO_ROOT="$(cd "$SELF_DIR/../.." && pwd)"
SYNC="$REPO_ROOT/skills/docs/project-docs/scripts/gh-wiki-sync.sh"
[[ -x "$SYNC" ]] || SYNC="$REPO_ROOT/skills/project-docs/scripts/gh-wiki-sync.sh"
[[ -x "$SYNC" ]] || { echo "FAIL: gh-wiki-sync.sh not found/executable" >&2; exit 1; }

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

WIKI_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/${REPO}.wiki.git"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
KB="$TMP/kb"; mkdir -p "$KB"

echo "== wiki reachability"
if git ls-remote "$WIKI_URL" >/dev/null 2>&1; then
  ok "wiki repo reachable with this token (fine-grained PAT + wiki.git works)"
else
  fail "cannot reach ${REPO}.wiki.git - wiki disabled, uninitialized, or the token's Contents permission doesn't cover it"
  echo; echo "Result: $PASS passed, $FAILN failed"; exit 1
fi

cd "$TMP"

echo "== bootstrap: pull existing wiki into an empty KB"
if "$SYNC" "$KB" --repo "$REPO" >out.txt 2>&1; then
  [[ -f "$KB/README.md" ]] && ok "empty-KB bootstrap pulled the wiki (Home -> README.md)" \
                           || fail "bootstrap ran but no README.md landed"
else
  fail "bootstrap sync failed: $(tail -1 out.txt)"
fi

echo "== push: new scratch section + page"
mkdir -p "$KB/zz-smoke-scratch"
printf '# Smoke Scratch\n\nScratch section - safe to delete.\n' > "$KB/zz-smoke-scratch/README.md"
printf '# Scratch Page\n\nCreated by smoke-wiki.sh.\n' > "$KB/zz-smoke-scratch/scratch-page.md"
if "$SYNC" "$KB" --repo "$REPO" >out.txt 2>&1 && grep -q "Pushed:" out.txt; then
  git clone -q "$WIKI_URL" check1
  [[ -f check1/Zz-Smoke-Scratch-Scratch-Page.md && -f check1/Zz-Smoke-Scratch.md ]] \
    && ok "pages pushed and named from the tree" || fail "pushed pages missing in wiki clone"
  grep -q "Zz-Smoke-Scratch-Scratch-Page" check1/_Sidebar.md \
    && ok "_Sidebar.md regenerated with the new page" || fail "sidebar missing the new page"
else
  fail "push sync failed: $(tail -1 out.txt)"
fi

echo "== pull: wiki-side edit round-trips"
git clone -q "$WIKI_URL" ui
printf '# Scratch Page\n\nCreated by smoke-wiki.sh.\n\nEdited wiki-side.\n' > ui/Zz-Smoke-Scratch-Scratch-Page.md
git -C ui add -A && git -C ui -c user.name=smoke -c user.email=s@s commit -qm "smoke ui edit" && git -C ui push -q origin HEAD
if "$SYNC" "$KB" --repo "$REPO" >out.txt 2>&1 && grep -q "Edited wiki-side." "$KB/zz-smoke-scratch/scratch-page.md"; then
  ok "wiki-side edit pulled into the KB"
else
  fail "wiki-side edit did not round-trip: $(tail -1 out.txt)"
fi

echo "== merge: both sides edit different regions"
printf 'Local intro.\n\n# Scratch Page\n\nCreated by smoke-wiki.sh.\n\nEdited wiki-side.\n' > "$KB/zz-smoke-scratch/scratch-page.md"
git -C ui pull -q
printf '# Scratch Page\n\nCreated by smoke-wiki.sh.\n\nEdited wiki-side.\n\nWiki appendix.\n' > ui/Zz-Smoke-Scratch-Scratch-Page.md
git -C ui add -A && git -C ui -c user.name=smoke -c user.email=s@s commit -qm "smoke appendix" && git -C ui push -q origin HEAD
if "$SYNC" "$KB" --repo "$REPO" >out.txt 2>&1 \
   && grep -q "Local intro." "$KB/zz-smoke-scratch/scratch-page.md" \
   && grep -q "Wiki appendix." "$KB/zz-smoke-scratch/scratch-page.md"; then
  ok "three-way merge combined both edits"
else
  fail "merge failed: $(tail -1 out.txt)"
fi

echo "== rename: local move renames the page"
mv "$KB/zz-smoke-scratch/scratch-page.md" "$KB/zz-smoke-scratch/renamed-page.md"
if "$SYNC" "$KB" --repo "$REPO" >out.txt 2>&1 && grep -q "Renamed pages:" out.txt; then
  rm -rf check2; git clone -q "$WIKI_URL" check2
  [[ -f check2/Zz-Smoke-Scratch-Renamed-Page.md && ! -f check2/Zz-Smoke-Scratch-Scratch-Page.md ]] \
    && ok "page renamed in the wiki" || fail "rename didn't land in the wiki"
else
  fail "rename sync failed: $(tail -1 out.txt)"
fi

echo "== cleanup"
if [[ $KEEP -eq 1 ]]; then
  echo "  (kept scratch pages: Zz-Smoke-Scratch*)"
else
  rm -rf "$KB/zz-smoke-scratch"
  if "$SYNC" "$KB" --repo "$REPO" --allow-delete >out.txt 2>&1 && grep -q "Deleted pages:" out.txt; then
    ok "scratch pages deleted with --allow-delete"
  else
    fail "cleanup delete failed: $(tail -1 out.txt)"
  fi
fi

echo; echo "Result: $PASS passed, $FAILN failed"
[[ $FAILN -eq 0 ]]
