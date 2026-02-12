#!/bin/bash
# Claude Harness TaskCompleted Hook v7.1.0
# Runs when an Agent Team task is being marked as complete
# Exit code 0: allow completion
# Exit code 2: prevent completion, send feedback
# v7.1.0: Single test run + single python3 call for performance

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Read task info from environment/stdin
TASK_TITLE="${CLAUDE_TASK_TITLE:-}"

# Read stdin for additional context (teammate_name etc.)
INPUT=$(cat 2>/dev/null || true)

# Check if this is a verification-related task
IS_VERIFY_TASK=""
if echo "$TASK_TITLE" | grep -qi "verify\|checkpoint\|review\|accept"; then
    IS_VERIFY_TASK="yes"
fi

# ============================================================================
# CONFIG PARSING: Single python3 call for all verification commands
# ============================================================================

CONFIG_FILE="$HARNESS_DIR/config.json"
TEST_CMD=""; LINT_CMD=""; BUILD_CMD=""; ACCEPT_CMD=""

if [ -f "$CONFIG_FILE" ]; then
    eval $(python3 -c "
import json; c=json.load(open('$CONFIG_FILE')); v=c.get('verification',{})
print(f'TEST_CMD=\"{v.get(\"tests\",\"\")}\"')
print(f'LINT_CMD=\"{v.get(\"lint\",\"\")}\"')
print(f'BUILD_CMD=\"{v.get(\"build\",\"\")}\"')
print(f'ACCEPT_CMD=\"{v.get(\"acceptance\",\"\")}\"')
" 2>/dev/null)
fi

# ============================================================================
# RUN TESTS ONCE: Cache result for both TDD and general verification
# ============================================================================

TEST_EXIT=-1
if [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ]; then
    timeout 10 bash -c "$TEST_CMD" > /dev/null 2>&1
    TEST_EXIT=$?
fi

# ============================================================================
# TDD PHASE VALIDATION (v6.4.0)
# ============================================================================

# Find active loop-state to get TDD phase
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
            TDD_PHASE=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
            break
        fi
    done
fi

# If TDD phase is active, validate test expectations using cached result
if [ -n "$TDD_PHASE" ] && [ -n "$IS_VERIFY_TASK" ]; then
    if [ $TEST_EXIT -ge 0 ]; then
        case "$TDD_PHASE" in
            red)
                if [ $TEST_EXIT -eq 0 ]; then
                    echo "TDD RED phase: Tests should FAIL but are passing. Write a failing test first before marking complete." >&2
                    exit 2
                fi
                ;;
            green)
                if [ $TEST_EXIT -ne 0 ]; then
                    echo "TDD GREEN phase: Tests must PASS before marking complete. Fix the implementation." >&2
                    exit 2
                fi
                ;;
            refactor)
                if [ $TEST_EXIT -ne 0 ]; then
                    echo "TDD REFACTOR phase: Tests must still PASS after refactoring. Your refactor broke something." >&2
                    exit 2
                fi
                ;;
            accept)
                if [ $TEST_EXIT -ne 0 ]; then
                    echo "TDD ACCEPT phase: Unit tests must still PASS during acceptance testing. Your acceptance fix broke unit tests." >&2
                    exit 2
                fi
                # Also run acceptance tests if configured
                if [ -n "$ACCEPT_CMD" ] && [ "$ACCEPT_CMD" != "" ]; then
                    timeout 10 bash -c "$ACCEPT_CMD" > /dev/null 2>&1
                    ACCEPT_EXIT=$?
                    if [ $ACCEPT_EXIT -ne 0 ]; then
                        echo "TDD ACCEPT phase: Acceptance tests FAILED. The feature does not meet end-to-end expectations." >&2
                        exit 2
                    fi
                fi
                ;;
        esac
    fi
fi

# ============================================================================
# EXISTING: Verification gate for verify/checkpoint/review tasks
# ============================================================================

# Only run verification for verify/checkpoint/review tasks
if echo "$TASK_TITLE" | grep -qi "verify\|checkpoint\|review\|accept"; then
    FAILURES=""

    if [ -n "$BUILD_CMD" ] && [ "$BUILD_CMD" != "" ]; then
        if ! timeout 10 bash -c "$BUILD_CMD" > /dev/null 2>&1; then
            FAILURES="${FAILURES}\n- Build failed: $BUILD_CMD"
        fi
    fi

    # Use cached test result instead of running again
    if [ $TEST_EXIT -gt 0 ]; then
        FAILURES="${FAILURES}\n- Tests failed: $TEST_CMD"
    fi

    if [ -n "$LINT_CMD" ] && [ "$LINT_CMD" != "" ]; then
        if ! timeout 10 bash -c "$LINT_CMD" > /dev/null 2>&1; then
            FAILURES="${FAILURES}\n- Lint failed: $LINT_CMD"
        fi
    fi

    if [ -n "$ACCEPT_CMD" ] && [ "$ACCEPT_CMD" != "" ]; then
        if ! timeout 10 bash -c "$ACCEPT_CMD" > /dev/null 2>&1; then
            FAILURES="${FAILURES}\n- Acceptance tests failed: $ACCEPT_CMD"
        fi
    fi

    if [ -n "$FAILURES" ]; then
        echo -e "Verification failures - task cannot be marked complete:$FAILURES"
        exit 2
    fi
fi

exit 0
