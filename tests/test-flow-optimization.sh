#!/bin/bash
# Flow.md Optimization Tests for feature-020
# Expected: ALL tests FAIL (RED phase - flow.md not yet optimized)

FLOW_FILE="$(cd "$(dirname "$0")/.." && pwd)/commands/flow.md"
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

echo "=== Flow.md Optimization Tests ==="
echo ""

LINE_COUNT=$(wc -l < "$FLOW_FILE")

# Test 1: flow.md should be under 900 lines (currently 1434)
test_it "flow.md is under 900 lines (currently $LINE_COUNT)" \
  '[ "$LINE_COUNT" -lt 900 ]'

# Test 2: Effort table should appear only ONCE (currently 3x)
EFFORT_TABLES=$(grep -c "| Phase | Effort |" "$FLOW_FILE")
test_it "Effort table appears only once (currently ${EFFORT_TABLES}x)" \
  '[ "$EFFORT_TABLES" -le 1 ]'

# Test 3: Delegation assertion should appear at most twice (currently 6x)
DELEG_CHECKS=$(grep -c "DELEGATION" "$FLOW_FILE" || true)
test_it "Delegation check appears at most 2x (currently ${DELEG_CHECKS}x)" \
  '[ "$DELEG_CHECKS" -le 2 ]'

# Test 4: --quick should document direct implementation (no team)
test_it "--quick documents direct implementation without team" \
  'grep -q "quick.*without.*team\|quick.*no team\|quick.*skip.*team\|quick.*directly" "$FLOW_FILE"'

# Test 5: ASCII boxes should be under 20 (currently 37)
BOX_COUNT=$(grep -c "┌─" "$FLOW_FILE" || true)
test_it "ASCII boxes under 20 (currently ${BOX_COUNT})" \
  '[ "$BOX_COUNT" -lt 20 ]'

# Test 6: loop-state schema should appear only once (currently 2x)
LOOP_SCHEMAS=$(grep -c '"version": 7' "$FLOW_FILE" || true)
test_it "loop-state schema appears only once (currently ${LOOP_SCHEMAS}x)" \
  '[ "$LOOP_SCHEMAS" -le 1 ]'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
