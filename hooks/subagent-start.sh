#!/bin/bash
# Claude Harness SubagentStart Hook v7.0.0
# Teammate context injection — injects harness state into spawned teammates
# No matcher — fires for all subagent/teammate starts
# Injects: active feature, TDD phase, recent failures, verification cmds

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# ============================================================================
# FIND ACTIVE LOOP STATE (same pattern as user-prompt-submit.sh)
# ============================================================================

LOOP_FEATURE=""
LOOP_ATTEMPT=""
TDD_PHASE=""
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
            TDD_PHASE=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            break
        fi
    done
fi

# Skip if no active loop
if [ -z "$LOOP_FEATURE" ]; then
    exit 0
fi

# ============================================================================
# BUILD COMPACT CONTEXT (~500 chars max)
# ============================================================================

CONTEXT="[HARNESS] Feature: $LOOP_FEATURE | Attempt: ${LOOP_ATTEMPT:-1}"

# Add TDD phase if set
if [ -n "$TDD_PHASE" ]; then
    CONTEXT="$CONTEXT | TDD: $TDD_PHASE"
fi

# Add verification commands from config
CONFIG_FILE="$HARNESS_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('tests',''))" 2>/dev/null)
    BUILD_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('build',''))" 2>/dev/null)
    LINT_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('lint',''))" 2>/dev/null)

    CMDS=""
    [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ] && CMDS="test: $TEST_CMD"
    [ -n "$BUILD_CMD" ] && [ "$BUILD_CMD" != "" ] && CMDS="$CMDS | build: $BUILD_CMD"
    [ -n "$LINT_CMD" ] && [ "$LINT_CMD" != "" ] && CMDS="$CMDS | lint: $LINT_CMD"

    if [ -n "$CMDS" ]; then
        CONTEXT="$CONTEXT\\nVerify: $CMDS"
    fi
fi

# Add last 3 failures (one-line summaries)
FAILURES_FILE="$HARNESS_DIR/memory/episodic/failures.json"
if [ -f "$FAILURES_FILE" ]; then
    RECENT_FAILURES=$(python3 -c "
import json
try:
    with open('$FAILURES_FILE') as f:
        data = json.load(f)
    entries = data.get('entries', [])[-3:]
    for e in entries:
        summary = e.get('summary', e.get('error', 'unknown'))[:80]
        print(summary)
except:
    pass
" 2>/dev/null)

    if [ -n "$RECENT_FAILURES" ]; then
        ESCAPED_FAILURES=$(echo "$RECENT_FAILURES" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/; /g')
        CONTEXT="$CONTEXT\\nRecent failures: $ESCAPED_FAILURES"
    fi
fi

# Add learned rules (titles only)
RULES_FILE="$HARNESS_DIR/memory/procedural/learned-rules.json"
if [ -f "$RULES_FILE" ]; then
    RULES=$(python3 -c "
import json
try:
    with open('$RULES_FILE') as f:
        data = json.load(f)
    entries = data.get('entries', [])[-5:]
    titles = [e.get('title', '')[:40] for e in entries if e.get('title')]
    print('; '.join(titles))
except:
    pass
" 2>/dev/null)

    if [ -n "$RULES" ]; then
        CONTEXT="$CONTEXT\\nRules: $RULES"
    fi
fi

# Escape context for JSON
CONTEXT_ESCAPED=$(echo -e "$CONTEXT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "additionalContext": "$CONTEXT_ESCAPED"
  }
}
EOF

exit 0
