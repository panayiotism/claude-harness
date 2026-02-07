#!/bin/bash
# Claude Harness TaskCompleted Hook v6.0.0
# Runs when an Agent Team task is being marked as complete
# Exit code 0: allow completion
# Exit code 2: prevent completion, send feedback

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Read task info from environment/stdin
TASK_TITLE="${CLAUDE_TASK_TITLE:-}"

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
