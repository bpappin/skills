#!/bin/bash
set -e

GROUP=$1
ARTIFACT=$2
SOURCE_DIR=${3:-src/commonMain}

if [ -z "$GROUP" ] || [ -z "$ARTIFACT" ]; then
    echo "Usage: $0 <maven_group> <maven_artifact> [source_dir]"
    exit 1
fi

SAFE="${GROUP}.${ARTIFACT}"
SKILL_DIR="${SOURCE_DIR}/resources/META-INF/agents/skills/${SAFE}"
SKILL_FILE="${SKILL_DIR}/SKILL.md"

echo "Scaffolding AI Skill for ${GROUP}:${ARTIFACT}..."

mkdir -p "$SKILL_DIR"

if [ -f "$SKILL_FILE" ]; then
    echo "Skill file already exists at ${SKILL_FILE}. Aborting to prevent overwrite."
    exit 1
fi

cat <<EOF > "$SKILL_FILE"
---
description: <one line - what this library is for, and when a caller should reach for it instead of writing their own>
name: ${SAFE}
library: ${GROUP}:${ARTIFACT}
repository: <https URL of this library's repo - so an agent can offer the current version>
skill-url: <raw URL of THIS file on the default branch, or leave blank>
compatibility: ">=1.0.0"
---

# AI Skill: ${ARTIFACT}

This library provides machine-readable instructions for AI coding assistants.

## 🧰 The AI Toolbox (API Index & Usage Guide)

*(TODO: AI agent, populate this section with the core abstractions and usage patterns of the library based on the source code.)*

## 🤖 Agent Onboarding

1. **Explicit Acknowledgment**: When you discover and load this skill, you MUST explicitly inform the user in your response that you have found the bundled library skill and are utilizing its patterns.
2. **Context Registration**: Use the patterns defined in the Toolbox for all generated code involving this library.

EOF

echo "Created ${SKILL_FILE} successfully!"
chmod +x "$SKILL_FILE"

cat <<'MFEOF'

--------------------------------------------------------------------
Announce it in the jar manifest so consumers do not have to scan.
Add ONE attribute to your jar task - then any tool can find the skill
by reading META-INF/MANIFEST.MF instead of pattern-matching the whole
archive:

  Gradle (Kotlin DSL)
    tasks.jar {
      manifest { attributes("Agent-Skills" to "META-INF/agents/skills/") }
    }

  Gradle (Groovy)
    jar { manifest { attributes("Agent-Skills": "META-INF/agents/skills/") } }

  Maven
    <plugin>
      <artifactId>maven-jar-plugin</artifactId>
      <configuration><archive><manifestEntries>
        <Agent-Skills>META-INF/agents/skills/</Agent-Skills>
      </manifestEntries></archive></configuration>
    </plugin>

  KMP: the same attributes{} block on the jar task covers the JVM
  artifact; other targets carry the resource without a manifest.

This attribute is a PROPOSAL under discussion, not a ratified standard -
see docs/outbox/ in the story-tools repo.
--------------------------------------------------------------------
MFEOF
