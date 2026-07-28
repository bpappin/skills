#!/usr/bin/env bash
# Print every skill's name and version from its SKILL.md frontmatter.
# Use it to compare the repo (current) against what's imported in a
# Claude skill library or installed in a project.
#
# Usage: skill-versions.sh [SKILLS_DIR]   (default: <repo>/skills)
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)/skills}"
printf '%-24s %-10s %s\n' 'SKILL' 'VERSION' 'GROUP'
find "$ROOT" -name SKILL.md -maxdepth 3 | sort | while read -r f; do
  name=$(sed -nE 's/^name: *(.+)$/\1/p' "$f" | head -1)
  ver=$(sed -nE 's/^ *version: *"?([^"]+)"?$/\1/p' "$f" | head -1)
  group=$(basename "$(dirname "$(dirname "$f")")")
  printf '%-24s %-10s %s\n' "${name:-?}" "${ver:-?}" "$group"
done
