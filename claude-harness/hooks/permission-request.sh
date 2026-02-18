#!/bin/bash
# Claude Harness PermissionRequest Hook
# Autonomous mode acceleration — auto-approve safe ops, auto-deny destructive
# No matcher — fires for all permission requests
# No-op when not in autonomous mode

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# ============================================================================
# CHECK FOR AUTONOMOUS MODE
# ============================================================================

AUTONOMOUS=false
SESSIONS_DIR="$HARNESS_DIR/sessions"
if [ -d "$SESSIONS_DIR" ]; then
    for session_dir in "$SESSIONS_DIR"/*/; do
        [ -d "$session_dir" ] || continue
        if [ -f "$session_dir/autonomous-state.json" ]; then
            AUTONOMOUS=true
            break
        fi
    done
fi

# Not in autonomous mode — let user handle permissions normally
if [ "$AUTONOMOUS" = false ]; then
    exit 0
fi

# ============================================================================
# READ REQUEST
# ============================================================================

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# ============================================================================
# DENY LIST — block even in autonomous mode
# ============================================================================

if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
    # Force push
    if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force'; then
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "deny",
      "message": "AUTONOMOUS DENY: git push --force is destructive even in autonomous mode."
    }
  }
}
EOF
        exit 0
    fi

    # Reset hard
    if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "deny",
      "message": "AUTONOMOUS DENY: git reset --hard discards changes."
    }
  }
}
EOF
        exit 0
    fi

    # Broad rm -rf
    if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f?\s+(/|~|\.\.)'; then
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "deny",
      "message": "AUTONOMOUS DENY: Broad rm -rf is too destructive."
    }
  }
}
EOF
        exit 0
    fi
fi

# ============================================================================
# ALLOW LIST — auto-approve safe operations in autonomous mode
# ============================================================================

if [ "$TOOL_NAME" = "Bash" ] && [ -n "$COMMAND" ]; then
    ALLOW=false

    # Read-only git operations
    if echo "$COMMAND" | grep -qE '^git\s+(status|log|diff|branch|show|rev-parse|describe|remote|fetch)\b'; then
        ALLOW=true
    fi

    # Safe git operations on feature branches
    if echo "$COMMAND" | grep -qE '^git\s+(add|commit|stash)\b'; then
        ALLOW=true
    fi

    # Non-force, non-main push
    if echo "$COMMAND" | grep -qE '^git\s+push\b' && \
       ! echo "$COMMAND" | grep -qE '(--force|origin\s+(main|master)\b)'; then
        ALLOW=true
    fi

    # Test/build/lint commands from config
    CONFIG_FILE="$HARNESS_DIR/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('tests',''))" 2>/dev/null)
        BUILD_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('build',''))" 2>/dev/null)
        LINT_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('lint',''))" 2>/dev/null)
        TC_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('typecheck',''))" 2>/dev/null)

        [ -n "$TEST_CMD" ] && echo "$COMMAND" | grep -qF "$TEST_CMD" && ALLOW=true
        [ -n "$BUILD_CMD" ] && echo "$COMMAND" | grep -qF "$BUILD_CMD" && ALLOW=true
        [ -n "$LINT_CMD" ] && echo "$COMMAND" | grep -qF "$LINT_CMD" && ALLOW=true
        [ -n "$TC_CMD" ] && echo "$COMMAND" | grep -qF "$TC_CMD" && ALLOW=true
    fi

    # Package managers (install only)
    if echo "$COMMAND" | grep -qE '^(npm|yarn|pnpm)\s+install\b'; then
        ALLOW=true
    fi
    if echo "$COMMAND" | grep -qE '^pip\s+install\b'; then
        ALLOW=true
    fi

    if [ "$ALLOW" = true ]; then
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  }
}
EOF
        exit 0
    fi
fi

# For Edit/Write tools — auto-approve in autonomous mode (PreToolUse handles safety)
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  }
}
EOF
    exit 0
fi

# For Read/Glob/Grep — auto-approve (read-only)
if [ "$TOOL_NAME" = "Read" ] || [ "$TOOL_NAME" = "Glob" ] || [ "$TOOL_NAME" = "Grep" ]; then
    cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow"
    }
  }
}
EOF
    exit 0
fi

# Unrecognized tool — let user decide
exit 0
