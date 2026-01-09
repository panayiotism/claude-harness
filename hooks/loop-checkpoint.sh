#!/bin/bash
# Claude Harness Stop Hook v3.5
# Auto-saves working context and implements Ralph-style loop continuation
# Called on Stop event (agent completes or is interrupted)
#
# Ralph Mode: When autonomous=true in loop state, this hook blocks exit
# and re-feeds the implementation prompt until verification passes or
# max iterations reached.

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"
WORKING_CONTEXT="$HARNESS_DIR/memory/working/context.json"
LOOP_STATE="$HARNESS_DIR/loops/state.json"
EPISODIC_FILE="$HARNESS_DIR/memory/episodic/decisions.json"
PROGRESS_FILE="$HARNESS_DIR/loops/progress.txt"
GUARDRAILS_FILE="$HARNESS_DIR/loops/guardrails.md"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    echo '{"continue": true}'
    exit 0
fi

# Ensure directories exist
mkdir -p "$HARNESS_DIR/memory/working" 2>/dev/null
mkdir -p "$HARNESS_DIR/memory/episodic" 2>/dev/null
mkdir -p "$HARNESS_DIR/loops" 2>/dev/null

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# === Parse Loop State ===

LOOP_FEATURE=""
LOOP_STATUS=""
LOOP_AUTONOMOUS="false"
LOOP_ATTEMPT=0
LOOP_MAX_ATTEMPTS=10
FEATURE_NAME=""

if [ -f "$LOOP_STATE" ]; then
    LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_STATE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    LOOP_STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_STATE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    FEATURE_NAME=$(grep -o '"featureName"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_STATE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    # Check for autonomous mode
    if grep -q '"autonomous"[[:space:]]*:[[:space:]]*true' "$LOOP_STATE" 2>/dev/null; then
        LOOP_AUTONOMOUS="true"
    fi

    # Get attempt count
    LOOP_ATTEMPT=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$LOOP_STATE" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    LOOP_MAX_ATTEMPTS=$(grep -o '"maxAttempts"[[:space:]]*:[[:space:]]*[0-9]*' "$LOOP_STATE" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')

    # Default values
    [ -z "$LOOP_ATTEMPT" ] && LOOP_ATTEMPT=0
    [ -z "$LOOP_MAX_ATTEMPTS" ] && LOOP_MAX_ATTEMPTS=10
fi

# === Update Working Context ===

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

# Update timestamp in working context
if command -v jq &> /dev/null; then
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
    sed -i "s/\"computedAt\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"computedAt\": \"$TIMESTAMP\"/" "$WORKING_CONTEXT" 2>/dev/null
fi

# === Record Stop Event to Episodic Memory ===

if [ ! -f "$EPISODIC_FILE" ]; then
    echo '{"version": 1, "decisions": []}' > "$EPISODIC_FILE"
fi

STOP_REASON=""
if echo "$HOOK_INPUT" | grep -q '"reason"'; then
    STOP_REASON=$(echo "$HOOK_INPUT" | grep -o '"reason"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

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

# === Stage Changes for Git ===

STAGED_MSG=""
if git -C "$CLAUDE_PROJECT_DIR" status --porcelain 2>/dev/null | grep -q ".claude-harness"; then
    git -C "$CLAUDE_PROJECT_DIR" add "$HARNESS_DIR/memory/" 2>/dev/null
    git -C "$CLAUDE_PROJECT_DIR" add "$HARNESS_DIR/loops/state.json" 2>/dev/null
    STAGED_MSG="Harness state staged for commit"
fi

# === Ralph-Style Loop Continuation ===

# Check if we should block exit and continue the loop
if [ "$LOOP_AUTONOMOUS" = "true" ] && [ "$LOOP_STATUS" = "in_progress" ]; then

    # Check if we've exceeded max attempts
    if [ "$LOOP_ATTEMPT" -ge "$LOOP_MAX_ATTEMPTS" ]; then
        # Update status to escalated and allow exit
        if command -v jq &> /dev/null; then
            TEMP_FILE=$(mktemp)
            jq --arg ts "$TIMESTAMP" \
                '.status = "escalated" | .escalationRequested = true | .escalatedAt = $ts | .escalationReason = "Max attempts reached in autonomous mode"' \
                "$LOOP_STATE" > "$TEMP_FILE" 2>/dev/null
            if [ $? -eq 0 ]; then
                mv "$TEMP_FILE" "$LOOP_STATE"
            else
                rm -f "$TEMP_FILE"
            fi
        fi

        MSG="Autonomous loop reached max attempts ($LOOP_MAX_ATTEMPTS). Escalation required for $LOOP_FEATURE."
        MSG_ESCAPED=$(echo "$MSG" | sed 's/"/\\"/g')
        cat << EOF
{
  "continue": true,
  "systemMessage": "$MSG_ESCAPED"
}
EOF
        exit 0
    fi

    # === Circuit Breaker: Check for repeated identical errors ===

    # Read last 3 error signatures from progress.txt
    CIRCUIT_BREAK="false"
    if [ -f "$PROGRESS_FILE" ]; then
        # Get last 3 FAILED entries and extract error patterns
        LAST_ERRORS=$(grep "FAILED" "$PROGRESS_FILE" | tail -3 | grep -o 'Error: [^|]*' | sort | uniq -c | sort -rn | head -1)
        ERROR_COUNT=$(echo "$LAST_ERRORS" | awk '{print $1}')

        if [ "$ERROR_COUNT" -ge 3 ]; then
            CIRCUIT_BREAK="true"

            # Update guardrails.md with the pattern
            ERROR_PATTERN=$(echo "$LAST_ERRORS" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
            echo "" >> "$GUARDRAILS_FILE"
            echo "## Circuit Breaker Triggered - $(date -u +"%Y-%m-%d %H:%M")" >> "$GUARDRAILS_FILE"
            echo "DO NOT repeat this approach - it has failed 3+ consecutive times:" >> "$GUARDRAILS_FILE"
            echo "\`\`\`" >> "$GUARDRAILS_FILE"
            echo "$ERROR_PATTERN" >> "$GUARDRAILS_FILE"
            echo "\`\`\`" >> "$GUARDRAILS_FILE"

            # Update status to escalated
            if command -v jq &> /dev/null; then
                TEMP_FILE=$(mktemp)
                jq --arg ts "$TIMESTAMP" --arg err "$ERROR_PATTERN" \
                    '.status = "escalated" | .escalationRequested = true | .escalatedAt = $ts | .escalationReason = ("Circuit breaker: " + $err)' \
                    "$LOOP_STATE" > "$TEMP_FILE" 2>/dev/null
                if [ $? -eq 0 ]; then
                    mv "$TEMP_FILE" "$LOOP_STATE"
                else
                    rm -f "$TEMP_FILE"
                fi
            fi

            MSG="Circuit breaker triggered: 3 consecutive identical errors. Review guardrails.md and try a different approach."
            MSG_ESCAPED=$(echo "$MSG" | sed 's/"/\\"/g')
            cat << EOF
{
  "continue": true,
  "systemMessage": "$MSG_ESCAPED"
}
EOF
            exit 0
        fi
    fi

    # === Continue Loop: Block exit and re-feed prompt ===

    # Build the continuation prompt
    NEXT_ATTEMPT=$((LOOP_ATTEMPT + 1))

    # Read guardrails if they exist
    GUARDRAILS_CONTENT=""
    if [ -f "$GUARDRAILS_FILE" ] && [ -s "$GUARDRAILS_FILE" ]; then
        GUARDRAILS_CONTENT="

GUARDRAILS (approaches to avoid):
$(cat "$GUARDRAILS_FILE")
"
    fi

    # Read recent progress
    PROGRESS_CONTENT=""
    if [ -f "$PROGRESS_FILE" ] && [ -s "$PROGRESS_FILE" ]; then
        PROGRESS_CONTENT="

RECENT PROGRESS (last 5 attempts):
$(tail -5 "$PROGRESS_FILE")
"
    fi

    # Escape for JSON
    GUARDRAILS_ESCAPED=$(echo "$GUARDRAILS_CONTENT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    PROGRESS_ESCAPED=$(echo "$PROGRESS_CONTENT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    # Build the continuation message
    CONTINUATION_PROMPT="RALPH LOOP CONTINUATION - Attempt $NEXT_ATTEMPT/$LOOP_MAX_ATTEMPTS

Feature: $LOOP_FEATURE - $FEATURE_NAME

Continue implementing this feature. Previous attempt did not pass verification.
Read the progress log and guardrails below, then try a different approach.
$GUARDRAILS_ESCAPED
$PROGRESS_ESCAPED

INSTRUCTIONS:
1. Review what failed in the previous attempt
2. Plan a different approach that avoids the guardrails
3. Implement the changes
4. Run verification commands
5. If verification passes, the loop will complete
6. If verification fails, log the attempt and the loop will continue

Run /claude-harness:implement $LOOP_FEATURE to continue the implementation."

    PROMPT_ESCAPED=$(echo "$CONTINUATION_PROMPT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

    # Output decision: block with continuation prompt
    cat << EOF
{
  "decision": "block",
  "systemMessage": "$PROMPT_ESCAPED"
}
EOF
    exit 0
fi

# === Standard Exit (non-autonomous or completed) ===

if [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
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
