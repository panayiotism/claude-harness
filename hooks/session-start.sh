#!/bin/bash
# Claude Harness SessionStart Hook
# Checks plugin version and runs project init.sh

# Get plugin version
PLUGIN_VERSION=$(grep '"version"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

# Check if this is a harness project
if [ ! -d "$CLAUDE_PROJECT_DIR/.claude-harness" ]; then
    exit 0  # Not a harness project, skip silently
fi

# Get project's last-run version
PROJECT_VERSION=$(cat "$CLAUDE_PROJECT_DIR/.claude-harness/.plugin-version" 2>/dev/null)

# Version check - handle both missing file and version mismatch
if [ -z "$PROJECT_VERSION" ]; then
    # .plugin-version doesn't exist - create it with current version
    echo "$PLUGIN_VERSION" > "$CLAUDE_PROJECT_DIR/.claude-harness/.plugin-version"
    echo ""
    echo "=== HARNESS INITIALIZED ==="
    echo "Recorded plugin version: $PLUGIN_VERSION"
    echo ""
elif [ "$PLUGIN_VERSION" != "$PROJECT_VERSION" ]; then
    # Version mismatch - update the file and notify
    echo "$PLUGIN_VERSION" > "$CLAUDE_PROJECT_DIR/.claude-harness/.plugin-version"
    echo ""
    echo "=== PLUGIN UPDATE DETECTED ==="
    echo "Plugin version: $PLUGIN_VERSION (was: $PROJECT_VERSION)"
    echo ""
    echo "ACTION REQUIRED: Run /claude-harness:setup to update harness files"
    echo ""
fi

# Run project's init.sh if it exists (check new location first, then legacy)
if [ -x "$CLAUDE_PROJECT_DIR/.claude-harness/init.sh" ]; then
    "$CLAUDE_PROJECT_DIR/.claude-harness/init.sh"
elif [ -x "$CLAUDE_PROJECT_DIR/init.sh" ]; then
    "$CLAUDE_PROJECT_DIR/init.sh"
fi
