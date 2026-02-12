#!/bin/bash
# Claude Harness SessionStart (compact) Hook v7.0.0
# Post-compaction context recovery — re-injects critical state after compaction
# Matcher: "compact" — only fires when source is context compaction
# Complements pre-compact.sh backup with active context restoration

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# ============================================================================
# FIND ACTIVE LOOP STATE
# ============================================================================

LOOP_FEATURE=""
LOOP_ATTEMPT=""
LOOP_MAX=""
TDD_PHASE=""
TEAM_NAME=""
LEAD_MODE=""
SESSIONS_DIR="$HARNESS_DIR/sessions"

if [ -d "$SESSIONS_DIR" ]; then
    for session_dir in "$SESSIONS_DIR"/*/; do
        [ -d "$session_dir" ] || continue
        [ "$(basename "$session_dir")" = ".recovery" ] && continue

        loop_file="$session_dir/loop-state.json"
        [ -f "$loop_file" ] || continue

        status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

        if [ "$status" = "in_progress" ]; then
            LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            LOOP_ATTEMPT=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
            LOOP_MAX=$(grep -o '"maxAttempts"[[:space:]]*:[[:space:]]*[0-9]*' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
            TDD_PHASE=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            TEAM_NAME=$(grep -o '"teamName"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

            # Check for lead mode
            if [ -f "$session_dir/lead-mode" ]; then
                LEAD_MODE=$(cat "$session_dir/lead-mode" 2>/dev/null)
            fi
            break
        fi
    done
fi

# ============================================================================
# BUILD POST-COMPACTION CONTEXT
# ============================================================================

CONTEXT=""

if [ -n "$LOOP_FEATURE" ]; then
    CONTEXT="POST-COMPACTION STATE RECOVERY"
    CONTEXT="$CONTEXT\n\nActive Feature: $LOOP_FEATURE (attempt ${LOOP_ATTEMPT:-1}/${LOOP_MAX:-3})"

    if [ -n "$TDD_PHASE" ]; then
        CONTEXT="$CONTEXT\nTDD Phase: $TDD_PHASE"
    fi

    if [ -n "$TEAM_NAME" ]; then
        CONTEXT="$CONTEXT\nAgent Team: $TEAM_NAME"
    fi

    if [ -n "$LEAD_MODE" ]; then
        CONTEXT="$CONTEXT\nLead Mode: $LEAD_MODE"

        # Read delegate rule if in delegate mode
        if [ "$LEAD_MODE" = "delegate" ]; then
            for session_dir in "$SESSIONS_DIR"/*/; do
                [ -f "$session_dir/delegate-rule" ] || continue
                DELEGATE_RULE=$(cat "$session_dir/delegate-rule" 2>/dev/null)
                if [ -n "$DELEGATE_RULE" ]; then
                    CONTEXT="$CONTEXT\nDelegate Rule: $DELEGATE_RULE"
                fi
                break
            done
        fi
    fi

    # Add recent failures
    FAILURES_FILE="$HARNESS_DIR/memory/episodic/failures.json"
    if [ -f "$FAILURES_FILE" ]; then
        RECENT=$(python3 -c "
import json
try:
    with open('$FAILURES_FILE') as f:
        data = json.load(f)
    entries = data.get('entries', [])[-3:]
    for e in entries:
        print('- ' + e.get('summary', 'unknown')[:80])
except:
    pass
" 2>/dev/null)

        if [ -n "$RECENT" ]; then
            ESCAPED_RECENT=$(echo "$RECENT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
            CONTEXT="$CONTEXT\n\nRecent Failures:\\n$ESCAPED_RECENT"
        fi
    fi

    CONTEXT="$CONTEXT\n\nResume: /claude-harness:flow $LOOP_FEATURE"
    CONTEXT="$CONTEXT\nAll memory layers intact (episodic, procedural, semantic, learned)."
fi

# If no active loop, just confirm memory is intact
if [ -z "$CONTEXT" ]; then
    CONTEXT="POST-COMPACTION: No active feature loop. Memory layers intact."
fi

# Escape for JSON output
CONTEXT_ESCAPED=$(echo -e "$CONTEXT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$CONTEXT_ESCAPED"
  }
}
EOF

exit 0
