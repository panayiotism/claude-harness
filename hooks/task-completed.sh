#!/bin/bash
# Claude Harness TaskCompleted Hook v6.4.0
# Runs when an Agent Team task is being marked as complete
# Exit code 0: allow completion
# Exit code 2: prevent completion, send feedback
# v6.4.0: Added TDD phase validation gate

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Read task info from environment/stdin
TASK_TITLE="${CLAUDE_TASK_TITLE:-}"

# Read stdin for additional context (teammate_name etc.)
INPUT=$(cat 2>/dev/null || true)

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

# If TDD phase is active, validate test expectations
if [ -n "$TDD_PHASE" ]; then
    CONFIG_FILE="$HARNESS_DIR/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('tests',''))" 2>/dev/null)

        if [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ]; then
            eval "$TEST_CMD" > /dev/null 2>&1
            TEST_EXIT=$?

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
            esac
        fi
    fi
fi

# ============================================================================
# EXISTING: Verification gate for verify/checkpoint/review tasks
# ============================================================================

# Only run verification for verify/checkpoint/review tasks
if echo "$TASK_TITLE" | grep -qi "verify\|checkpoint\|review"; then
    CONFIG_FILE="$HARNESS_DIR/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        FAILURES=""

        BUILD_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('build',''))" 2>/dev/null)
        TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('tests',''))" 2>/dev/null)
        LINT_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('lint',''))" 2>/dev/null)

        if [ -n "$BUILD_CMD" ] && [ "$BUILD_CMD" != "" ]; then
            if ! eval "$BUILD_CMD" > /dev/null 2>&1; then
                FAILURES="${FAILURES}\n- Build failed: $BUILD_CMD"
            fi
        fi

        if [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ]; then
            if ! eval "$TEST_CMD" > /dev/null 2>&1; then
                FAILURES="${FAILURES}\n- Tests failed: $TEST_CMD"
            fi
        fi

        if [ -n "$LINT_CMD" ] && [ "$LINT_CMD" != "" ]; then
            if ! eval "$LINT_CMD" > /dev/null 2>&1; then
                FAILURES="${FAILURES}\n- Lint failed: $LINT_CMD"
            fi
        fi

        if [ -n "$FAILURES" ]; then
            echo -e "Verification failures - task cannot be marked complete:$FAILURES"
            exit 2
        fi
    fi
fi

exit 0
