#!/bin/bash
# Hook Compliance Tests
# Tests current hooks against Claude Code hooks reference

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
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

# Test 1: hooks.json has 8 event types (SessionStart, PreCompact, Stop, PreToolUse, PermissionRequest, SubagentStart, TeammateIdle, TaskCompleted)
test_it "hooks.json has 8 event types" \
  'python3 -c "
import json
with open(\"$HOOKS_DIR/hooks.json\") as f:
    data = json.load(f)
assert len(data[\"hooks\"]) == 8, f\"Expected 8 event types, got {len(data['hooks'])}\"
"'

# Test 2: pre-compact includes hookEventName in output
test_it "pre-compact includes hookEventName in output" \
  'grep -q "hookEventName" "$HOOKS_DIR/pre-compact"'

# Test 3: stop must not output plain text (only JSON or empty)
test_it "stop does not output plain text echo" \
  '! grep -E "^\s*echo\s+\"[^{]" "$HOOKS_DIR/stop"'

# Test 4: pre-compact must not contain emoji
test_it "pre-compact does not contain emoji" \
  '! grep -P "\xe2\x9a\xa0|\xf0\x9f" "$HOOKS_DIR/pre-compact" && ! grep "⚠" "$HOOKS_DIR/pre-compact"'

# Test 5: Team hooks are registered (re-added in v9.0.0)
test_it "SubagentStart hook in hooks.json" \
  'grep -q "SubagentStart" "$HOOKS_DIR/hooks.json"'

test_it "TeammateIdle hook in hooks.json" \
  'grep -q "TeammateIdle" "$HOOKS_DIR/hooks.json"'

test_it "TaskCompleted hook in hooks.json" \
  'grep -q "TaskCompleted" "$HOOKS_DIR/hooks.json"'

# Test 6: Hooks use run-hook.cmd wrapper (v10.0.0 cross-platform)
test_it "All hooks use run-hook.cmd wrapper" \
  'python3 -c "
import json
with open(\"$HOOKS_DIR/hooks.json\") as f:
    data = json.load(f)
for event, entries in data[\"hooks\"].items():
    for entry in entries:
        for hook in entry[\"hooks\"]:
            cmd = hook[\"command\"]
            assert \"run-hook.cmd\" in cmd, f\"{event} does not use run-hook.cmd: {cmd}\"
"'

# Test 7: Legacy .sh hook scripts are removed
test_it "session-start.sh does not exist" \
  '[ ! -f "$HOOKS_DIR/session-start.sh" ]'

test_it "pre-compact.sh does not exist" \
  '[ ! -f "$HOOKS_DIR/pre-compact.sh" ]'

test_it "stop.sh does not exist" \
  '[ ! -f "$HOOKS_DIR/stop.sh" ]'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
