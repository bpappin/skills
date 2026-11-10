#!/usr/bin/env bash
# Regression test: a section born from a local README.md settles its
# directory name in ONE sync.
#
# The bug this covers: the birth step named a new section's directory with
# the article's ID prefix (PROJ-A-5_research/) while the pull step names it
# for the section (research/), so the next sync moved it back. Every file in
# a new section appeared as moved twice in git history and it took three
# syncs to reach "In sync".
#
# Runs the real script against a stand-in API on localhost - no credentials,
# no network, nothing touched outside a temp directory.
#
# Usage: sync-section-birth.sh [path/to/yt-sync.sh] [port]
# Exit: 0 all cases pass, 1 a case failed.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SYNC="${1:-$HERE/../../../skills/docs/project-docs/scripts/yt-sync.sh}"
PORT="${2:-8797}"
[[ -f "$SYNC" ]] || { echo "not found: $SYNC" >&2; exit 1; }

python3 "$HERE/fake-youtrack.py" "$PORT" & FAKE=$!
trap 'kill $FAKE 2>/dev/null' EXIT
sleep 1

fails=0
tree() { (cd docs/knowledge && find . -mindepth 1 -not -path './.yt-sync*' | LC_ALL=C sort | tr '\n' ' '); }
check() { # name expected-tree actual-tree
  if [[ "$2" == "$3" ]]; then echo "  ok: $1"
  else echo "  FAIL: $1"; echo "    expected: $2"; echo "    actual:   $3"; fails=$((fails+1)); fi
}

echo "case: new section with a README, against an existing sync state"
W="$(mktemp -d)"; cd "$W"
git init -q .; git config user.email t@t.t; git config user.name t
mkdir -p docs/knowledge
export YOUTRACK_URL="http://127.0.0.1:$PORT" YOUTRACK_TOKEN=fake
bash "$SYNC" docs/knowledge --project PROJ >/dev/null 2>&1   # establish state
mkdir -p docs/knowledge/research
printf '# Research\n\nInvestigations.\n' > docs/knowledge/research/README.md
printf '# Some Topic\n\nBody.\n' > docs/knowledge/research/some-topic.md
bash "$SYNC" docs/knowledge --project PROJ >/dev/null 2>&1
settled="./research ./research/PROJ-A-2_some-topic.md ./research/README.md "
check "directory keeps its section name after the birth sync" "$settled" "$(tree)"
out="$(bash "$SYNC" docs/knowledge --project PROJ 2>&1)"
case "$out" in *"nothing to do"*) echo "  ok: second sync is a no-op";;
  *) echo "  FAIL: second sync moved things"; echo "$out" | sed 's/^/    /'; fails=$((fails+1));; esac
check "tree unchanged by the second sync" "$settled" "$(tree)"

curl -fsS -X POST "http://127.0.0.1:$PORT/_reset" >/dev/null

echo "case: --force adoption of an existing tree"
W="$(mktemp -d)"; cd "$W"
git init -q .; git config user.email t@t.t; git config user.name t
mkdir -p docs/knowledge/decisions
printf '# Architecture Decision Records\n\nDecisions.\n' > docs/knowledge/decisions/README.md
printf '# ADR 1 Thing\n\nBody.\n' > docs/knowledge/decisions/0001-thing.md
bash "$SYNC" docs/knowledge --project PROJ --force >/dev/null 2>&1
adopted="./decisions ./decisions/PROJ-A-2_adr-1-thing.md ./decisions/README.md "
check "adopted directory keeps its name" "$adopted" "$(tree)"
out="$(bash "$SYNC" docs/knowledge --project PROJ 2>&1)"
case "$out" in *"nothing to do"*) echo "  ok: second sync is a no-op";;
  *) echo "  FAIL: second sync moved things"; echo "$out" | sed 's/^/    /'; fails=$((fails+1));; esac

echo
if [[ $fails -eq 0 ]]; then echo "PASS"; else echo "FAIL ($fails)"; fi
exit $((fails > 0))
