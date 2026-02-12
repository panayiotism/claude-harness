#!/bin/bash
# Claude Harness PostToolUse Hook v7.0.0
# Async streaming verification — runs tests in background after code edits
# Matcher: "Edit|Write", async: true
# Results delivered next turn as additionalContext

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Read stdin JSON
INPUT=$(cat)

# Extract the file path from tool_input
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Skip non-code files
case "$FILE_PATH" in
    *.md|*.json|*.txt|*.yml|*.yaml|*.toml|*.lock|*.cfg|*.ini|*.env|*.gitignore)
        exit 0
        ;;
esac

# Skip harness internal files
if echo "$FILE_PATH" | grep -qE '\.(claude-harness|claude)/'; then
    exit 0
fi

# Read test command from config
CONFIG_FILE="$HARNESS_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    exit 0
fi

TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('tests',''))" 2>/dev/null)

if [ -z "$TEST_CMD" ] || [ "$TEST_CMD" = "" ]; then
    exit 0
fi

# Run tests and capture output
TEST_OUTPUT=$(timeout 10 bash -c "$TEST_CMD" 2>&1)
TEST_EXIT=$?

# Truncate to last 20 lines
TRUNCATED=$(echo "$TEST_OUTPUT" | tail -20)

# Build context based on result
FILENAME=$(basename "$FILE_PATH")
if [ $TEST_EXIT -eq 0 ]; then
    CONTEXT="[ASYNC TEST] PASS after editing $FILENAME"
else
    # Escape for JSON
    ESCAPED_OUTPUT=$(echo "$TRUNCATED" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    CONTEXT="[ASYNC TEST] FAIL after editing $FILENAME\\n$ESCAPED_OUTPUT"
fi

# Output JSON with additionalContext
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "$CONTEXT"
  }
}
EOF

exit 0
