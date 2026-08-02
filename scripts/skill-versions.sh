#!/usr/bin/env bash
# Print every skill's name and version from its SKILL.md frontmatter.
# Use it to compare the repo (current) against what's imported in a
# Claude skill library or installed in a project.
#
# Usage: skill-versions.sh [SKILLS_DIR] [--publish]
#   (default SKILLS_DIR: <repo>/skills)
#   --publish   also write VERSIONS.json at the repo root - the manifest
#               a project fetches to find out whether it is behind.
#               Commit it; it is how remote version checks work.
set -euo pipefail
PUBLISH=0; ARGS=()
for a in "$@"; do [[ "$a" == "--publish" ]] && PUBLISH=1 || ARGS+=("$a"); done
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="${ARGS[0]:-$REPO_ROOT/skills}"
printf '%-24s %-10s %s\n' 'SKILL' 'VERSION' 'GROUP'
find "$ROOT" -name SKILL.md -maxdepth 3 | sort | while read -r f; do
  name=$(sed -nE 's/^name: *(.+)$/\1/p' "$f" | head -1)
  ver=$(sed -nE 's/^ *version: *"?([^"]+)"?$/\1/p' "$f" | head -1)
  group=$(basename "$(dirname "$(dirname "$f")")")
  printf '%-24s %-10s %s\n' "${name:-?}" "${ver:-?}" "$group"
done

if [[ "$PUBLISH" == 1 ]]; then
  out="$REPO_ROOT/VERSIONS.json"
  {
    printf '{\n  "generated": "%s",\n  "skills": {\n' "$(date +%Y-%m-%d)"
    first=1
    find "$ROOT" -name SKILL.md -maxdepth 3 | sort | while read -r f; do
      name=$(sed -nE 's/^name: *(.+)$/\1/p' "$f" | head -1)
      ver=$(sed -nE 's/^ *version: *"?([^"]+)"?$/\1/p' "$f" | head -1)
      [[ -n "$name" ]] || continue
      [[ $first == 1 ]] && first=0 || printf ',\n'
      printf '    "%s": "%s"' "$name" "${ver:-0}"
    done
    printf '\n  }\n}\n'
  } > "$out"
  echo "Wrote $out"
fi
