#!/usr/bin/env bash
# story-tools bootstrap: fetch the suite, then run the installer.
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/bpappin/skills/main/bootstrap.sh)"
#
# Use `bash -c "$(curl ...)"`, NOT `curl ... | bash`: the installer is
# interactive, and piping leaves stdin pointed at the script instead of
# your terminal, so every prompt reads EOF.
#
# Clones (or updates) the suite into ~/.agents/story-tools/src and runs
# scripts/install.sh. That clone is where projects get their skills from,
# so it stays put - re-run this any time to update it.
#
# Args are passed through to install.sh:
#   bash -c "$(curl -fsSL .../bootstrap.sh)" -- --project ~/code/my-app
#
# Env: STORY_TOOLS_REPO (default bpappin/skills), STORY_TOOLS_BRANCH
#      (default main), STORY_TOOLS_SRC (default ~/.agents/story-tools/src)
set -euo pipefail

REPO="${STORY_TOOLS_REPO:-bpappin/skills}"
BRANCH="${STORY_TOOLS_BRANCH:-main}"
SRC="${STORY_TOOLS_SRC:-$HOME/.agents/story-tools/src}"

# Piped in? Then stdin is this script, and every wizard prompt reads EOF.
# Catch it here rather than letting the installer skip through silently.
if [[ ! -t 0 ]]; then
  cat >&2 <<'PIPED'
error: stdin is not a terminal - this looks like `curl ... | bash`.
The installer is interactive, so piping makes every prompt read EOF.

Run it this way instead (keeps your terminal on stdin):

  bash -c "$(curl -fsSL https://raw.githubusercontent.com/bpappin/skills/main/bootstrap.sh)"

Or clone first:

  git clone https://github.com/bpappin/skills.git ~/.agents/story-tools/src
  ~/.agents/story-tools/src/scripts/install.sh
PIPED
  exit 1
fi

for tool in git curl; do
  command -v "$tool" >/dev/null 2>&1 || { echo "error: $tool is required" >&2; exit 1; }
done

if [[ -d "$SRC/.git" ]]; then
  echo "==> updating $SRC"
  git -C "$SRC" fetch --quiet origin "$BRANCH"
  git -C "$SRC" checkout --quiet "$BRANCH"
  if ! git -C "$SRC" merge --ff-only --quiet "origin/$BRANCH" 2>/dev/null; then
    echo "  ! local changes in $SRC - leaving them alone, using what is there" >&2
  fi
else
  echo "==> cloning $REPO into $SRC"
  mkdir -p "$(dirname "$SRC")"
  git clone --quiet --branch "$BRANCH" "https://github.com/$REPO.git" "$SRC"
fi

INSTALL="$SRC/scripts/install.sh"
[[ -f "$INSTALL" ]] || { echo "error: $INSTALL not found - wrong repo or branch?" >&2; exit 1; }
chmod +x "$INSTALL" 2>/dev/null || true

echo "==> running the installer"
echo
exec "$INSTALL" "$@"
