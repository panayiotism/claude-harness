#!/bin/bash
# Claude Harness SessionStart Hook v3.8.0
# Outputs JSON with systemMessage (user-visible) and additionalContext (Claude-visible)
# Enhanced with session-scoped state for parallel work streams

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project - output nothing
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# ============================================================================
# SESSION MANAGEMENT (v3.8.0 - Parallel Work Streams)
# ============================================================================

# Generate unique session ID (UUID or fallback)
SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "sess-$(date +%s%N | sha256sum | head -c 16)")
SESSION_DIR="$HARNESS_DIR/sessions/$SESSION_ID"

# Create session directory
mkdir -p "$SESSION_DIR"

# Write session info file
cat > "$SESSION_DIR/session.json" << SESSIONEOF
{
  "id": "$SESSION_ID",
  "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "pid": "$$",
  "workingDir": "$CLAUDE_PROJECT_DIR"
}
SESSIONEOF

# Get plugin version
PLUGIN_VERSION=$(grep '"version"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')

# Get project's last-run version
PROJECT_VERSION=$(cat "$HARNESS_DIR/.plugin-version" 2>/dev/null)

# Build status components
VERSION_MSG=""
NEEDS_MIGRATION=false
if [ -z "$PROJECT_VERSION" ]; then
    echo "$PLUGIN_VERSION" > "$HARNESS_DIR/.plugin-version"
    VERSION_MSG="Harness initialized (v$PLUGIN_VERSION)"
elif [ "$PLUGIN_VERSION" != "$PROJECT_VERSION" ]; then
    echo "$PLUGIN_VERSION" > "$HARNESS_DIR/.plugin-version"
    VERSION_MSG="Plugin updated: v$PROJECT_VERSION -> v$PLUGIN_VERSION"
    # Check if migration to v3.0 is needed
    if [ ! -d "$HARNESS_DIR/memory" ] && [ -f "$HARNESS_DIR/feature-list.json" ]; then
        NEEDS_MIGRATION=true
    fi
fi

# ============================================================================
# V3.0 MEMORY LAYER STATUS
# ============================================================================

# Get memory layer stats
WORKING_COMPUTED=""
EPISODIC_COUNT=0
FAILURES_COUNT=0
SUCCESSES_COUNT=0

# Check for v3.0 structure
if [ -d "$HARNESS_DIR/memory" ]; then
    IS_V3=true

    # Working context
    if [ -f "$HARNESS_DIR/memory/working/context.json" ]; then
        WORKING_COMPUTED=$(grep -o '"computedAt"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/memory/working/context.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # Episodic memory
    if [ -f "$HARNESS_DIR/memory/episodic/decisions.json" ]; then
        EPISODIC_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/episodic/decisions.json" 2>/dev/null || echo "0")
    fi

    # Procedural memory (failures/successes)
    if [ -f "$HARNESS_DIR/memory/procedural/failures.json" ]; then
        FAILURES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/procedural/failures.json" 2>/dev/null || echo "0")
    fi
    if [ -f "$HARNESS_DIR/memory/procedural/successes.json" ]; then
        SUCCESSES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/procedural/successes.json" 2>/dev/null || echo "0")
    fi

    # Learned rules (from user corrections)
    RULES_COUNT=0
    if [ -f "$HARNESS_DIR/memory/learned/rules.json" ]; then
        RULES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/learned/rules.json" 2>/dev/null || echo "0")
    fi

    # Features from new location (shared across sessions)
    FEATURES_FILE="$HARNESS_DIR/features/active.json"
    AGENT_FILE="$HARNESS_DIR/agents/context.json"

    # Session-scoped files (v3.8.0 - parallel work streams)
    # First check if session-specific files exist, fallback to legacy paths
    if [ -d "$SESSION_DIR" ]; then
        LOOP_FILE="$SESSION_DIR/loop-state.json"
        WORKING_FILE="$SESSION_DIR/context.json"
    else
        # Fallback to legacy paths for backward compatibility
        LOOP_FILE="$HARNESS_DIR/loops/state.json"
        WORKING_FILE="$HARNESS_DIR/memory/working/context.json"
    fi
else
    IS_V3=false
    # Fallback to v2.x locations
    FEATURES_FILE="$HARNESS_DIR/feature-list.json"
    LOOP_FILE="$HARNESS_DIR/loop-state.json"
    AGENT_FILE="$HARNESS_DIR/agent-context.json"
    WORKING_FILE="$HARNESS_DIR/working-context.json"
fi

# Get active feature from working-context
ACTIVE_FEATURE=""
FEATURE_SUMMARY=""
if [ -f "$WORKING_FILE" ]; then
    ACTIVE_FEATURE=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' "$WORKING_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    FEATURE_SUMMARY=$(grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' "$WORKING_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Get feature counts (handle both v2 and v3 schemas)
TOTAL_FEATURES=0
PENDING_FEATURES=0
if [ -f "$FEATURES_FILE" ]; then
    TOTAL_FEATURES=$(grep -c '"id"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
    if [ "$IS_V3" = true ]; then
        # v3 uses status field
        PENDING_FEATURES=$(grep -c '"status"[[:space:]]*:[[:space:]]*"pending"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
        IN_PROGRESS=$(grep -c '"status"[[:space:]]*:[[:space:]]*"in_progress"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
        NEEDS_TESTS=$(grep -c '"status"[[:space:]]*:[[:space:]]*"needs_tests"' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
    else
        # v2 uses passes field
        PENDING_FEATURES=$(grep -c '"passes"[[:space:]]*:[[:space:]]*false' "$FEATURES_FILE" 2>/dev/null | head -1 || echo "0")
    fi
fi

# Get orchestration state
ORCH_FEATURE=""
ORCH_PHASE=""
if [ -f "$AGENT_FILE" ]; then
    ORCH_FEATURE=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGENT_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    ORCH_PHASE=$(grep -o '"orchestrationPhase"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGENT_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Get active loop state (PRIORITY - shows before other status)
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

# Get last session summary
LAST_SUMMARY=""
if [ -f "$HARNESS_DIR/claude-progress.json" ]; then
    LAST_SUMMARY=$(grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/claude-progress.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# ============================================================================
# BUILD USER-VISIBLE MESSAGE
# ============================================================================

# Check for active loop first (highest priority)
LOOP_LINE=""
if [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
    LOOP_LINE="ACTIVE LOOP: $LOOP_FEATURE (attempt $LOOP_ATTEMPT/$LOOP_MAX)"
fi

# Build status line
STATUS_LINE=""
if [ "$IS_V3" = true ]; then
    # v3 format with more status detail
    if [ "$PENDING_FEATURES" != "0" ] || [ "$IN_PROGRESS" != "0" ] || [ "$NEEDS_TESTS" != "0" ]; then
        STATUS_LINE="P:$PENDING_FEATURES WIP:$IN_PROGRESS Tests:$NEEDS_TESTS"
    else
        STATUS_LINE="No pending features"
    fi
else
    # v2 format
    if [ "$PENDING_FEATURES" != "0" ]; then
        STATUS_LINE="$PENDING_FEATURES pending"
    else
        STATUS_LINE="No pending features"
    fi
fi

if [ -n "$ACTIVE_FEATURE" ] && [ "$ACTIVE_FEATURE" != "null" ]; then
    STATUS_LINE="$STATUS_LINE | Active: $ACTIVE_FEATURE"
fi

if [ -n "$ORCH_FEATURE" ] && [ "$ORCH_FEATURE" != "null" ] && [ "$ORCH_PHASE" != "completed" ]; then
    STATUS_LINE="$STATUS_LINE | Orch: $ORCH_PHASE"
fi

# Build memory status line (v3 only)
MEMORY_LINE=""
if [ "$IS_V3" = true ]; then
    MEMORY_LINE="Memory: $EPISODIC_COUNT decisions | $FAILURES_COUNT failures | $RULES_COUNT rules"
fi

# Build the box output (65 chars wide inner content)
STATUS_PADDED=$(printf "%-61s" "$STATUS_LINE")

# Build box based on version and state
if [ -n "$LOOP_LINE" ]; then
    # Active loop - highest priority display
    LOOP_PADDED=$(printf "%-61s" "$LOOP_LINE")
    RESUME_CMD="/claude-harness:do $LOOP_FEATURE"
    RESUME_PADDED=$(printf "%-61s" "Resume: $RESUME_CMD")

    if [ "$IS_V3" = true ]; then
        MEMORY_PADDED=$(printf "%-61s" "$MEMORY_LINE")
        USER_MSG="
┌─────────────────────────────────────────────────────────────────┐
│                  CLAUDE HARNESS v$PLUGIN_VERSION (Memory Architecture)     │
├─────────────────────────────────────────────────────────────────┤
│  $LOOP_PADDED│
│  $RESUME_PADDED│
├─────────────────────────────────────────────────────────────────┤
│  $STATUS_PADDED│
│  $MEMORY_PADDED│
├─────────────────────────────────────────────────────────────────┤
│  /claude-harness:do           Resume or start workflow          │
│  /claude-harness:checkpoint   Commit + persist memory           │
└─────────────────────────────────────────────────────────────────┘"
    else
        USER_MSG="
┌─────────────────────────────────────────────────────────────────┐
│                     CLAUDE HARNESS v$PLUGIN_VERSION                       │
├─────────────────────────────────────────────────────────────────┤
│  $LOOP_PADDED│
│  $RESUME_PADDED│
├─────────────────────────────────────────────────────────────────┤
│  $STATUS_PADDED│
├─────────────────────────────────────────────────────────────────┤
│  Commands:                                                      │
│  /claude-harness:do          Resume or start workflow           │
│  /claude-harness:start       Full status + GitHub sync          │
│  /claude-harness:checkpoint  Commit, push, create/update PR     │
└─────────────────────────────────────────────────────────────────┘"
    fi
elif [ "$IS_V3" = true ]; then
    # v3.0 display without active loop
    MEMORY_PADDED=$(printf "%-61s" "$MEMORY_LINE")
    USER_MSG="
┌─────────────────────────────────────────────────────────────────┐
│                  CLAUDE HARNESS v$PLUGIN_VERSION (Memory Architecture)     │
├─────────────────────────────────────────────────────────────────┤
│  $STATUS_PADDED│
│  $MEMORY_PADDED│
├─────────────────────────────────────────────────────────────────┤
│  /claude-harness:setup          Initialize harness (one-time)   │
│  /claude-harness:start          Compile context + GitHub sync   │
│  /claude-harness:do             Unified workflow (features+fixes)│
│  /claude-harness:do-tdd         TDD workflow (tests first)      │
│  /claude-harness:checkpoint     Commit + persist memory         │
│  /claude-harness:orchestrate    Spawn multi-agent team          │
│  /claude-harness:merge          Merge PRs + auto-version        │
└─────────────────────────────────────────────────────────────────┘"
else
    # v2.x display
    USER_MSG="
┌─────────────────────────────────────────────────────────────────┐
│                     CLAUDE HARNESS v$PLUGIN_VERSION                       │
├─────────────────────────────────────────────────────────────────┤
│  $STATUS_PADDED│
├─────────────────────────────────────────────────────────────────┤
│  Commands:                                                      │
│  /claude-harness:start       Full status + GitHub sync          │
│  /claude-harness:do          Unified workflow (features+fixes)  │
│  /claude-harness:orchestrate Spawn multi-agent team             │
│  /claude-harness:checkpoint  Commit, push, create/update PR     │
│  /claude-harness:merge       Merge PRs + create release         │
└─────────────────────────────────────────────────────────────────┘"
fi

# Add version update notice if applicable
if [ -n "$VERSION_MSG" ]; then
    USER_MSG="$USER_MSG
     ⚠️  $VERSION_MSG - run /claude-harness:setup to update"
fi

# Add migration notice if needed
if [ "$NEEDS_MIGRATION" = true ]; then
    USER_MSG="$USER_MSG
     🔄 v2.x detected - run /claude-harness:setup to upgrade to v3.0"
fi

# ============================================================================
# BUILD CLAUDE CONTEXT
# ============================================================================

CLAUDE_CONTEXT="=== CLAUDE HARNESS SESSION (v$PLUGIN_VERSION) ===\n"

# Add session info for parallel work streams
CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nSession ID: $SESSION_ID"
CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nSession Dir: .claude-harness/sessions/$SESSION_ID/"

if [ "$IS_V3" = true ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n=== MEMORY ARCHITECTURE v3.0 ==="
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nEpisodic Memory: $EPISODIC_COUNT decisions recorded"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nProcedural Memory: $FAILURES_COUNT failures, $SUCCESSES_COUNT successes"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nLearned Rules: $RULES_COUNT rules from user corrections"

    if [ -n "$WORKING_COMPUTED" ]; then
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nWorking Context: Last compiled $WORKING_COMPUTED"
    else
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nWorking Context: Not compiled - run /claude-harness:start"
    fi

    # Add failure prevention context if there are failures to avoid
    if [ "$FAILURES_COUNT" -gt 0 ]; then
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** FAILURE PREVENTION ACTIVE ***"
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n$FAILURES_COUNT past failures recorded. /claude-harness:do automatically checks these before implementation."
    fi
fi

if [ -n "$VERSION_MSG" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nVersion: $VERSION_MSG"
fi

if [ -n "$ACTIVE_FEATURE" ] && [ "$ACTIVE_FEATURE" != "null" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nRESUMING WORK:\nFeature: $ACTIVE_FEATURE\nSummary: $FEATURE_SUMMARY"
fi

if [ "$TOTAL_FEATURES" != "0" ]; then
    if [ "$IS_V3" = true ]; then
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nFeatures: P:$PENDING_FEATURES WIP:$IN_PROGRESS Tests:$NEEDS_TESTS / $TOTAL_FEATURES total"
    else
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nFeatures: $PENDING_FEATURES pending / $TOTAL_FEATURES total"
    fi
fi

# Add active loop context (PRIORITY)
if [ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** ACTIVE AGENTIC LOOP ***\nFeature: $LOOP_FEATURE\nAttempt: $LOOP_ATTEMPT of $LOOP_MAX\nStatus: In Progress\n\nIMPORTANT: Resume the loop with: /claude-harness:do $LOOP_FEATURE\nThe loop will continue from the last attempt, analyzing previous errors to try a different approach."

    if [ "$IS_V3" = true ]; then
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nPast failures for this feature are recorded in memory/procedural/failures.json."
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nConsult these before attempting a new approach."
        CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nResume with: /claude-harness:do $LOOP_FEATURE"
    fi
fi

if [ -n "$ORCH_FEATURE" ] && [ "$ORCH_FEATURE" != "null" ] && [ "$ORCH_PHASE" != "completed" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nACTIVE ORCHESTRATION:\nFeature: $ORCH_FEATURE\nPhase: $ORCH_PHASE\nResume with: /claude-harness:orchestrate $ORCH_FEATURE"
fi

if [ -n "$LAST_SUMMARY" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nLast session: $LAST_SUMMARY"
fi

# V3 specific recommendations
if [ "$IS_V3" = true ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n=== v3.8 WORKFLOW (7 commands) ===\n1. /claude-harness:setup - Initialize harness (one-time)\n2. /claude-harness:start - Compile context + GitHub sync\n3. /claude-harness:do - Unified workflow (features AND fixes)\n4. /claude-harness:do-tdd - TDD workflow (tests first)\n5. /claude-harness:checkpoint - Manual commit + push + PR\n6. /claude-harness:orchestrate - Multi-agent team (advanced)\n7. /claude-harness:merge - Merge PRs, auto-version, release\n\n*** PARALLEL SESSIONS ENABLED ***\nThis session has its own state directory. Multiple Claude instances can work on different features simultaneously without conflicts."
else
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nACTION: Run /claude-harness:start for full session status with GitHub sync."
fi

# ============================================================================
# OUTPUT JSON
# ============================================================================

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
    "sessionId": "$SESSION_ID",
    "sessionDir": "$SESSION_DIR",
    "additionalContext": "$CLAUDE_CONTEXT_ESCAPED"
  }
}
EOF
