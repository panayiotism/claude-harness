#!/bin/bash
# Claude Harness PostToolUseFailure Hook v6.4.0
# Real-time failure learning — records test/build/lint failures
# Matcher: "Bash"
# Appends to memory/episodic/failures.json for future reference

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Read stdin JSON
INPUT=$(cat)

# Skip if this was a user interrupt
IS_INTERRUPT=$(echo "$INPUT" | grep -o '"is_interrupt"[[:space:]]*:[[:space:]]*true' | head -1)
if [ -n "$IS_INTERRUPT" ]; then
    exit 0
fi

# Extract error and command
ERROR_MSG=$(echo "$INPUT" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

if [ -z "$ERROR_MSG" ] && [ -z "$COMMAND" ]; then
    exit 0
fi

# Only record failures from verification-related commands
IS_VERIFY=false
if echo "$COMMAND" | grep -qiE '(test|jest|pytest|mocha|vitest|cargo test|go test|npm run test)'; then
    IS_VERIFY=true
fi
if echo "$COMMAND" | grep -qiE '(build|compile|tsc|webpack|vite build|cargo build|go build|npm run build)'; then
    IS_VERIFY=true
fi
if echo "$COMMAND" | grep -qiE '(lint|eslint|pylint|flake8|clippy|golangci|npm run lint)'; then
    IS_VERIFY=true
fi
if echo "$COMMAND" | grep -qiE '(typecheck|tsc --noEmit|mypy|pyright)'; then
    IS_VERIFY=true
fi

if [ "$IS_VERIFY" = false ]; then
    exit 0
fi

# Record failure to failures.json
FAILURES_FILE="$HARNESS_DIR/memory/episodic/failures.json"
mkdir -p "$(dirname "$FAILURES_FILE")"

# Use python3 for safe JSON manipulation
python3 -c "
import json, os, sys
from datetime import datetime, timezone

failures_path = '$FAILURES_FILE'
command = '''$COMMAND'''[:200]
error = '''$ERROR_MSG'''[:500]

# Load or create
if os.path.exists(failures_path):
    try:
        with open(failures_path) as f:
            data = json.load(f)
    except:
        data = {'entries': []}
else:
    data = {'entries': []}

# Append new entry
entry = {
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'command': command,
    'error': error,
    'summary': f'Failed: {command[:80]}'
}
data['entries'].append(entry)

# Cap at 20 entries (FIFO)
if len(data['entries']) > 20:
    data['entries'] = data['entries'][-20:]

with open(failures_path, 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null

# Output brief failure note as context
SUMMARY=$(echo "$COMMAND" | head -c 80)
CONTEXT="[FAILURE RECORDED] $SUMMARY — see memory/episodic/failures.json"
CONTEXT_ESCAPED=$(echo "$CONTEXT" | sed 's/"/\\"/g')

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUseFailure",
    "additionalContext": "$CONTEXT_ESCAPED"
  }
}
EOF

exit 0
