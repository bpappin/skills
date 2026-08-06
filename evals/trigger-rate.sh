#!/usr/bin/env bash
# Measure which skill an agent reaches for, per query.
#
# Extends the trigger-rate pattern: instead of asking "did MY skill fire?",
# it records WHICH skill fired. A collision then shows up as the wrong
# answer rather than a silent zero - which is the failure mode that
# actually bites when several skills sit near each other.
#
# Usage: trigger-rate.sh <queries.json> [runs]
#   queries.json: [{ "query": "...", "expect": "skill-name" | null,
#                    "forbid": ["skill-name", ...] }, ...]
#
#   expect: null  - a negative control; NOTHING should fire.
#   forbid        - this skill must not fire, whatever else legitimately does.
#                   Use it for near-miss vocabulary: "design the settings
#                   screen" must never reach to-rad, but something else may.
#
# Run this from a project that has the skills installed. Needs the `claude`
# CLI and `jq` on PATH, and network access.
set -uo pipefail

QUERIES="${1:?Usage: $0 <queries.json> [runs]}"
RUNS="${2:-3}"
command -v jq >/dev/null || { echo "error: jq is required" >&2; exit 1; }
command -v claude >/dev/null || { echo "error: the claude CLI is required" >&2; exit 1; }

# Every Skill invocation in one run, as a JSON array of names.
skills_invoked() {
  claude -p "$1" --output-format json 2>/dev/null \
    | jq -c '[.messages[]?.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill]' \
    || echo '[]'
}

count=$(jq length "$QUERIES")
for i in $(seq 0 $((count - 1))); do
  query=$(jq -r ".[$i].query" "$QUERIES")
  expect=$(jq -r ".[$i].expect // empty" "$QUERIES")
  forbid=$(jq -c ".[$i].forbid // []" "$QUERIES")
  hits=0; wrong=0; banned=0; observed='[]'

  for _ in $(seq 1 "$RUNS"); do
    got=$(skills_invoked "$query")
    observed=$(jq -c --argjson a "$observed" --argjson b "$got" -n '$a + $b')
    if jq -e --argjson f "$forbid" 'any(.[]; . as $s | $f | index($s))' <<<"$got" >/dev/null; then
      banned=$((banned+1))
    fi
    if [[ -z "$expect" ]]; then
      # Negative control: firing at all is the failure.
      [[ "$(jq 'length' <<<"$got")" -eq 0 ]] && hits=$((hits+1)) || wrong=$((wrong+1))
    else
      if jq -e --arg s "$expect" 'any(.[]; . == $s)' <<<"$got" >/dev/null; then
        hits=$((hits+1))
      elif [[ "$(jq 'length' <<<"$got")" -gt 0 ]]; then
        wrong=$((wrong+1))   # something fired, but not the right one - a collision
      fi
    fi
  done

  jq -n --arg query "$query" --arg expect "${expect:-}" \
        --argjson hits "$hits" --argjson wrong "$wrong" --argjson runs "$RUNS" \
        --argjson observed "$observed" --argjson banned "$banned" \
        --argjson forbid "$forbid" \
    '{query: $query,
      expect: (if $expect == "" then null else $expect end),
      forbid: $forbid,
      correct: $hits, wrong_skill: $wrong, forbidden_fired: $banned, runs: $runs,
      rate: ($hits / $runs),
      skills_seen: ($observed | group_by(.) | map({(.[0]): length}) | add // {})}'
done | jq -s '
  { results: .,
    summary: {
      queries: length,
      mean_rate: (map(.rate) | add / length),
      never_fired: [ .[] | select(.expect != null and .correct == 0 and .wrong_skill == 0) | .query ],
      collisions:  [ .[] | select(.wrong_skill > 0) | {query, expect, skills_seen} ],
      false_positives: [ .[] | select(.expect == null and .wrong_skill > 0) | {query, skills_seen} ],
      forbidden_fired: [ .[] | select(.forbidden_fired > 0) | {query, forbid, skills_seen} ]
    } }'
