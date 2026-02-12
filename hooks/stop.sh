#!/bin/bash
# Stop Hook v6.3.0 - Detect completion, mark active sessions on natural stop
# Runs when Claude finishes responding (NOT on user interrupt - Ctrl+C/Escape)
# Within 5-second timeout (hooks.json)

HARNESS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude-harness"
SESSIONS_DIR="$HARNESS_DIR/sessions"
RECOVERY_DIR="$SESSIONS_DIR/.recovery"

# Check all session directories for loop states
for session_dir in "$SESSIONS_DIR"/*/; do
  [ -d "$session_dir" ] || continue
  [ "$(basename "$session_dir")" = ".recovery" ] && continue

  loop_state="$session_dir/loop-state.json"
  [ -f "$loop_state" ] || continue

  # Read status and feature (without jq)
  status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_state" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
  feature=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_state" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

  if [ "$status" = "completed" ] && [ -n "$feature" ]; then
    # Feature completed - no plain text output
    # Clean up stale recovery markers for this feature
    if [ -f "$RECOVERY_DIR/interrupted.json" ]; then
      rec_feature=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$RECOVERY_DIR/interrupted.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
      if [ "$rec_feature" = "$feature" ]; then
        rm -f "$RECOVERY_DIR/interrupted.json" "$RECOVERY_DIR/loop-state.json" "$RECOVERY_DIR/autonomous-state.json"
        rmdir "$RECOVERY_DIR" 2>/dev/null
      fi
    fi
    exit 0
  fi

  # For in_progress states on natural stop: Claude finished responding but
  # the feature isn't done. This is NOT a user interrupt (those don't trigger
  # Stop), but could be output limit, premature stop, etc.
  if [ "$status" = "in_progress" ] && [ -n "$feature" ]; then
    attempt=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$loop_state" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    tdd_phase=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_state" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    team_name=$(grep -o '"teamName"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_state" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    mkdir -p "$RECOVERY_DIR"
    cat > "$RECOVERY_DIR/interrupted.json" << INTEOF
{
  "version": 1,
  "interruptedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "staleSessionId": "$(basename "$session_dir")",
  "feature": "$feature",
  "attemptAtInterrupt": ${attempt:-1},
  "tddPhase": "${tdd_phase:-null}",
  "staleTeamName": "${team_name:-null}",
  "reason": "natural-stop-while-in-progress"
}
INTEOF
    # Feature in progress - no plain text output
    exit 0
  fi
done

exit 0
