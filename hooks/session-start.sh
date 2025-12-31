#!/bin/bash
# Claude Harness SessionStart Hook
# Outputs JSON with systemMessage (user-visible) and additionalContext (Claude-visible)

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project - output nothing
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Get plugin version
PLUGIN_VERSION=$(grep '"version"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

# Get project's last-run version
PROJECT_VERSION=$(cat "$HARNESS_DIR/.plugin-version" 2>/dev/null)

# Build status components
VERSION_MSG=""
if [ -z "$PROJECT_VERSION" ]; then
    echo "$PLUGIN_VERSION" > "$HARNESS_DIR/.plugin-version"
    VERSION_MSG="Harness initialized (v$PLUGIN_VERSION)"
elif [ "$PLUGIN_VERSION" != "$PROJECT_VERSION" ]; then
    echo "$PLUGIN_VERSION" > "$HARNESS_DIR/.plugin-version"
    VERSION_MSG="Plugin updated: v$PROJECT_VERSION -> v$PLUGIN_VERSION"
fi

# Get active feature from working-context
ACTIVE_FEATURE=""
FEATURE_SUMMARY=""
if [ -f "$HARNESS_DIR/working-context.json" ]; then
    ACTIVE_FEATURE=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/working-context.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    FEATURE_SUMMARY=$(grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/working-context.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Get feature counts
TOTAL_FEATURES=0
PENDING_FEATURES=0
if [ -f "$HARNESS_DIR/feature-list.json" ]; then
    TOTAL_FEATURES=$(grep -c '"id"' "$HARNESS_DIR/feature-list.json" 2>/dev/null | head -1 || echo "0")
    PENDING_FEATURES=$(grep -c '"passes"[[:space:]]*:[[:space:]]*false' "$HARNESS_DIR/feature-list.json" 2>/dev/null | head -1 || echo "0")
fi

# Get orchestration state
ORCH_FEATURE=""
ORCH_PHASE=""
if [ -f "$HARNESS_DIR/agent-context.json" ]; then
    ORCH_FEATURE=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/agent-context.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    ORCH_PHASE=$(grep -o '"orchestrationPhase"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/agent-context.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Get last session summary
LAST_SUMMARY=""
if [ -f "$HARNESS_DIR/claude-progress.json" ]; then
    LAST_SUMMARY=$(grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/claude-progress.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Build user-visible message (systemMessage) - enhanced box format
# Build status line
STATUS_LINE=""
if [ "$PENDING_FEATURES" != "0" ]; then
    STATUS_LINE="$PENDING_FEATURES pending"
else
    STATUS_LINE="No pending features"
fi

if [ -n "$ACTIVE_FEATURE" ] && [ "$ACTIVE_FEATURE" != "null" ]; then
    STATUS_LINE="$STATUS_LINE | Resuming: $ACTIVE_FEATURE"
fi

if [ -n "$ORCH_FEATURE" ] && [ "$ORCH_FEATURE" != "null" ] && [ "$ORCH_PHASE" != "completed" ]; then
    STATUS_LINE="$STATUS_LINE | Orchestration: $ORCH_PHASE"
fi

# Build the box output (65 chars wide inner content)
# Pad status line to fixed width
STATUS_PADDED=$(printf "%-61s" "$STATUS_LINE")

USER_MSG="
┌─────────────────────────────────────────────────────────────────┐
│                     CLAUDE HARNESS v$PLUGIN_VERSION                       │
├─────────────────────────────────────────────────────────────────┤
│  $STATUS_PADDED│
├─────────────────────────────────────────────────────────────────┤
│  Commands:                                                      │
│  /claude-harness:start       Full status + GitHub sync          │
│  /claude-harness:feature     Add new feature + GitHub issue     │
│  /claude-harness:orchestrate Spawn multi-agent team             │
│  /claude-harness:checkpoint  Commit, push, create/update PR     │
│  /claude-harness:merge-all   Merge PRs + create release         │
└─────────────────────────────────────────────────────────────────┘"

# Add version update notice if applicable
if [ -n "$VERSION_MSG" ]; then
    USER_MSG="$USER_MSG
⚠️  $VERSION_MSG - run /claude-harness:setup to update project files"
fi

# Build Claude context (additionalContext)
CLAUDE_CONTEXT="=== CLAUDE HARNESS SESSION ===\n"

if [ -n "$VERSION_MSG" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nVersion: $VERSION_MSG"
fi

if [ -n "$ACTIVE_FEATURE" ] && [ "$ACTIVE_FEATURE" != "null" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nRESUMING WORK:\nFeature: $ACTIVE_FEATURE\nSummary: $FEATURE_SUMMARY"
fi

if [ "$TOTAL_FEATURES" != "0" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nFeatures: $PENDING_FEATURES pending / $TOTAL_FEATURES total"
fi

if [ -n "$ORCH_FEATURE" ] && [ "$ORCH_FEATURE" != "null" ] && [ "$ORCH_PHASE" != "completed" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nACTIVE ORCHESTRATION:\nFeature: $ORCH_FEATURE\nPhase: $ORCH_PHASE\nResume with: /claude-harness:orchestrate $ORCH_FEATURE"
fi

if [ -n "$LAST_SUMMARY" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nLast session: $LAST_SUMMARY"
fi

CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nACTION: Run /claude-harness:start for full session status with GitHub sync."

# Escape for JSON (handle multi-line output)
USER_MSG_ESCAPED=$(echo "$USER_MSG" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
CLAUDE_CONTEXT_ESCAPED=$(echo -e "$CLAUDE_CONTEXT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Output JSON with both systemMessage (user) and additionalContext (Claude)
cat << EOF
{
  "continue": true,
  "systemMessage": "$USER_MSG_ESCAPED",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "$CLAUDE_CONTEXT_ESCAPED"
  }
}
EOF
