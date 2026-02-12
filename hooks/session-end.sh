#!/bin/bash
# Session End Hook - Clean up inactive session directories
# Runs automatically when a Claude Code session ends
# Only removes sessions where the PID is no longer running (inactive)

HARNESS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude-harness"
SESSIONS_DIR="$HARNESS_DIR/sessions"

# Exit if no sessions directory
[ -d "$SESSIONS_DIR" ] || exit 0

# Get current session ID from stdin (JSON input from SessionEnd hook)
INPUT=$(cat)
CURRENT_SESSION=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

# Iterate through all session directories
for session_dir in "$SESSIONS_DIR"/*/; do
  [ -d "$session_dir" ] || continue

  session_id=$(basename "$session_dir")
  session_file="$session_dir/session.json"

  # Skip current session (the one that's ending)
  [ "$session_id" = "$CURRENT_SESSION" ] && continue

  # Skip if no session.json (malformed session)
  [ -f "$session_file" ] || continue

  # Get PID from session.json
  pid=$(grep -o '"pid"[[:space:]]*:[[:space:]]*"[^"]*"' "$session_file" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

  # If no PID or PID is not running, session is inactive - delete it
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    rm -rf "$session_dir"
  fi
done

exit 0
