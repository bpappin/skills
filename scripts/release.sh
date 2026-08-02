#!/usr/bin/env bash
# Prepare a release: roll the changelog, then tell you what to run.
#
# Usage: release.sh <version>        e.g. release.sh 1.0.0
#
# Moves the [Unreleased] section to [<version>] - <today>, opens a fresh
# empty Unreleased above it, and refreshes VERSIONS.json. It does NOT
# commit, tag, or push - it prints those commands for you to run, so
# nothing leaves your machine without you doing it.
set -euo pipefail

VER="${1:-}"; VER="${VER#v}"
[[ "$VER" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || {
  echo "usage: release.sh <version>   (e.g. 1.0.0)" >&2; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CL="$ROOT/CHANGELOG.md"
[[ -f "$CL" ]] || { echo "error: no CHANGELOG.md" >&2; exit 1; }

grep -q "^## \[$VER\]" "$CL" && { echo "error: CHANGELOG already has [$VER]" >&2; exit 1; }
grep -q '^## \[Unreleased\]' "$CL" || { echo "error: no [Unreleased] section" >&2; exit 1; }

# anything actually in Unreleased?
if ! "$ROOT/scripts/changelog-section.sh" Unreleased >/dev/null 2>&1; then
  echo "error: [Unreleased] is empty - nothing to release" >&2; exit 1
fi

TODAY="$(date +%Y-%m-%d)"
python3 - "$CL" "$VER" "$TODAY" <<'PY'
import sys
path, ver, today = sys.argv[1:4]
s = open(path, encoding='utf-8').read()
s = s.replace('## [Unreleased]',
              f'## [Unreleased]\n\nNothing yet.\n\n## [{ver}] - {today}', 1)
open(path, 'w', encoding='utf-8').write(s)
PY
echo "  ✓ CHANGELOG.md: [Unreleased] -> [$VER] - $TODAY"

"$ROOT/scripts/skill-versions.sh" "$ROOT/skills" --publish >/dev/null
echo "  ✓ VERSIONS.json refreshed"

cat <<NEXT

Review the changelog section, then:

  git add CHANGELOG.md VERSIONS.json
  git commit -m "release v$VER"
  git push
  git tag v$VER && git push origin v$VER

The tag triggers the release workflow: it packages every skill, attaches
the .skill bundles and VERSIONS.json, and uses the [$VER] changelog
section as the release notes.
NEXT
