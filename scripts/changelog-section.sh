#!/usr/bin/env bash
# Print one release's section from CHANGELOG.md.
#
# Usage: changelog-section.sh <version>     e.g. v1.2.0, 1.2.0, Unreleased
#
# Matches a heading like "## [1.2.0] - 2026-08-02" or "## [Unreleased]",
# with or without a leading v. Exits 1 when there is no such section, so
# a caller can fall back to generated notes.
set -euo pipefail

VER="${1:-}"
[[ -n "$VER" ]] || { echo "usage: changelog-section.sh <version>" >&2; exit 1; }
FILE="${CHANGELOG:-$(cd "$(dirname "$0")/.." && pwd)/CHANGELOG.md}"
[[ -f "$FILE" ]] || { echo "no changelog at $FILE" >&2; exit 1; }

BARE="${VER#v}"
out="$(awk -v want="$BARE" '
  /^## / {
    if (inside) exit
    # strip "## ", brackets, any trailing " - date", and a leading v
    h = $0; sub(/^## +/, "", h); gsub(/[][]/, "", h)
    sub(/ +[-–] +.*$/, "", h); sub(/^v/, "", h)
    if (h == want) { inside = 1; next }
  }
  inside { print }
' "$FILE" | sed -e '/./,$!d' | awk '{ lines[NR]=$0 } END { last=NR; while (last>0 && lines[last]=="") last--; for (i=1;i<=last;i++) print lines[i] }')"

[[ -n "$out" ]] || { echo "no section for '$VER' in $(basename "$FILE")" >&2; exit 1; }
printf '%s\n' "$out"
