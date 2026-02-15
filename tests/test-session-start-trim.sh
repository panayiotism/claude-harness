#!/bin/bash
# Session-start.sh Trim Tests for feature-021
# Expected: ALL tests FAIL (RED phase)

HOOKS_DIR="$(cd "$(dirname "$0")/../claude-harness/hooks" && pwd)"
FILE="$HOOKS_DIR/session-start.sh"
PASS=0
FAIL=0

test_it() {
  local desc="$1"; shift
  if eval "$@" 2>/dev/null; then ((PASS++)); echo "  PASS: $desc"
  else ((FAIL++)); echo "  FAIL: $desc"; fi
}

echo "=== Session-start.sh Trim Tests ==="
echo ""

LINE_COUNT=$(wc -l < "$FILE")

# Test 1: Under 400 lines (currently 633)
test_it "session-start.sh under 400 lines (currently $LINE_COUNT)" \
  '[ "$LINE_COUNT" -lt 400 ]'

# Test 2: No "Opus 4.6" capabilities text (redundant - Claude knows itself)
test_it "No Opus 4.6 capabilities section" \
  '! grep -qi "OPUS 4.6 CAPABILITIES\|128K output\|Effort controls\|Adaptive thinking" "$FILE"'

# Test 3: Has a reusable box function (build_box or similar)
test_it "Has reusable box formatting function" \
  'grep -q "build_box\|format_box\|draw_box" "$FILE"'

# Test 4: Workflow listing not duplicated in context
WORKFLOW_MENTIONS=$(grep -c "claude-harness:flow\|claude-harness:start\|claude-harness:setup" "$FILE" || true)
test_it "Workflow commands mentioned at most 5 times (currently $WORKFLOW_MENTIONS)" \
  '[ "$WORKFLOW_MENTIONS" -le 5 ]'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
