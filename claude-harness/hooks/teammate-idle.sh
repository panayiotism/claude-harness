#!/bin/bash
# Claude Harness TeammateIdle Hook v7.0.0
# Runs when an Agent Team teammate finishes work and is about to go idle
# Exit code 0: let teammate go idle
# Exit code 2: send feedback to keep teammate working
# v6.4.0: Added lint + typecheck gates, collect all failures
# v7.0.0: Single config parse, parallel exec

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
# CHECK 2-4: Tests, lint, typecheck from config (v7.0.0: single parse, parallel exec)
# ============================================================================

CONFIG_FILE="$HARNESS_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    eval $(python3 -c "
import json, shlex
c=json.load(open('$CONFIG_FILE'))
v=c.get('verification',{})
print('TEST_CMD=%s' % shlex.quote(v.get('tests','')))
print('LINT_CMD=%s' % shlex.quote(v.get('lint','')))
print('TC_CMD=%s' % shlex.quote(v.get('typecheck','')))
" 2>/dev/null)

    # Run checks in parallel
    TEST_PID=""
    LINT_PID=""
    TC_PID=""

    if [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ]; then
        timeout 10 bash -c "$TEST_CMD" > /dev/null 2>&1 &
        TEST_PID=$!
    fi

    if [ -n "$LINT_CMD" ] && [ "$LINT_CMD" != "" ]; then
        timeout 10 bash -c "$LINT_CMD" > /dev/null 2>&1 &
        LINT_PID=$!
    fi

    if [ -n "$TC_CMD" ] && [ "$TC_CMD" != "" ]; then
        timeout 10 bash -c "$TC_CMD" > /dev/null 2>&1 &
        TC_PID=$!
    fi

    # Wait for all parallel jobs and collect results
    wait

    if [ -n "$TEST_PID" ]; then
        wait $TEST_PID 2>/dev/null || FAILURES="${FAILURES}\n- Tests failing: $TEST_CMD"
    fi

    if [ -n "$LINT_PID" ]; then
        wait $LINT_PID 2>/dev/null || FAILURES="${FAILURES}\n- Lint failing: $LINT_CMD"
    fi

    if [ -n "$TC_PID" ]; then
        wait $TC_PID 2>/dev/null || FAILURES="${FAILURES}\n- Typecheck failing: $TC_CMD"
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
