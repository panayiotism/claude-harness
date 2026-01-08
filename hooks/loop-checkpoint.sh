#!/bin/bash
# Claude Harness Stop Hook v3.4
# Auto-saves working context when agent loop ends
# Called on Stop event (agent completes or is interrupted)

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"
WORKING_CONTEXT="$HARNESS_DIR/memory/working/context.json"
LOOP_STATE="$HARNESS_DIR/loops/state.json"
EPISODIC_FILE="$HARNESS_DIR/memory/episodic/decisions.json"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    echo '{"continue": true}'
    exit 0
fi

# Ensure memory directories exist
mkdir -p "$HARNESS_DIR/memory/working" 2>/dev/null
mkdir -p "$HARNESS_DIR/memory/episodic" 2>/dev/null

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Get active loop info
LOOP_FEATURE=""
LOOP_STATUS=""
if [ -f "$LOOP_STATE" ]; then
    LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_STATE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    LOOP_STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_STATE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# === Update Working Context ===

# Initialize working context if it doesn't exist
if [ ! -f "$WORKING_CONTEXT" ]; then
    cat > "$WORKING_CONTEXT" << EOF
{
  "version": 3,
  "computedAt": "$TIMESTAMP",
  "sessionId": "session-$(date +%Y%m%d-%H%M%S)",
  "activeFeature": null,
  "relevantMemory": {
    "recentDecisions": [],
    "projectPatterns": [],
    "avoidApproaches": [],
    "learnedRules": []
  },
  "currentTask": {
    "description": null,
    "files": [],
    "acceptanceCriteria": []
  },
  "compilationLog": ["Created by loop-checkpoint.sh"]
}
EOF
fi

# Update the computedAt timestamp in working context
if command -v jq &> /dev/null; then
    # Use jq if available
    TEMP_FILE=$(mktemp)
    jq --arg ts "$TIMESTAMP" --arg feat "$LOOP_FEATURE" \
        '.computedAt = $ts | .activeFeature = $feat | .lastStopEvent = $ts' \
        "$WORKING_CONTEXT" > "$TEMP_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$WORKING_CONTEXT"
    else
        rm -f "$TEMP_FILE"
    fi
else
    # Fallback: update timestamp with sed
    sed -i "s/\"computedAt\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"computedAt\": \"$TIMESTAMP\"/" "$WORKING_CONTEXT" 2>/dev/null
fi

# === Record Stop Event to Episodic Memory ===

# Initialize episodic decisions if it doesn't exist
if [ ! -f "$EPISODIC_FILE" ]; then
    echo '{"version": 1, "decisions": []}' > "$EPISODIC_FILE"
fi

# Create stop event entry
STOP_REASON=""
# Try to extract stop reason from hook input
if echo "$HOOK_INPUT" | grep -q '"reason"'; then
    STOP_REASON=$(echo "$HOOK_INPUT" | grep -o '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Record to episodic memory
if command -v jq &> /dev/null; then
    TEMP_FILE=$(mktemp)
    jq --arg ts "$TIMESTAMP" --arg feat "$LOOP_FEATURE" --arg status "$LOOP_STATUS" --arg reason "$STOP_REASON" \
        '.decisions += [{"id": "stop-\($ts)", "timestamp": $ts, "type": "stop_event", "feature": $feat, "status": $status, "reason": $reason}]' \
        "$EPISODIC_FILE" > "$TEMP_FILE" 2>/dev/null
    if [ $? -eq 0 ]; then
        mv "$TEMP_FILE" "$EPISODIC_FILE"
    else
        rm -f "$TEMP_FILE"
    fi
fi

# === Stage Changes for Git (optional) ===

# Check if there are uncommitted changes in harness files
if git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | grep -q ".claude-harness"; then
    # Stage harness memory files for next commit
    git -C "$CLAUDE_PROJECT_DIR" add "$HARNESS_DIR/memory/" 2>/dev/null
    git -C "$CLAUDE_PROJECT_DIR" add "$HARNESS_DIR/loops/state.json" 2>/dev/null

    # Build status message
    STAGED_MSG="Harness state staged for commit"
else
    STAGED_MSG=""
fi

# === Output Result ===

if [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
    # Active loop - provide resume hint
    MSG="Loop checkpoint saved for $LOOP_FEATURE. Resume with /claude-harness:implement $LOOP_FEATURE"
    if [ -n "$STAGED_MSG" ]; then
        MSG="$MSG. $STAGED_MSG"
    fi
    MSG_ESCAPED=$(echo "$MSG" | sed 's/"/\\"/g')

    cat << EOF
{
  "continue": true,
  "systemMessage": "$MSG_ESCAPED"
}
EOF
else
    # No active loop
    if [ -n "$STAGED_MSG" ]; then
        STAGED_ESCAPED=$(echo "$STAGED_MSG" | sed 's/"/\\"/g')
        cat << EOF
{
  "continue": true,
  "systemMessage": "$STAGED_ESCAPED"
}
EOF
    else
        echo '{"continue": true}'
    fi
fi
