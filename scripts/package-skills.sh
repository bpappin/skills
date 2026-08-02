#!/usr/bin/env bash
# Package every skill as a versioned .skill bundle, and refresh
# VERSIONS.json.
#
# Output is disposable build product (dist/ is gitignored) - the source
# in skills/ is the only truth. Rebuild any time; publish by attaching
# the files to a GitHub Release, not by committing them.
#
# Usage: package-skills.sh [--clean] [SKILL_NAME ...]
#   --clean      remove older packages of each skill it builds
#   SKILL_NAME   package only these (default: all)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$REPO_ROOT/skills"; OUT="$REPO_ROOT/dist/versioned"
CLEAN=0; ONLY=()
for a in "$@"; do [[ "$a" == "--clean" ]] && CLEAN=1 || ONLY+=("$a"); done

command -v zip >/dev/null 2>&1 || { echo "error: zip is required" >&2; exit 1; }
mkdir -p "$OUT"

built=0 skipped=0
while IFS= read -r skill_md; do
  dir="$(dirname "$skill_md")"; name="$(basename "$dir")"; group="$(dirname "$dir")"
  if [[ ${#ONLY[@]} -gt 0 ]]; then
    case " ${ONLY[*]} " in *" $name "*) ;; *) continue;; esac
  fi
  ver="$(sed -nE 's/^ *version: *"?([^"]+)"?$/\1/p' "$skill_md" | head -1)"
  if [[ -z "$ver" ]]; then
    echo "  ! $name has no version - skipped" >&2; skipped=$((skipped+1)); continue
  fi
  if command -v skills-ref >/dev/null 2>&1 && ! skills-ref validate "$dir" >/dev/null 2>&1; then
    echo "  ! $name fails validation - skipped" >&2; skipped=$((skipped+1)); continue
  fi
  [[ $CLEAN == 1 ]] && rm -f "$OUT/$name"-*.skill
  target="$OUT/$name-$ver.skill"
  rm -f "$target"
  (cd "$group" && zip -qr "$target" "$name" -x "*.DS_Store" "*/.git/*")
  printf '  %-32s %s\n' "$name" "$ver"
  built=$((built+1))
done < <(find "$SRC" -name SKILL.md -maxdepth 3 | sort)

"$REPO_ROOT/scripts/skill-versions.sh" "$SRC" --publish >/dev/null
echo
echo "$built packaged into dist/versioned/${skipped:+ ($skipped skipped)}"
echo "VERSIONS.json refreshed - commit it so projects can see what is published."
