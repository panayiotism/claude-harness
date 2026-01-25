#!/bin/bash
# Session End Hook v4.4.1 - Clean up inactive session directories
# Runs automatically when a Claude Code session ends
# Only removes sessions where the PID is no longer running (inactive)
#
# NOTE: This hook may not trigger reliably on /clear or crashes.
# The primary cleanup now happens in session-start.sh (proactive cleanup).
# This hook serves as a secondary cleanup mechanism.

HARNESS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude-harness"
SESSIONS_DIR="$HARNESS_DIR/sessions"

# Exit if no sessions directory
[ -d "$SESSIONS_DIR" ] || exit 0

# Get current session ID from stdin (JSON input from SessionEnd hook)
# Use grep/sed instead of jq for portability
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

  # Get PID from session.json (works without jq)
  pid=$(grep '"pid"' "$session_file" 2>/dev/null | grep -o '[0-9]\+')

  # If no PID or process doesn't exist, session is inactive - delete it
  # Use ps -p instead of kill -0 (more reliable on WSL)
  if [ -z "$pid" ] || ! ps -p "$pid" > /dev/null 2>&1; then
    rm -rf "$session_dir"
  fi
done

exit 0
