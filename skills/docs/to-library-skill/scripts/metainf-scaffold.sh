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

LEGACY="$(ls -1 "${SOURCE_DIR}"/resources/META-INF/ai-skills/*.ai-skill.md 2>/dev/null || true)"
if [ -n "$LEGACY" ]; then
  echo "error: this package already has a v1 skill:" >&2
  printf '  %s\n' $LEGACY >&2
  echo "  Scaffolding now would leave TWO skills for one module. Migrate it:" >&2
  echo "    migrate-library-skills.sh . --apply" >&2
  exit 1
fi
if [ -d "${SOURCE_DIR}/resources/META-INF/skills" ]; then
  echo "error: this module uses the pre-canonical META-INF/skills/ path." >&2
  echo "  Mixing it with META-INF/agents/skills/ makes the Agent-Skills" >&2
  echo "  manifest attribute wrong for one of them. Normalise first:" >&2
  echo "    migrate-library-skills.sh . --apply" >&2
  exit 1
fi

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

  KMP: there is no single `jar` task - name the target's jar:
    tasks.named<Jar>("jvmJar") { manifest { attributes(...) } }
  Do NOT use tasks.withType<Jar>: it also matches allMetadataJar, which
  does NOT carry commonMain resources, so that jar would declare a path
  it does not hold and a consumer trusting the attribute finds nothing.

  ANDROID: the attribute cannot reach an AAR - Android Gradle strips
  META-INF/MANIFEST.MF from the nested classes.jar, and an AAR has no
  manifest of its own. Android consumers scan; that is expected.

  ANDROID, more important: on AGP 8 commonMain resources are DROPPED
  from the AAR entirely (KT-46493) - your skill ships on JVM and is
  silently missing on Android. Add:
    android { sourceSets.getByName("main") {
        resources.srcDir("src/commonMain/resources") } }
  AGP 9's com.android.kotlin.multiplatform.library does it for you.
  Verify either way: unzip -l the AAR and look inside classes.jar.

This attribute is a PROPOSAL under discussion, not a ratified standard -
see docs/outbox/ in the story-tools repo.
--------------------------------------------------------------------
MFEOF
