#!/bin/bash
# Claude Harness PreToolUse Hook v7.0.0
# Branch safety + state protection
# Matchers: "Bash" and "Edit|Write" (registered separately in hooks.json)
# Exit 0 with permissionDecision: "deny" = block the tool call
# Exit 0 with no decision = allow

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"

# Skip if not a harness project
if [ ! -d "$HARNESS_DIR" ]; then
    exit 0
fi

# Read stdin JSON
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

# ============================================================================
# BASH TOOL — Block dangerous git commands and state destruction
# ============================================================================

if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    DENY_REASON=""

    # Block checkout to main/master ONLY if an active loop is in progress
    # (autonomous flow legitimately checks out main between features)
    if echo "$COMMAND" | grep -qE 'git\s+checkout\s+(main|master)\b'; then
        SESSIONS_DIR="$HARNESS_DIR/sessions"
        if [ -d "$SESSIONS_DIR" ]; then
            for sd in "$SESSIONS_DIR"/*/; do
                [ -d "$sd" ] || continue
                [ "$(basename "$sd")" = ".recovery" ] && continue
                lf="$sd/loop-state.json"
                [ -f "$lf" ] || continue
                ls=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$lf" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                if [ "$ls" = "in_progress" ]; then
                    DENY_REASON="BLOCKED: git checkout main/master while a feature loop is in progress. Stay on your feature branch."
                    break
                fi
            done
        fi
    fi

    # Block force push
    if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force'; then
        DENY_REASON="BLOCKED: git push --force is destructive. Use normal push or ask the user."
    fi

    # Block reset --hard
    if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
        DENY_REASON="BLOCKED: git reset --hard discards changes. Use git stash or ask the user."
    fi

    # Block clean -f
    if echo "$COMMAND" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f'; then
        DENY_REASON="BLOCKED: git clean -f deletes untracked files permanently. Ask the user."
    fi

    # Block direct push to main
    if echo "$COMMAND" | grep -qE 'git\s+push\s+origin\s+(main|master)\b'; then
        DENY_REASON="BLOCKED: Direct push to main/master. Use a PR workflow instead."
    fi

    # Block rm -rf of harness state
    if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f?\s+.*\.claude-harness'; then
        DENY_REASON="BLOCKED: Deleting .claude-harness would destroy all session state and memory."
    fi

    # Block branch -D (force delete)
    if echo "$COMMAND" | grep -qE 'git\s+branch\s+-D\b'; then
        DENY_REASON="BLOCKED: git branch -D force-deletes a branch. Use -d for safe delete or ask the user."
    fi

    if [ -n "$DENY_REASON" ]; then
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$DENY_REASON"
  }
}
EOF
        exit 0
    fi
fi

# ============================================================================
# EDIT/WRITE TOOL — Block writes to harness-managed state files
# ============================================================================

if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
    FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    DENY_REASON=""

    # Block writes to hooks (self-modification prevention)
    # Note: loop-state.json and active.json are NOT blocked here because /flow
    # legitimately writes these files using Write/Edit tools. The hook cannot
    # distinguish between /flow state management and accidental writes.
    if echo "$FILE_PATH" | grep -qE 'hooks/(hooks\.json|.*\.sh)$'; then
        DENY_REASON="BLOCKED: Hook files are managed by the harness plugin. Do not self-modify."
    fi

    if [ -n "$DENY_REASON" ]; then
        cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "$DENY_REASON"
  }
}
EOF
        exit 0
    fi
fi

# No issues found — allow the tool call (no output needed)
exit 0
