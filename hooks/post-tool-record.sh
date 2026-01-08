#!/bin/bash
# Claude Harness PostToolUse Hook v3.4
# Records file modifications to procedural memory
# Called after Write, Edit tools

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"
CHANGES_FILE="$HARNESS_DIR/memory/procedural/file-changes.json"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    echo '{"continue": true}'
    exit 0
fi

# Ensure memory directories exist
mkdir -p "$HARNESS_DIR/memory/procedural" 2>/dev/null

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract tool name and file path
TOOL_NAME=$(echo "$HOOK_INPUT" | grep -o '"toolName"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
TOOL_USE_ID=$(echo "$HOOK_INPUT" | grep -o '"tool_use_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# If no file path from file_path, try path
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Only record if we have a file path
if [ -z "$FILE_PATH" ]; then
    echo '{"continue": true}'
    exit 0
fi

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get active loop feature (if any)
LOOP_FEATURE=""
if [ -f "$HARNESS_DIR/loops/state.json" ]; then
    LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/loops/state.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Initialize file-changes.json if it doesn't exist
if [ ! -f "$CHANGES_FILE" ]; then
    echo '{"version": 1, "changes": []}' > "$CHANGES_FILE"
fi

# Create new change entry
# Using a simple approach to append without full JSON parsing
# This creates a temp file and rebuilds the JSON
TEMP_FILE=$(mktemp)
NEW_ENTRY="{\"timestamp\": \"$TIMESTAMP\", \"tool\": \"$TOOL_NAME\", \"file\": \"$FILE_PATH\", \"feature\": \"$LOOP_FEATURE\", \"toolUseId\": \"$TOOL_USE_ID\"}"

# Read existing changes, append new one
# Simple approach: extract changes array, append, rebuild
if command -v jq &> /dev/null; then
    # Use jq if available (preferred)
    jq --arg ts "$TIMESTAMP" --arg tool "$TOOL_NAME" --arg file "$FILE_PATH" --arg feat "$LOOP_FEATURE" --arg tuid "$TOOL_USE_ID" \
        '.changes += [{"timestamp": $ts, "tool": $tool, "file": $file, "feature": $feat, "toolUseId": $tuid}]' \
        "$CHANGES_FILE" > "$TEMP_FILE" 2>/dev/null

    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$CHANGES_FILE"
    else
        rm -f "$TEMP_FILE"
    fi
else
    # Fallback: simple append (less robust but works without jq)
    # Read the file, remove closing brackets, append entry, close
    EXISTING=$(cat "$CHANGES_FILE")
    # Remove trailing }
    EXISTING="${EXISTING%\}}"
    # Remove trailing ]
    EXISTING="${EXISTING%\]}"
    # Check if there are existing entries (contains a {)
    if echo "$EXISTING" | grep -q '"timestamp"'; then
        # Has entries, add comma
        echo "${EXISTING}, $NEW_ENTRY]}" > "$CHANGES_FILE"
    else
        # No entries yet
        echo "${EXISTING}$NEW_ENTRY]}" > "$CHANGES_FILE"
    fi
fi

rm -f "$TEMP_FILE" 2>/dev/null

# Output success
echo '{"continue": true}'
