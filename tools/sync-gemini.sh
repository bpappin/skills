#!/bin/bash

# Gemini Skill Sync & Install Tool
# This script packages and installs all skills from the src/skills directory.

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$SKILLS_ROOT/src/skills"
PACKAGE_SCRIPT="/Users/bpappin/Library/Caches/JetBrains/Air/gemini-cli-10/builtin/skill-creator/scripts/package_skill.cjs"
TEMP_DIST="$SKILLS_ROOT/dist_temp"

# Parse arguments
SCOPE="workspace"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --global) SCOPE="user" ;;
        --local) SCOPE="workspace" ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo "🚀 Starting Gemini Skill Synchronization..."
echo "📂 Source Directory: $SRC_DIR"
echo "🎯 Scope: $SCOPE"

mkdir -p "$TEMP_DIST"

# Find all directories containing a SKILL.md file
find "$SRC_DIR" -name "SKILL.md" | while read -r skill_file; do
    SKILL_DIR="$(dirname "$skill_file")"
    SKILL_NAME="$(basename "$SKILL_DIR")"
    
    echo "📦 Packaging skill: $SKILL_NAME..."
    
    # Run the packaging script
    node "$PACKAGE_SCRIPT" "$SKILL_DIR" "$TEMP_DIST" > /dev/null
    
    if [ $? -eq 0 ]; then
        SKILL_PACKAGE="$TEMP_DIST/$SKILL_NAME.skill"
        if [ -f "$SKILL_PACKAGE" ]; then
            echo "📥 Installing $SKILL_NAME..."
            # Try gemini command directly first, then fallback to npx
            if command -v gemini &> /dev/null; then
                gemini skills install "$SKILL_PACKAGE" --scope "$SCOPE"
            else
                npx -y @google/gemini-cli skills install "$SKILL_PACKAGE" --scope "$SCOPE"
            fi
        else
            echo "❌ Error: Package not found for $SKILL_NAME"
        fi
    else
        echo "❌ Error: Failed to package $SKILL_NAME"
    fi
done

echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIST"

echo "✅ Skill synchronization complete!"
echo ""
echo "📢  IMPORTANT: To activate the updated skills, please run the following command"
echo "    in your active Gemini session:"
echo ""
echo "    /skills reload"
echo ""
