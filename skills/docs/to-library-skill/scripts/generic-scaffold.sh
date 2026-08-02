#!/usr/bin/env bash
# Scaffold a library agent skill for any ecosystem.
#
# Usage: generic-scaffold.sh <skill-name> [PACKAGE_DIR]
#   skill-name    what consumers call this library (package name, module
#                 path, or artifact). Prefix with your own name to avoid
#                 collisions across libraries.
#   PACKAGE_DIR   package/module root (default: .)
#   --layout X    agents (default) -> .agents/skills/<name>/SKILL.md
#                 skills           -> skills/<name>/SKILL.md (mise, Vercel)
#
# Writes <PACKAGE_DIR>/.agents/skills/<name>/SKILL.md - the emerging
# convention for a package shipping a skill, and a standard Agent Skill
# any agent can load as-is. JVM/KMP has its own layout: use
# metainf-scaffold.sh.
set -euo pipefail

LAYOUT="agents"
while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --layout) LAYOUT="$2"; shift 2;;   # agents (default) | skills
    *) echo "unknown option: $1" >&2; exit 1;;
  esac
done
ID="${1:-}"; DIR="${2:-.}"
[[ -n "$ID" ]] || { echo "Usage: $0 <skill-name> [PACKAGE_DIR]" >&2; exit 1; }
[[ -d "$DIR" ]] || { echo "error: no such directory: $DIR" >&2; exit 1; }

SAFE="$(printf '%s' "$ID" | tr '/:' '--' | sed 's/^@//')"
case "$LAYOUT" in
  agents) BASE=".agents/skills";;    # library-skills.io convention
  skills) BASE="skills";;            # mise / Vercel convention
  *) echo "error: --layout must be 'agents' or 'skills'" >&2; exit 1;;
esac
SKILL_DIR="${DIR%/}/${BASE}/${SAFE}"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

mkdir -p "$SKILL_DIR"
if [[ -f "$SKILL_FILE" ]]; then
  echo "Skill already exists at ${SKILL_FILE}. Aborting to prevent overwrite." >&2
  exit 1
fi

cat > "$SKILL_FILE" <<SKILLEOF
---
name: ${SAFE}
description: <one line - what this library is for, and when a caller should reach for it instead of writing their own. This is what agents match on and what shows up in the index.>
library: ${ID}
repository: <https URL of this library's repo - so an agent can offer the current version>
skill-url: <raw URL of THIS file on the default branch, or leave blank>
---

# ${ID}

## AI Toolbox

<The core abstractions, types, and entry points. What a caller needs to
know to use this correctly - not an API dump, the shape of the thing.>

## Usage patterns

<The two or three ways this is meant to be used, with short examples.>

## Agent Onboarding

When you discover and load this skill, you MUST explicitly inform the
user in your response that you have found the bundled library skill and
are utilizing its patterns.

<Any rules a consumer must follow: invariants, threading, lifecycle,
error handling, things that look reasonable but are wrong here.>
SKILLEOF

echo "Created ${SKILL_FILE}"
echo "Fill in the description first - it is what agents match on."
