#!/bin/bash
# TaskCompleted Hook - ATDD verification gate for Agent Teams
# Enforces quality gates when tasks are marked complete.
# Exit 2 = prevent task completion (with feedback via stderr)
# Exit 0 = allow task completion

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract task info
TASK_INFO=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
subject = data.get('task_subject', data.get('taskSubject', ''))
teammate = data.get('teammate_name', data.get('teammateName', ''))
print(f'{subject}|||{teammate}')
" 2>/dev/null || echo "|||")

TASK_SUBJECT="${TASK_INFO%%|||*}"
TEAMMATE_NAME="${TASK_INFO##*|||}"

# Find project root
PROJECT_ROOT="$(pwd)"
while [ "$PROJECT_ROOT" != "/" ]; do
    [ -d "$PROJECT_ROOT/.claude-harness" ] && break
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

if [ ! -d "$PROJECT_ROOT/.claude-harness" ]; then
    exit 0
fi

CONFIG_FILE="$PROJECT_ROOT/.claude-harness/config.json"
SUBJECT_LOWER=$(echo "$TASK_SUBJECT" | tr '[:upper:]' '[:lower:]')
ISSUES=()

# Determine which verification gate to apply based on task subject
run_verification() {
    local CMD_NAME="$1"
    local CMD_VALUE="$2"
    if [ -n "$CMD_VALUE" ]; then
        if ! timeout 120 bash -c "cd '$PROJECT_ROOT' && $CMD_VALUE" >/dev/null 2>&1; then
            ISSUES+=("$CMD_NAME failing: $CMD_VALUE")
        fi
    fi
}

# Read verification commands from config.json
if [ -f "$CONFIG_FILE" ] && command -v python3 >/dev/null 2>&1; then
    eval "$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
v = config.get('verification', {})
for key in ['build', 'tests', 'lint', 'typecheck', 'acceptance']:
    cmd = v.get(key, '')
    # Shell-escape the command value
    escaped = cmd.replace(\"'\", \"'\\\"'\\\"'\")
    print(f\"V_{key.upper()}='{escaped}'\")
" 2>/dev/null)"
fi

# --- ATDD Gate Logic ---

if echo "$SUBJECT_LOWER" | grep -q "acceptance test\|write.*test"; then
    # RED phase: Acceptance test task
    # Verify that test files were created (tests may fail — that's expected)
    # Just check that the test command can be invoked
    if [ -n "${V_ACCEPTANCE:-}" ]; then
        # Run acceptance tests — allowed to fail (RED phase)
        # We just verify the command doesn't error out completely (e.g. missing files)
        timeout 120 bash -c "cd '$PROJECT_ROOT' && $V_ACCEPTANCE" >/dev/null 2>&1 || true
    fi
    if [ -n "${V_TESTS:-}" ]; then
        timeout 120 bash -c "cd '$PROJECT_ROOT' && $V_TESTS" >/dev/null 2>&1 || true
    fi
    # No gate enforcement for RED phase — tests are expected to fail

elif echo "$SUBJECT_LOWER" | grep -q "^implement\|implementation"; then
    # GREEN phase: Implementation task
    # Acceptance tests MUST pass now (implementer's job is to make them green)
    if [ -n "${V_ACCEPTANCE:-}" ]; then
        run_verification "acceptance" "$V_ACCEPTANCE"
    fi
    if [ -n "${V_TESTS:-}" ]; then
        run_verification "tests" "$V_TESTS"
    fi

elif echo "$SUBJECT_LOWER" | grep -q "verif\|accept\|checkpoint\|final"; then
    # Full verification gate — ALL commands must pass
    [ -n "${V_BUILD:-}" ] && run_verification "build" "$V_BUILD"
    [ -n "${V_TESTS:-}" ] && run_verification "tests" "$V_TESTS"
    [ -n "${V_LINT:-}" ] && run_verification "lint" "$V_LINT"
    [ -n "${V_TYPECHECK:-}" ] && run_verification "typecheck" "$V_TYPECHECK"
    [ -n "${V_ACCEPTANCE:-}" ] && run_verification "acceptance" "$V_ACCEPTANCE"

elif echo "$SUBJECT_LOWER" | grep -q "review\|feedback"; then
    # Review/feedback tasks — only check lint (code quality)
    [ -n "${V_LINT:-}" ] && run_verification "lint" "$V_LINT"

else
    # Unknown task type — no enforcement
    exit 0
fi

# --- Report results ---
if [ ${#ISSUES[@]} -gt 0 ]; then
    {
        echo "Task cannot be completed - verification failures:"
        for issue in "${ISSUES[@]}"; do
            echo "- $issue"
        done
        echo ""
        echo "Fix the issues above and try completing the task again."
    } >&2
    exit 2
fi

exit 0
