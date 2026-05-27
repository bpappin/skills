#!/bin/bash

# Agent Skills Project Installer / Migrator
# This script copies the master skills library into a target project.
# If a legacy .skills/ directory is detected in the target project, it triggers migrate.py.

SKILLS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASTER_DIR="$SKILLS_ROOT/src/skills"
MIGRATE_SCRIPT="$MASTER_DIR/manage-skills/scripts/migrate.py"

# Help output
show_help() {
    echo "Usage: ./install-project.sh [options] <target-project-root>"
    echo ""
    echo "Options:"
    echo "  --backup       Back up legacy .skills/ to skills-backup/ before migrating (default)"
    echo "  --no-backup    Migrate legacy folder without backing up"
    echo "  --dry-run      Analyze and report customizations without migrating"
    echo "  --help         Show this help message"
}

# Parse options
BACKUP_FLAG="--backup"
DRY_RUN=""
TARGET_DIR=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --backup) BACKUP_FLAG="--backup" ;;
        --no-backup) BACKUP_FLAG="" ;;
        --dry-run) DRY_RUN="--dry-run" ;;
        --help) show_help; exit 0 ;;
        -*) echo "Unknown option: $1"; show_help; exit 1 ;;
        *) TARGET_DIR="$1" ;;
    esac
    shift
done

if [ -z "$TARGET_DIR" ]; then
    echo "❌ Error: Target project root directory is required."
    show_help
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: Target directory does not exist: $TARGET_DIR"
    exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
echo "🚀 Checking target project: $TARGET_DIR"

# 1. Detect Legacy .skills/ Directory
if [ -d "$TARGET_DIR/.skills" ]; then
    echo "⚠️  Legacy '.skills/' directory detected in target project."
    echo "🔄 Running automated migration script..."
    
    # Run migrate.py
    if [ -n "$DRY_RUN" ]; then
        python3 "$MIGRATE_SCRIPT" --project-root "$TARGET_DIR" --master-dir "$MASTER_DIR" --dry-run
    else
        # If backup flag is empty, pass nothing, otherwise pass --backup
        if [ -n "$BACKUP_FLAG" ]; then
            python3 "$MIGRATE_SCRIPT" --project-root "$TARGET_DIR" --master-dir "$MASTER_DIR" --backup --migrate
        else
            python3 "$MIGRATE_SCRIPT" --project-root "$TARGET_DIR" --master-dir "$MASTER_DIR" --migrate
        fi
    fi
    exit $?
fi

# 2. Standard Installation if no legacy folder exists
echo "📦 Installing skills into: $TARGET_DIR/.agents/skills/ ..."
mkdir -p "$TARGET_DIR/.agents/skills"

# Copy all master skills to .agents/skills/ in target project
cp -R "$MASTER_DIR/"* "$TARGET_DIR/.agents/skills/"

# Setup AGENTS.md if missing
if [ ! -f "$TARGET_DIR/AGENTS.md" ]; then
    echo "📝 Creating default AGENTS.md in target project root..."
    cp "$MASTER_DIR/setup-project/AGENTS_TEMPLATE.md" "$TARGET_DIR/AGENTS.md"
fi

# Setup CLAUDE.md if missing
if [ ! -f "$TARGET_DIR/CLAUDE.md" ]; then
    echo "📝 Creating default CLAUDE.md in target project root..."
    echo 'Before taking action, you MUST read the instructions in [AGENTS.md](AGENTS.md) and adhere to the project'\''s local skill workflows.' > "$TARGET_DIR/CLAUDE.md"
fi

# Setup project.json config file
CONFIG_TARGET="$TARGET_DIR/.agents/config/project.json"
LEGACY_CONFIG="$TARGET_DIR/.config/project.json"

if [ ! -f "$CONFIG_TARGET" ]; then
    if [ -f "$LEGACY_CONFIG" ]; then
        echo "🔄 Migrating legacy config .config/project.json to .agents/config/project.json ..."
        mkdir -p "$TARGET_DIR/.agents/config"
        mv "$LEGACY_CONFIG" "$CONFIG_TARGET"
        rmdir "$TARGET_DIR/.config" 2>/dev/null
    else
        echo "📝 Initializing project.json in .agents/config/ ..."
        mkdir -p "$TARGET_DIR/.agents/config"
        PROJECT_NAME=$(basename "$TARGET_DIR")
        cat <<EOF > "$CONFIG_TARGET"
{
  "project_id": "$PROJECT_NAME",
  "sync_target": "github",
  "sync_enabled": false
}
EOF
    fi
fi

echo "✅ Skill installation complete!"
