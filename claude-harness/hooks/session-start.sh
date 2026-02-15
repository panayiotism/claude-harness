#!/bin/bash
# Claude Harness SessionStart Hook v8.0.0

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project - output nothing
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# --- Reusable box formatting ---
build_box() {
    # Usage: build_box "line1" "line2" ... (use "---" for separator)
    local TOP="┌─────────────────────────────────────────────────────────────────┐"
    local SEP="├─────────────────────────────────────────────────────────────────┤"
    local BOT="└─────────────────────────────────────────────────────────────────┘"
    local out="$TOP"
    for line in "$@"; do
        if [ "$line" = "---" ]; then
            out="$out
$SEP"
        else
            out="$out
│$(printf '%-63s' "  $line")│"
        fi
    done
    echo "$out
$BOT"
}

# --- GitHub repo caching ---
GITHUB_OWNER=""
GITHUB_REPO=""

REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [ -n "$REMOTE_URL" ]; then
    if [[ "$REMOTE_URL" =~ git@github\.com:([^/]+)/([^/.]+) ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"
        GITHUB_REPO="${BASH_REMATCH[2]}"
    elif [[ "$REMOTE_URL" =~ github\.com/([^/]+)/([^/.]+) ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"
        GITHUB_REPO="${BASH_REMATCH[2]}"
    fi
    GITHUB_REPO="${GITHUB_REPO%.git}"
fi

# --- Session management ---
SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "sess-$(date +%s%N | sha256sum | head -c 16)")
SESSION_DIR="$HARNESS_DIR/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR"

cat > "$SESSION_DIR/session.json" << SESSIONEOF
{
  "id": "$SESSION_ID",
  "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pid": "$$",
  "workingDir": "$CLAUDE_PROJECT_DIR"
}
SESSIONEOF

# --- Stale session cleanup ---
SESSIONS_DIR="$HARNESS_DIR/sessions"
RECOVERY_DIR="$SESSIONS_DIR/.recovery"
CLEANED_COUNT=0

if [ -d "$SESSIONS_DIR" ]; then
    for session_dir in "$SESSIONS_DIR"/*/; do
        [ -d "$session_dir" ] || continue
        session_id=$(basename "$session_dir")
        [ "$session_id" = "$SESSION_ID" ] && continue
        [ "$session_id" = ".recovery" ] && continue
        session_file="$session_dir/session.json"
        [ -f "$session_file" ] || continue
        pid=$(grep '"pid"' "$session_file" 2>/dev/null | grep -o '[0-9]\+')
        if [ -z "$pid" ] || ! ps -p "$pid" > /dev/null 2>&1; then
            loop_file="$session_dir/loop-state.json"
            if [ -f "$loop_file" ]; then
                loop_status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                if [ "$loop_status" = "in_progress" ]; then
                    loop_feature=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                    loop_attempt=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
                    tdd_phase=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$loop_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                    mkdir -p "$RECOVERY_DIR"
                    cat > "$RECOVERY_DIR/interrupted.json" << INTEOF
{
  "version": 1,
  "interruptedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "staleSessionId": "$session_id",
  "feature": "$loop_feature",
  "attemptAtInterrupt": ${loop_attempt:-1},
  "tddPhase": "${tdd_phase:-null}",
  "reason": "stale-session-detected"
}
INTEOF
                    cp "$loop_file" "$RECOVERY_DIR/loop-state.json" 2>/dev/null
                    [ -f "$session_dir/autonomous-state.json" ] && \
                        cp "$session_dir/autonomous-state.json" "$RECOVERY_DIR/autonomous-state.json" 2>/dev/null
                fi
            fi
            rm -rf "$session_dir"
            CLEANED_COUNT=$((CLEANED_COUNT + 1))
        fi
    done
fi

# --- Version & memory status ---
PLUGIN_VERSION=$(grep '"version"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')
PROJECT_VERSION=$(cat "$HARNESS_DIR/.plugin-version" 2>/dev/null)

VERSION_MSG=""
if [ -z "$PROJECT_VERSION" ]; then
    VERSION_MSG="Harness not initialized - run /claude-harness:setup"
elif [ "$PLUGIN_VERSION" != "$PROJECT_VERSION" ]; then
    VERSION_MSG="Plugin v$PLUGIN_VERSION (project at v$PROJECT_VERSION) - run /claude-harness:setup to migrate"
fi

EPISODIC_COUNT=0; FAILURES_COUNT=0; SUCCESSES_COUNT=0; RULES_COUNT=0
WORKING_COMPUTED=""
IS_V3=false

if [ -d "$HARNESS_DIR/memory" ]; then
    IS_V3=true
    [ -f "$HARNESS_DIR/memory/working/context.json" ] && \
        WORKING_COMPUTED=$(grep -o '"computedAt"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/memory/working/context.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    [ -f "$HARNESS_DIR/memory/episodic/decisions.json" ] && \
        EPISODIC_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/episodic/decisions.json" 2>/dev/null || echo "0")
    [ -f "$HARNESS_DIR/memory/procedural/failures.json" ] && \
        FAILURES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/procedural/failures.json" 2>/dev/null || echo "0")
    [ -f "$HARNESS_DIR/memory/procedural/successes.json" ] && \
        SUCCESSES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/procedural/successes.json" 2>/dev/null || echo "0")
    [ -f "$HARNESS_DIR/memory/learned/rules.json" ] && \
        RULES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/learned/rules.json" 2>/dev/null || echo "0")
fi

# Session-scoped paths
FEATURES_FILE="$HARNESS_DIR/features/active.json"
AGENT_FILE="$HARNESS_DIR/agents/context.json"
LOOP_FILE="$SESSION_DIR/loop-state.json"
WORKING_FILE="$SESSION_DIR/context.json"

# Feature state
ACTIVE_FEATURE=""
FEATURE_SUMMARY=""
if [ -f "$WORKING_FILE" ]; then
    ACTIVE_FEATURE=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' "$WORKING_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    FEATURE_SUMMARY=$(grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' "$WORKING_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

TOTAL_FEATURES=0; PENDING_FEATURES=0; IN_PROGRESS=0; NEEDS_TESTS=0
if [ -f "$FEATURES_FILE" ]; then
    TOTAL_FEATURES=$(grep -c '"id"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
    PENDING_FEATURES=$(grep -c '"status"[[:space:]]*:[[:space:]]*"pending"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
    IN_PROGRESS=$(grep -c '"status"[[:space:]]*:[[:space:]]*"in_progress"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
    NEEDS_TESTS=$(grep -c '"status"[[:space:]]*:[[:space:]]*"needs_tests"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
fi

# Orchestration state
ORCH_FEATURE=""
ORCH_PHASE=""
if [ -f "$AGENT_FILE" ]; then
    ORCH_FEATURE=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGENT_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    ORCH_PHASE=$(grep -o '"orchestrationPhase"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGENT_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Active loop state
LOOP_FEATURE=""
LOOP_STATUS=""
LOOP_ATTEMPT=""
LOOP_MAX=""
if [ -f "$LOOP_FILE" ]; then
    LOOP_STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    if [ "$LOOP_STATUS" = "in_progress" ]; then
        LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
        LOOP_ATTEMPT=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
        LOOP_MAX=$(grep -o '"maxAttempts"[[:space:]]*:[[:space:]]*[0-9]*' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    fi
fi

# Interrupt recovery
INT_FEATURE=""
INT_ATTEMPT=""
INT_PHASE=""
if [ -f "$RECOVERY_DIR/interrupted.json" ]; then
    INT_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$RECOVERY_DIR/interrupted.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    INT_ATTEMPT=$(grep -o '"attemptAtInterrupt"[[:space:]]*:[[:space:]]*[0-9]*' "$RECOVERY_DIR/interrupted.json" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    INT_PHASE=$(grep -o '"tddPhase"[[:space:]]*:[[:space:]]*"[^"]*"' "$RECOVERY_DIR/interrupted.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

LAST_SUMMARY=""
if [ -f "$HARNESS_DIR/claude-progress.json" ]; then
    LAST_SUMMARY=$(grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/claude-progress.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# --- Build user-visible message ---
LOOP_LINE=""
if [ -n "$INT_FEATURE" ]; then
    LOOP_LINE="INTERRUPTED: $INT_FEATURE (attempt $INT_ATTEMPT, phase: ${INT_PHASE:-unknown})"
    LOOP_FEATURE="$INT_FEATURE"
elif [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
    LOOP_LINE="ACTIVE LOOP: $LOOP_FEATURE (attempt $LOOP_ATTEMPT/$LOOP_MAX)"
fi

STATUS_LINE="P:$PENDING_FEATURES WIP:$IN_PROGRESS Tests:$NEEDS_TESTS"
[ -n "$ACTIVE_FEATURE" ] && [ "$ACTIVE_FEATURE" != "null" ] && STATUS_LINE="$STATUS_LINE | Active: $ACTIVE_FEATURE"
[ -n "$ORCH_FEATURE" ] && [ "$ORCH_FEATURE" != "null" ] && [ "$ORCH_PHASE" != "completed" ] && STATUS_LINE="$STATUS_LINE | Orch: $ORCH_PHASE"

MEMORY_LINE="Memory: $EPISODIC_COUNT decisions | $FAILURES_COUNT failures | $RULES_COUNT rules"

# Assemble box content lines
BOX_LINES=("CLAUDE HARNESS v$PLUGIN_VERSION")
if [ -n "$LOOP_LINE" ]; then
    FLOW_CMD="/claude-harness:flow"
    BOX_LINES+=("---" "$LOOP_LINE" "Resume: $FLOW_CMD $LOOP_FEATURE")
fi
BOX_LINES+=("---" "$STATUS_LINE")
[ "$IS_V3" = true ] && BOX_LINES+=("$MEMORY_LINE")
BOX_LINES+=("---" "/claude-harness:flow        Unified workflow (recommended)" "Flags: --no-merge --plan-only --autonomous --quick --fix")

USER_MSG=$(build_box "${BOX_LINES[@]}")

# Append notices
[ -n "$VERSION_MSG" ] && USER_MSG="$USER_MSG"$'\n'"     ⚠️  $VERSION_MSG"

# --- Build Claude context ---
CLAUDE_CONTEXT="=== CLAUDE HARNESS SESSION (v$PLUGIN_VERSION) ===\n"
CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nSession ID: $SESSION_ID"
CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nSession Dir: .claude-harness/sessions/$SESSION_ID/"
CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nPlugin Root: $CLAUDE_PLUGIN_ROOT"

# GitHub info
if [ -n "$GITHUB_OWNER" ] && [ -n "$GITHUB_REPO" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n=== GITHUB (CACHED) ==="
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nOwner: $GITHUB_OWNER"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nRepo: $GITHUB_REPO"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nIMPORTANT: Use these cached values for ALL GitHub API calls. Do NOT re-parse git remote."
fi

# Memory (single condensed block, v3 only)
if [ "$IS_V3" = true ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n=== MEMORY ARCHITECTURE v3.0 ==="
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nEpisodic Memory: $EPISODIC_COUNT decisions recorded"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nProcedural Memory: $FAILURES_COUNT failures, $SUCCESSES_COUNT successes"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nLearned Rules: $RULES_COUNT rules from user corrections"
    if [ -n "$WORKING_COMPUTED" ]; then
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nWorking Context: Last compiled $WORKING_COMPUTED"
    else
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nWorking Context: Not compiled - run /start"
    fi
fi

[ -n "$VERSION_MSG" ] && CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nVersion: $VERSION_MSG"

[ -n "$ACTIVE_FEATURE" ] && [ "$ACTIVE_FEATURE" != "null" ] && \
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nRESUMING WORK:\nFeature: $ACTIVE_FEATURE\nSummary: $FEATURE_SUMMARY"

[ "$TOTAL_FEATURES" != "0" ] && \
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nFeatures: P:$PENDING_FEATURES WIP:$IN_PROGRESS Tests:$NEEDS_TESTS / $TOTAL_FEATURES total"

# Interrupt recovery context
if [ -n "$INT_FEATURE" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** INTERRUPTED SESSION DETECTED ***"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nFeature: $INT_FEATURE was interrupted at attempt $INT_ATTEMPT"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nTDD Phase: ${INT_PHASE:-null}"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nRecovery file: .claude-harness/sessions/.recovery/interrupted.json"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nResume: /claude-harness:flow $INT_FEATURE"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nIMPORTANT: On resume, flow will offer recovery options. Do NOT retry same approach blindly."
fi

# Active loop context
if [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** ACTIVE AGENTIC LOOP ***\nFeature: $LOOP_FEATURE\nAttempt: $LOOP_ATTEMPT of $LOOP_MAX\nStatus: In Progress"
fi

if [ -n "$ORCH_FEATURE" ] && [ "$ORCH_FEATURE" != "null" ] && [ "$ORCH_PHASE" != "completed" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nACTIVE ORCHESTRATION:\nFeature: $ORCH_FEATURE\nPhase: $ORCH_PHASE"
fi

[ -n "$LAST_SUMMARY" ] && CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nLast session: $LAST_SUMMARY"

CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** PARALLEL SESSIONS ENABLED ***\nThis session has its own state directory. Multiple Claude instances can work on different features simultaneously without conflicts."

# --- Output JSON ---
USER_MSG_ESCAPED=$(echo "$USER_MSG" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
CLAUDE_CONTEXT_ESCAPED=$(echo -e "$CLAUDE_CONTEXT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

cat << EOF
{
  "continue": true,
  "systemMessage": "$USER_MSG_ESCAPED",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "sessionId": "$SESSION_ID",
    "sessionDir": "$SESSION_DIR",
    "github": {
      "owner": "$GITHUB_OWNER",
      "repo": "$GITHUB_REPO"
    },
    "additionalContext": "$CLAUDE_CONTEXT_ESCAPED"
  }
}
EOF
