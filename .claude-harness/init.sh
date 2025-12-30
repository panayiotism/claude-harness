#!/bin/bash
echo "=== Claude Harness Dev Environment ==="
echo "Working directory: $(pwd)"
echo ""
echo "=== Recent Git History ==="
git log --oneline -5 2>/dev/null || echo "Not a git repository"
echo ""
echo "=== Progress ==="
if [ -f .claude-harness/claude-progress.json ]; then
  cat .claude-harness/claude-progress.json | head -20
else
  echo "No .claude-harness/claude-progress.json found"
fi
echo ""
echo "=== Pending Features ==="
if [ -f .claude-harness/feature-list.json ]; then
  cat .claude-harness/feature-list.json
else
  echo "No .claude-harness/feature-list.json found"
fi
