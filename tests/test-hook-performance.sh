#!/bin/bash
# Hook Performance Tests for feature-022
# Expected: ALL tests FAIL (RED phase)

HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
PASS=0
FAIL=0

test_it() {
  local desc="$1"; shift
  if eval "$@" 2>/dev/null; then ((PASS++)); echo "  PASS: $desc"
  else ((FAIL++)); echo "  FAIL: $desc"; fi
}

echo "=== Hook Performance Tests ==="
echo ""

# Test 1: teammate-idle.sh should have parallel verification (& and wait)
test_it "teammate-idle.sh uses parallel verification" \
  'grep -q "wait" "$HOOKS_DIR/teammate-idle.sh" && grep -q "&$" "$HOOKS_DIR/teammate-idle.sh"'

# Test 2: task-completed.sh should NOT run test commands twice
# Count how many times timeout.*bash.*TEST_CMD appears (should be 1, currently 2)
TC_TEST_RUNS=$(grep -c 'timeout.*bash.*\$TEST_CMD\|timeout.*bash.*"$TEST_CMD"' "$HOOKS_DIR/task-completed.sh" || true)
test_it "task-completed.sh runs test command only once (currently ${TC_TEST_RUNS}x)" \
  '[ "$TC_TEST_RUNS" -le 1 ]'

# Test 3: teammate-idle.sh makes at most 1 python3 call
IDLE_PY_CALLS=$(grep -c 'python3' "$HOOKS_DIR/teammate-idle.sh" || true)
test_it "teammate-idle.sh makes at most 1 python3 call (currently ${IDLE_PY_CALLS})" \
  '[ "$IDLE_PY_CALLS" -le 1 ]'

# Test 4: task-completed.sh makes at most 1 python3 call for config parsing
TC_PY_CALLS=$(grep -c 'python3.*config.json\|python3.*CONFIG_FILE' "$HOOKS_DIR/task-completed.sh" || true)
test_it "task-completed.sh makes at most 1 python3 config call (currently ${TC_PY_CALLS})" \
  '[ "$TC_PY_CALLS" -le 1 ]'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
