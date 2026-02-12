#!/bin/bash
# Hook Compliance Tests for feature-019
# Tests current hooks against Claude Code hooks reference
# Expected: ALL tests FAIL (RED phase - bugs exist in current code)

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

# Bug 1: TaskCompleted should NOT be async (async hooks cannot block with exit 2)
test_it "TaskCompleted is not async in hooks.json" \
  '! python3 -c "
import json
with open(\"$HOOKS_DIR/hooks.json\") as f:
    data = json.load(f)
tc = data[\"hooks\"][\"TaskCompleted\"][0]
assert tc[\"hooks\"][0].get(\"async\") == True
" 2>/dev/null'

# Bug 2: First SessionStart entry should have a matcher (prevent double-fire)
test_it "First SessionStart entry has a matcher" \
  'python3 -c "
import json
with open(\"$HOOKS_DIR/hooks.json\") as f:
    data = json.load(f)
entry = data[\"hooks\"][\"SessionStart\"][0]
assert \"matcher\" in entry, \"No matcher on first SessionStart\"
"'

# Bug 3: pre-compact.sh must include hookEventName in hookSpecificOutput
test_it "pre-compact.sh includes hookEventName in output" \
  'grep -q "hookEventName" "$HOOKS_DIR/pre-compact.sh"'

# Bug 4: session-end.sh must not use jq
test_it "session-end.sh does not use jq" \
  '! grep -q "\bjq\b" "$HOOKS_DIR/session-end.sh"'

# Bug 5: user-prompt-submit.sh must not output activeLoop field
test_it "user-prompt-submit.sh does not output activeLoop" \
  '! grep -q "activeLoop" "$HOOKS_DIR/user-prompt-submit.sh"'

# Bug 6: stop.sh must not output plain text (only JSON or empty)
test_it "stop.sh does not output plain text echo" \
  '! grep -E "^\s*echo\s+\"[^{]" "$HOOKS_DIR/stop.sh"'

# Bug 7: pre-compact.sh must not contain emoji
test_it "pre-compact.sh does not contain emoji" \
  '! grep -P "\xe2\x9a\xa0|\xf0\x9f" "$HOOKS_DIR/pre-compact.sh" && ! grep "⚠" "$HOOKS_DIR/pre-compact.sh"'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
