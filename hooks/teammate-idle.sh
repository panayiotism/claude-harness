#!/bin/bash
# Claude Harness TeammateIdle Hook v7.1.0
# Runs when an Agent Team teammate finishes work and is about to go idle
# Exit code 0: let teammate go idle
# Exit code 2: send feedback to keep teammate working
# v7.1.0: Parallel verification + single config call for performance

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
# CHECK 2-4: Tests, lint, typecheck from config (parallel)
# ============================================================================

CONFIG_FILE="$HARNESS_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    # Single call to extract all verification commands
    eval $(python3 -c "
import json; c=json.load(open('$CONFIG_FILE')); v=c.get('verification',{})
print(f'TEST_CMD=\"{v.get(\"tests\",\"\")}\"')
print(f'LINT_CMD=\"{v.get(\"lint\",\"\")}\"')
print(f'TC_CMD=\"{v.get(\"typecheck\",\"\")}\"')
" 2>/dev/null)

    # Run checks in parallel with background processes
    TEST_RESULT=0; LINT_RESULT=0; TC_RESULT=0
    TEST_PID=""; LINT_PID=""; TC_PID=""

    if [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ]; then
        (timeout 10 bash -c "$TEST_CMD" > /dev/null 2>&1) &
        TEST_PID=$!
    fi

    if [ -n "$LINT_CMD" ] && [ "$LINT_CMD" != "" ]; then
        (timeout 10 bash -c "$LINT_CMD" > /dev/null 2>&1) &
        LINT_PID=$!
    fi

    if [ -n "$TC_CMD" ] && [ "$TC_CMD" != "" ]; then
        (timeout 10 bash -c "$TC_CMD" > /dev/null 2>&1) &
        TC_PID=$!
    fi

    # Wait for all parallel results
    if [ -n "$TEST_PID" ]; then wait $TEST_PID 2>/dev/null || TEST_RESULT=$?; fi
    if [ -n "$LINT_PID" ]; then wait $LINT_PID 2>/dev/null || LINT_RESULT=$?; fi
    if [ -n "$TC_PID" ]; then wait $TC_PID 2>/dev/null || TC_RESULT=$?; fi

    if [ $TEST_RESULT -ne 0 ]; then FAILURES="${FAILURES}\n- Tests failing: $TEST_CMD"; fi
    if [ $LINT_RESULT -ne 0 ]; then FAILURES="${FAILURES}\n- Lint failing: $LINT_CMD"; fi
    if [ $TC_RESULT -ne 0 ]; then FAILURES="${FAILURES}\n- Typecheck failing: $TC_CMD"; fi
fi

# ============================================================================
# REPORT ALL FAILURES AT ONCE
# ============================================================================

if [ -n "$FAILURES" ]; then
    echo -e "Cannot go idle — issues to fix:$FAILURES" >&2
    exit 2
fi

exit 0
