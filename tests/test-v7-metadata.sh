#!/bin/bash
# v7.0.0 Metadata & Changelog Tests for feature-023

HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

test_it() {
  local desc="$1"; shift
  if eval "$@" 2>/dev/null; then ((PASS++)); echo "  PASS: $desc"
  else ((FAIL++)); echo "  FAIL: $desc"; fi
}

echo "=== v7.0.0 Metadata & Changelog Tests ==="
echo ""

# Test 1: plugin.json version is 7.0.0
test_it "plugin.json version is 7.0.0" \
  'grep -q "\"version\": \"7.0.0\"" "$ROOT_DIR/.claude-plugin/plugin.json"'

# Test 2: All hook files have v7.0.0 in header (line 2)
OLD_HOOKS=0
for f in "$HOOKS_DIR"/*.sh; do
  header=$(sed -n '2p' "$f")
  if echo "$header" | grep -q 'v[0-9]' && ! echo "$header" | grep -q 'v7.0.0'; then
    OLD_HOOKS=$((OLD_HOOKS + 1))
  fi
done
test_it "All hook version headers are v7.0.0 (${OLD_HOOKS} outdated)" \
  '[ "$OLD_HOOKS" -eq 0 ]'

# Test 3: README.md has v7.0.0 changelog entry
test_it "README.md has v7.0.0 changelog entry" \
  'grep -q "7\.0\.0" "$ROOT_DIR/README.md" | head -1 && grep -q "7\.0\.0" "$ROOT_DIR/README.md"'

# Test 4: README.md v7.0.0 entry mentions key features
test_it "README.md v7.0.0 entry mentions hook compliance and performance" \
  'grep -A5 "7\.0\.0" "$ROOT_DIR/README.md" | grep -qi "hook\|performance\|compliance\|optimization"'

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
