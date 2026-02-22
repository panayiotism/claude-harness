#!/bin/bash
# TeammateIdle Hook - Quality gate for Agent Teams
# Prevents teammates from going idle when work is incomplete.
# Exit 2 = keep teammate working (with feedback via stderr)
# Exit 0 = allow teammate to idle

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract teammate name (used to determine role-specific checks)
TEAMMATE_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('teammate_name', data.get('teammateName', '')))" 2>/dev/null || echo "")

# Find project root (look for .claude-harness/)
PROJECT_ROOT="$(pwd)"
while [ "$PROJECT_ROOT" != "/" ]; do
    [ -d "$PROJECT_ROOT/.claude-harness" ] && break
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

if [ ! -d "$PROJECT_ROOT/.claude-harness" ]; then
    # No harness found — allow idle
    exit 0
fi

CONFIG_FILE="$PROJECT_ROOT/.claude-harness/config.json"
ISSUES=()

# --- Check 1: Uncommitted changes ---
UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | head -20)
if [ -n "$UNCOMMITTED" ]; then
    FILE_COUNT=$(echo "$UNCOMMITTED" | wc -l | tr -d ' ')
    ISSUES+=("$FILE_COUNT uncommitted files. Stage and commit your work.")
fi

# --- Check 2: Verification commands ---
# Read verification commands from config.json
if [ -f "$CONFIG_FILE" ] && command -v python3 >/dev/null 2>&1; then
    VERIFICATION=$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    config = json.load(f)
v = config.get('verification', {})
# Output: cmd_name=command pairs, one per line
for key in ['build', 'tests', 'lint', 'typecheck', 'acceptance']:
    cmd = v.get(key, '')
    if cmd:
        print(f'{key}={cmd}')
" 2>/dev/null || echo "")

    if [ -n "$VERIFICATION" ]; then
        while IFS= read -r line; do
            CMD_NAME="${line%%=*}"
            CMD_VALUE="${line#*=}"

            # Reviewer teammates only run lint (not full test suite)
            if echo "$TEAMMATE_NAME" | grep -qi "reviewer"; then
                if [ "$CMD_NAME" != "lint" ]; then
                    continue
                fi
            fi

            # Run the verification command with a timeout
            if ! timeout 60 bash -c "cd '$PROJECT_ROOT' && $CMD_VALUE" >/dev/null 2>&1; then
                ISSUES+=("$CMD_NAME failing: $CMD_VALUE")
            fi
        done <<< "$VERIFICATION"
    fi
fi

# --- Report results ---
if [ ${#ISSUES[@]} -gt 0 ]; then
    {
        echo "Cannot go idle - issues to fix:"
        for issue in "${ISSUES[@]}"; do
            echo "- $issue"
        done
    } >&2
    exit 2
fi

# All clear — teammate can idle
exit 0
