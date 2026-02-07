#!/bin/bash
# Claude Harness UserPromptSubmit Hook v5.1.4
# Provides smart routing context when user submits a prompt
# Checks for active loops and injects relevant context

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    echo '{"continue": true}'
    exit 0
fi

# ============================================================================
# ACTIVE LOOP DETECTION
# ============================================================================

LOOP_FEATURE=""
LOOP_STATUS=""
LOOP_ATTEMPT=""
LOOP_MAX=""
LOOP_TYPE=""
ADDITIONAL_CONTEXT=""

# Check for session-scoped loop state first
SESSIONS_DIR="$HARNESS_DIR/sessions"
if [ -d "$SESSIONS_DIR" ]; then
    # Find most recent active session with an in_progress loop
    for session_dir in "$SESSIONS_DIR"/*/; do
        [ -d "$session_dir" ] || continue

        loop_file="$session_dir/loop-state.json"
        [ -f "$loop_file" ] || continue

        status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

        if [ "$status" = "in_progress" ]; then
            LOOP_STATUS="$status"
            LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            LOOP_ATTEMPT=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
            LOOP_MAX=$(grep -o '"maxAttempts"[[:space:]]*:[[:space:]]*[0-9]*' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
            LOOP_TYPE=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            break
        fi
    done
fi

# Fallback to legacy loop state location
if [ -z "$LOOP_FEATURE" ]; then
    for legacy_path in "$HARNESS_DIR/loops/state.json" "$HARNESS_DIR/loop-state.json"; do
        if [ -f "$legacy_path" ]; then
            status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$legacy_path" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

            if [ "$status" = "in_progress" ]; then
                LOOP_STATUS="$status"
                LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$legacy_path" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                LOOP_ATTEMPT=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$legacy_path" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
                LOOP_MAX=$(grep -o '"maxAttempts"[[:space:]]*:[[:space:]]*[0-9]*' "$legacy_path" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
                LOOP_TYPE=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' "$legacy_path" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                break
            fi
        fi
    done
fi

# ============================================================================
# BUILD CONTEXT IF ACTIVE LOOP EXISTS
# ============================================================================

# Validate feature still exists in active.json (prevent stale loop-state false positives)
if [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
    FEATURES_FILE="$HARNESS_DIR/features/active.json"
    if [ -f "$FEATURES_FILE" ]; then
        if ! grep -q "\"$LOOP_FEATURE\"" "$FEATURES_FILE" 2>/dev/null; then
            # Feature not in active.json - stale loop-state, ignore it
            LOOP_FEATURE=""
            LOOP_STATUS=""
        fi
    fi
fi

if [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
    if [ "$LOOP_TYPE" = "fix" ]; then
        ADDITIONAL_CONTEXT="[ACTIVE FIX IN PROGRESS]\nFix: $LOOP_FEATURE\nAttempt: $LOOP_ATTEMPT/$LOOP_MAX\n\nResume with: /claude-harness:flow $LOOP_FEATURE"
    else
        ADDITIONAL_CONTEXT="[ACTIVE FEATURE IN PROGRESS]\nFeature: $LOOP_FEATURE\nAttempt: $LOOP_ATTEMPT/$LOOP_MAX\n\nResume with: /claude-harness:flow $LOOP_FEATURE"
    fi
fi

# ============================================================================
# OUTPUT JSON
# ============================================================================

if [ -n "$ADDITIONAL_CONTEXT" ]; then
    # Escape for JSON
    CONTEXT_ESCAPED=$(echo -e "$ADDITIONAL_CONTEXT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    cat << EOF
{
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "activeLoop": {
      "feature": "$LOOP_FEATURE",
      "status": "$LOOP_STATUS",
      "attempt": $LOOP_ATTEMPT,
      "maxAttempts": $LOOP_MAX,
      "type": "$LOOP_TYPE"
    },
    "additionalContext": "$CONTEXT_ESCAPED"
  }
}
EOF
else
    # No active loop - pass through
    echo '{"continue": true}'
fi
