#!/bin/bash
# Claude Harness PreCompact Hook v5.1.4
# Saves critical state before context compaction to prevent data loss
# This is a safety net - ideally users run /claude-harness:checkpoint then /clear

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    echo '{"continue": true}'
    exit 0
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# ============================================================================
# SAVE EMERGENCY STATE BEFORE COMPACTION
# ============================================================================

# Create compaction backup directory
BACKUP_DIR="$HARNESS_DIR/memory/compaction-backups"
mkdir -p "$BACKUP_DIR"

# Generate backup filename with timestamp
BACKUP_FILE="$BACKUP_DIR/pre-compact-$(date +%Y%m%d-%H%M%S).json"

# Gather current state
LOOP_STATE=""
if [ -f "$HARNESS_DIR/loops/state.json" ]; then
    LOOP_STATE=$(cat "$HARNESS_DIR/loops/state.json" 2>/dev/null)
fi

WORKING_CONTEXT=""
if [ -f "$HARNESS_DIR/memory/working/context.json" ]; then
    WORKING_CONTEXT=$(cat "$HARNESS_DIR/memory/working/context.json" 2>/dev/null)
fi

PROGRESS=""
if [ -f "$HARNESS_DIR/claude-progress.json" ]; then
    PROGRESS=$(cat "$HARNESS_DIR/claude-progress.json" 2>/dev/null)
fi

# Get git status for context
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
GIT_STATUS=$(git status --porcelain 2>/dev/null | head -20)
GIT_LAST_COMMIT=$(git log -1 --format="%h %s" 2>/dev/null || echo "unknown")

# Create backup JSON
cat > "$BACKUP_FILE" << BACKUP_EOF
{
  "timestamp": "$TIMESTAMP",
  "reason": "pre-compaction-safety-backup",
  "git": {
    "branch": "$GIT_BRANCH",
    "lastCommit": "$GIT_LAST_COMMIT",
    "uncommittedFiles": $(echo "$GIT_STATUS" | wc -l)
  },
  "loopState": $LOOP_STATE,
  "workingContext": $WORKING_CONTEXT,
  "progress": $PROGRESS
}
BACKUP_EOF

# Keep only last 5 backups to avoid bloat
ls -t "$BACKUP_DIR"/pre-compact-*.json 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null

# ============================================================================
# UPDATE PROGRESS WITH COMPACTION NOTE
# ============================================================================

# Add compaction event to progress if file exists
if [ -f "$HARNESS_DIR/claude-progress.json" ]; then
    # Use a simple approach - just note that compaction happened
    TEMP_FILE=$(mktemp)
    if command -v jq &> /dev/null; then
        jq --arg ts "$TIMESTAMP" '.lastCompaction = $ts | .compactionCount = ((.compactionCount // 0) + 1)' \
            "$HARNESS_DIR/claude-progress.json" > "$TEMP_FILE" 2>/dev/null && \
            mv "$TEMP_FILE" "$HARNESS_DIR/claude-progress.json"
    fi
fi

# ============================================================================
# OUTPUT FOR CLAUDE
# ============================================================================

# Build message for Claude
USER_MSG="WARNING: Context compaction triggered - state backed up to $BACKUP_FILE"

CLAUDE_CONTEXT="PRE-COMPACTION SAFETY BACKUP CREATED

State has been preserved before compaction:
- Backup: $BACKUP_FILE
- Branch: $GIT_BRANCH
- Last commit: $GIT_LAST_COMMIT

Opus 4.6 native context compaction is active. The model will automatically
summarize and compress context intelligently, preserving task-relevant information.
Your memory layers remain intact (episodic, procedural, semantic, learned).

After compaction, run /claude-harness:start only if context feels incomplete.

TIP: Opus 4.6 compaction is smarter than manual /clear - it preserves task-relevant
context automatically. Only run /checkpoint + /clear if you want a full reset."

# Escape for JSON
USER_MSG_ESCAPED=$(echo "$USER_MSG" | sed 's/"/\\"/g')
CLAUDE_CONTEXT_ESCAPED=$(echo "$CLAUDE_CONTEXT" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Output JSON response
cat << EOF
{
  "continue": true,
  "systemMessage": "$USER_MSG_ESCAPED",
  "hookSpecificOutput": {
    "hookEventName": "PreCompact",
    "additionalContext": "$CLAUDE_CONTEXT_ESCAPED"
  }
}
EOF
