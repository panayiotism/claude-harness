#!/bin/bash
# Claude Harness TeammateIdle Hook v6.0.0
# Runs when an Agent Team teammate finishes work and is about to go idle
# Exit code 0: let teammate go idle
# Exit code 2: send feedback to keep teammate working

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -gt 0 ]; then
    echo "You have uncommitted changes. Please stage and commit your work before going idle."
    exit 2
fi

# Run tests if config exists
CONFIG_FILE="$HARNESS_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    TEST_CMD=$(python3 -c "import json; c=json.load(open('$CONFIG_FILE')); print(c.get('verification',{}).get('tests',''))" 2>/dev/null)
    if [ -n "$TEST_CMD" ] && [ "$TEST_CMD" != "" ]; then
        if ! eval "$TEST_CMD" > /dev/null 2>&1; then
            echo "Tests are failing. Please fix failing tests before going idle."
            exit 2
        fi
    fi
fi

exit 0
