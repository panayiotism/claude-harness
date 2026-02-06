#!/bin/bash
# Stop Hook v4.5.1 - Check if feature completed, suggest checkpoint
# Runs when user stops/interrupts Claude Code
# Uses loop-state.json file check instead of prompt-based analysis

HARNESS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude-harness"
SESSIONS_DIR="$HARNESS_DIR/sessions"

# Check all session directories for completed loop states
for session_dir in "$SESSIONS_DIR"/*/; do
  [ -d "$session_dir" ] || continue

  loop_state="$session_dir/loop-state.json"
  [ -f "$loop_state" ] || continue

  # Check if status is "completed" (without jq)
  status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_state" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')
  feature=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_state" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

  if [ "$status" = "completed" ] && [ -n "$feature" ]; then
    echo "Feature $feature completed. Run /claude-harness:checkpoint or /claude-harness:flow $feature to finalize."
    exit 0
  fi
done

exit 0
