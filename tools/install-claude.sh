#!/bin/bash

# Claude Code Skill Install Tool
# This script injects all skills from the central repository into Claude's custom instructions.

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$SKILLS_ROOT/src/skills"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
echo "⚠️  WARNING: Syncing skills to Claude global instructions is DIFFERENT"
echo "   from the \"Project-Attached Skills\" model (using .agents/skills/ directory in your repo)."
echo "   Only use this if you want these skills to be available in all Claude sessions."
echo ""

echo "🚀 Starting Claude Skill Installation..."

# 1. Collect all Skill instructions
ALL_INSTRUCTIONS=""

while read -r skill_file; do
    SKILL_NAME=$(basename "$(dirname "$skill_file")")
    CONTENT=$(cat "$skill_file" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
    
    SKILL_BLOCK="<skill name=\"$SKILL_NAME\">\n$CONTENT\n</skill>\n\n"
    ALL_INSTRUCTIONS="${ALL_INSTRUCTIONS}${SKILL_BLOCK}"
done < <(find "$SRC_DIR" -name "SKILL.md")

# 2. Update Claude Settings
if [ ! -f "$CLAUDE_SETTINGS" ]; then
    mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
    echo '{"customInstructions": ""}' > "$CLAUDE_SETTINGS"
fi

echo "📝 Updating Claude's Global Custom Instructions..."

# Using Python to safely update the JSON file
python3 -c "
import json
import os

settings_path = os.path.expanduser('~/.claude/settings.json')
with open(settings_path, 'r') as f:
    data = json.load(f)

# The instructions to inject
new_instructions = \"\"\"$ALL_INSTRUCTIONS\"\"\"

# Clear existing skills and append new ones
# We keep the core instructions if they exist, but replace the skill blocks
import re
pattern = r'<skill.*?</skill>'
current = data.get('customInstructions', '')
clean_instructions = re.sub(pattern, '', current, flags=re.DOTALL).strip()

data['customInstructions'] = (clean_instructions + '\n\n' + new_instructions).strip()

with open(settings_path, 'w') as f:
    json.dump(data, f, indent=2)
"

echo "✅ Claude installation complete!"
echo "💡 These skills will now be available in all new Claude Code sessions."
