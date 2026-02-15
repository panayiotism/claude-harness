#!/bin/bash
# Hook Compliance Tests
# Tests current hooks against Claude Code hooks reference

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../claude-harness/hooks"
PASS=0
FAIL=0

test_it() {
  local desc="$1"
  shift
  if eval "$@" 2>/dev/null; then
    ((PASS++))
    echo "  PASS: $desc"
  else
    ((FAIL++))
    echo "  FAIL: $desc"
  fi
}

echo "=== Hook Compliance Tests ==="
echo ""

# Test 1: hooks.json has exactly 6 hook registrations (5 event types, PreToolUse has 2)
test_it "hooks.json has 5 event types" \
  'python3 -c "
import json
with open(\"$HOOKS_DIR/hooks.json\") as f:
    data = json.load(f)
assert len(data[\"hooks\"]) == 5, f\"Expected 5 event types, got {len(data['hooks'])}\"
"'

# Test 2: pre-compact.sh includes hookEventName in output
test_it "pre-compact.sh includes hookEventName in output" \
  'grep -q "hookEventName" "$HOOKS_DIR/pre-compact.sh"'

# Test 3: stop.sh must not output plain text (only JSON or empty)
test_it "stop.sh does not output plain text echo" \
  '! grep -E "^\s*echo\s+\"[^{]" "$HOOKS_DIR/stop.sh"'

# Test 4: pre-compact.sh must not contain emoji
test_it "pre-compact.sh does not contain emoji" \
  '! grep -P "\xe2\x9a\xa0|\xf0\x9f" "$HOOKS_DIR/pre-compact.sh" && ! grep "⚠" "$HOOKS_DIR/pre-compact.sh"'

# Test 5: No team-specific hooks remain
test_it "No SubagentStart hook in hooks.json" \
  '! grep -q "SubagentStart" "$HOOKS_DIR/hooks.json"'

test_it "No TeammateIdle hook in hooks.json" \
  '! grep -q "TeammateIdle" "$HOOKS_DIR/hooks.json"'

test_it "No TaskCompleted hook in hooks.json" \
  '! grep -q "TaskCompleted" "$HOOKS_DIR/hooks.json"'

# Test 6: Team hook scripts are deleted
test_it "subagent-start.sh does not exist" \
  '[ ! -f "$HOOKS_DIR/subagent-start.sh" ]'

test_it "teammate-idle.sh does not exist" \
  '[ ! -f "$HOOKS_DIR/teammate-idle.sh" ]'

test_it "task-completed.sh does not exist" \
  '[ ! -f "$HOOKS_DIR/task-completed.sh" ]'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
