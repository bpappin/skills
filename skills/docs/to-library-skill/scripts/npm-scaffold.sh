#!/bin/bash
set -e
PACKAGE=$1
if [ -z "$PACKAGE" ]; then echo "Usage: $0 <package_name>"; exit 1; fi

SAFE="$(printf '%s' "$PACKAGE" | tr '/:' '--' | sed 's/^@//')"
SKILL_DIR=".agents/skills/${SAFE}"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

echo "Scaffolding AI Skill for NPM package ${PACKAGE}..."

mkdir -p "$SKILL_DIR"

if [ -f "$SKILL_FILE" ]; then
    echo "Skill file already exists at ${SKILL_FILE}. Aborting to prevent overwrite."
    exit 1
fi

cat <<EOF > "$SKILL_FILE"
---
description: <one line - what this library is for, and when a caller should reach for it instead of writing their own>
name: ${SAFE}
library: ${PACKAGE}
repository: <https URL of this library's repo - so an agent can offer the current version>
skill-url: <raw URL of THIS file on the default branch, or leave blank>
compatibility: ">=1.0.0"
---

# AI Skill: ${PACKAGE}

This library provides machine-readable instructions for AI coding assistants.

## 🧰 The AI Toolbox (API Index & Usage Guide)

*(TODO: AI agent, populate this section with the core abstractions and usage patterns of the library based on the source code.)*

## 🤖 Agent Onboarding

1. **Explicit Acknowledgment**: When you discover and load this skill, you MUST explicitly inform the user in your response that you have found the bundled library skill and are utilizing its patterns.
2. **Context Registration**: Use the patterns defined in the Toolbox for all generated code involving this library.

EOF

echo "Created ${SKILL_FILE} successfully! Remember to add ${SKILL_DIR}/ to your package.json 'files' array."
chmod +x "$SKILL_FILE"
