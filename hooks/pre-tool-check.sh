#!/bin/bash
# Claude Harness PreToolUse Hook v3.4
# Checks learned rules before tool execution
# Called before Write, Edit, Bash tools

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"
RULES_FILE="$HARNESS_DIR/memory/learned/rules.json"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    echo '{"continue": true}'
    exit 0
fi

# Skip if no learned rules exist
if [ ! -f "$RULES_FILE" ]; then
    echo '{"continue": true}'
    exit 0
fi

# Read hook input from stdin (Claude Code passes JSON)
HOOK_INPUT=$(cat)

# Extract tool name and parameters from input
TOOL_NAME=$(echo "$HOOK_INPUT" | grep -o '"toolName"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# If no file path, check for path parameter (different tools use different names)
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$HOOK_INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Count active rules
RULE_COUNT=$(grep -c '"active"[[:space:]]*:[[:space:]]*true' "$RULES_FILE" 2>/dev/null || echo "0")

# If we have rules and a file path, check for applicable rules
WARNINGS=""
if [ "$RULE_COUNT" -gt 0 ] && [ -n "$FILE_PATH" ]; then
    # Get file extension
    FILE_EXT="${FILE_PATH##*.}"

    # Read rules and check for matches
    # This is a simplified check - looks for rules with matching file patterns
    while IFS= read -r line; do
        if echo "$line" | grep -q "\"filePatterns\""; then
            # Check if this rule applies to our file type
            if echo "$line" | grep -q "\"*.$FILE_EXT\"" || echo "$line" | grep -q '"always"[[:space:]]*:[[:space:]]*true'; then
                # Extract rule title for warning
                RULE_TITLE=$(echo "$line" | grep -o '"title"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                if [ -n "$RULE_TITLE" ]; then
                    if [ -n "$WARNINGS" ]; then
                        WARNINGS="$WARNINGS, $RULE_TITLE"
                    else
                        WARNINGS="$RULE_TITLE"
                    fi
                fi
            fi
        fi
    done < "$RULES_FILE"
fi

# Build response
if [ -n "$WARNINGS" ]; then
    # We have applicable rules - remind Claude about them
    WARNING_MSG="Learned rules to follow: $WARNINGS"
    WARNING_ESCAPED=$(echo "$WARNING_MSG" | sed 's/"/\\"/g')

    cat << EOF
{
  "continue": true,
  "systemMessage": "$WARNING_ESCAPED"
}
EOF
else
    # No warnings needed
    echo '{"continue": true}'
fi
