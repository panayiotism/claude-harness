#!/bin/bash
# Claude Harness TeammateIdle Hook v6.4.0
# Runs when an Agent Team teammate finishes work and is about to go idle
# Exit code 0: let teammate go idle
# Exit code 2: send feedback to keep teammate working
# v6.4.0: Added lint + typecheck gates, collect all failures

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Read stdin for teammate context
INPUT=$(cat 2>/dev/null || true)

FAILURES=""

# ============================================================================
# CHECK 1: Uncommitted changes
# ============================================================================

UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -gt 0 ]; then
    FAILURES="${FAILURES}\n- Uncommitted changes: $UNCOMMITTED files. Stage and commit your work."
fi

# ============================================================================
# CHECK 2-4: Tests, lint, typecheck from config
# ============================================================================

CONFIG_FILE="$HARNESS_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('tests',''))" 2>/dev/null)
    LINT_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('lint',''))" 2>/dev/null)
    TC_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('typecheck',''))" 2>/dev/null)

    # Tests
    if [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ]; then
        if ! eval "$TEST_CMD" > /dev/null 2>&1; then
            FAILURES="${FAILURES}\n- Tests failing: $TEST_CMD"
        fi
    fi

    # Lint (v6.4.0)
    if [ -n "$LINT_CMD" ] && [ "$LINT_CMD" != "" ]; then
        if ! eval "$LINT_CMD" > /dev/null 2>&1; then
            FAILURES="${FAILURES}\n- Lint failing: $LINT_CMD"
        fi
    fi

    # Typecheck (v6.4.0)
    if [ -n "$TC_CMD" ] && [ "$TC_CMD" != "" ]; then
        if ! eval "$TC_CMD" > /dev/null 2>&1; then
            FAILURES="${FAILURES}\n- Typecheck failing: $TC_CMD"
        fi
    fi
fi

# ============================================================================
# REPORT ALL FAILURES AT ONCE
# ============================================================================

if [ -n "$FAILURES" ]; then
    echo -e "Cannot go idle — issues to fix:$FAILURES" >&2
    exit 2
fi

exit 0
