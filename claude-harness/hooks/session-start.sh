#!/bin/bash
# Claude Harness SessionStart Hook

HARNESS_DIR="$CLAUDE_PROJECT_DIR/.claude-harness"
[ ! -d "$HARNESS_DIR" ] && exit 0

# --- Reusable box formatting ---
build_box() {
    local TOP="┌─────────────────────────────────────────────────────────────────┐"
    local SEP="├─────────────────────────────────────────────────────────────────┤"
    local BOT="└─────────────────────────────────────────────────────────────────┘"
    local out="$TOP"
    for line in "$@"; do
        if [ "$line" = "---" ]; then out="$out
$SEP"
        else out="$out
│$(printf '%-63s' "  $line")│"
        fi
    done
    echo "$out
$BOT"
}

# --- GitHub repo caching ---
GITHUB_OWNER=""; GITHUB_REPO=""
REMOTE_URL=$(git remote get-url origin 2>/dev/null)
if [ -n "$REMOTE_URL" ]; then
    if [[ "$REMOTE_URL" =~ git@github\.com:([^/]+)/([^/.]+) ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"; GITHUB_REPO="${BASH_REMATCH[2]}"
    elif [[ "$REMOTE_URL" =~ github\.com/([^/]+)/([^/.]+) ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"; GITHUB_REPO="${BASH_REMATCH[2]}"
    fi
    GITHUB_REPO="${GITHUB_REPO%.git}"
fi

# --- Stale plugin cache detection & auto-update ---
PLUGIN_REPO="panayiotism/claude-harness"
CACHE_BASE="$HOME/.claude/plugins/cache/claude-harness/claude-harness"
CACHE_CHECK="$HOME/.claude/plugins/cache/claude-harness/.version-check"
INST_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces/claude-harness"
PLUGIN_BRANCH="main"
[ -f "$CACHE_BASE/.branch" ] && PLUGIN_BRANCH=$(cat "$CACHE_BASE/.branch" 2>/dev/null)
LATEST_VERSION=""; CACHE_IS_STALE=false; CACHE_UPDATED=false

check_latest_version() {
    local now; now=$(date +%s)
    if [ -f "$CACHE_CHECK" ]; then
        local ct cv; ct=$(head -1 "$CACHE_CHECK" 2>/dev/null); cv=$(tail -1 "$CACHE_CHECK" 2>/dev/null)
        if [ -n "$ct" ] && [ -n "$cv" ] && [ $((now - ct)) -lt 86400 ]; then
            LATEST_VERSION="$cv"; return 0
        fi
    fi
    local v=""
    command -v gh &>/dev/null && v=$(gh api "repos/$PLUGIN_REPO/contents/claude-harness/.claude-plugin/plugin.json?ref=$PLUGIN_BRANCH" \
        --jq '.content' 2>/dev/null | base64 -d 2>/dev/null | grep '"version"' | sed 's/.*: *"\([^"]*\)".*/\1/')
    [ -z "$v" ] && v=$(curl -sf --max-time 5 \
        "https://raw.githubusercontent.com/$PLUGIN_REPO/$PLUGIN_BRANCH/claude-harness/.claude-plugin/plugin.json" \
        2>/dev/null | grep '"version"' | sed 's/.*: *"\([^"]*\)".*/\1/')
    if [ -n "$v" ]; then
        LATEST_VERSION="$v"
        mkdir -p "$(dirname "$CACHE_CHECK")"
        printf '%s\n%s\n' "$now" "$v" > "$CACHE_CHECK"
    fi
}

auto_update_cache() {
    # Step 1: Update marketplace git clone (Claude Code resolves plugins from here)
    if [ -d "$MARKETPLACE_DIR/.git" ]; then
        (cd "$MARKETPLACE_DIR" && git fetch origin "$PLUGIN_BRANCH" 2>/dev/null && git reset --hard "origin/$PLUGIN_BRANCH" 2>/dev/null) || true
    fi

    # Step 2: Download latest plugin tarball
    local tmp; tmp=$(mktemp -d) || return 1
    trap 'rm -rf "$tmp"' RETURN
    local ok=false
    command -v gh &>/dev/null && gh api "repos/$PLUGIN_REPO/tarball/$PLUGIN_BRANCH" > "$tmp/r.tar.gz" 2>/dev/null && ok=true
    [ "$ok" = false ] && curl -sfL --max-time 30 "https://github.com/$PLUGIN_REPO/archive/refs/heads/$PLUGIN_BRANCH.tar.gz" -o "$tmp/r.tar.gz" 2>/dev/null && ok=true
    [ "$ok" = false ] && return 1
    tar -xzf "$tmp/r.tar.gz" -C "$tmp" 2>/dev/null || return 1
    local ext; ext=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)
    local src="$ext/claude-harness"
    [ ! -f "$src/.claude-plugin/plugin.json" ] && return 1
    local sha=""
    command -v gh &>/dev/null && sha=$(gh api "repos/$PLUGIN_REPO/commits/$PLUGIN_BRANCH" --jq '.sha' 2>/dev/null)
    [ -z "$sha" ] && sha=$(curl -sf --max-time 5 "https://api.github.com/repos/$PLUGIN_REPO/commits/$PLUGIN_BRANCH" 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    # Step 3: Create new cache directory
    local nc="$CACHE_BASE/$LATEST_VERSION"
    rm -rf "$nc" 2>/dev/null; mkdir -p "$nc"
    cp -r "$src/." "$nc/" || return 1
    chmod +x "$nc/hooks/"*.sh "$nc/setup.sh" 2>/dev/null

    # Step 4: Update installed_plugins.json registry
    if [ -f "$INST_PLUGINS" ] && command -v python3 &>/dev/null; then
        python3 -c "
import json; from datetime import datetime, timezone
with open('$INST_PLUGINS') as f: data = json.load(f)
p = data.get('plugins',{}).get('claude-harness@claude-harness',[])
if p:
    p[0]['installPath']='$nc'; p[0]['version']='$LATEST_VERSION'
    ${sha:+p[0][\"gitCommitSha\"]=\"$sha\"}
    p[0]['lastUpdated']=datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3]+'Z'
with open('$INST_PLUGINS','w') as f: json.dump(data,f,indent=2); f.write('\n')
" 2>/dev/null || return 1
    else return 1; fi
    rm -f "$CACHE_CHECK" 2>/dev/null
    CACHE_UPDATED=true
}

check_latest_version 2>/dev/null
PLUGIN_VERSION_CACHED=$(grep '"version"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')
if [ -n "$LATEST_VERSION" ] && [ -n "$PLUGIN_VERSION_CACHED" ] && [ "$LATEST_VERSION" != "$PLUGIN_VERSION_CACHED" ]; then
    CACHE_IS_STALE=true
    auto_update_cache 2>/dev/null
fi

# --- Session management ---
SESSION_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "sess-$(date +%s%N | sha256sum | head -c 16)")
SESSION_DIR="$HARNESS_DIR/sessions/$SESSION_ID"
mkdir -p "$SESSION_DIR"
cat > "$SESSION_DIR/session.json" << SESSIONEOF
{ "id": "$SESSION_ID", "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "pid": "$$", "workingDir": "$CLAUDE_PROJECT_DIR" }
SESSIONEOF

# --- Stale session cleanup ---
SESSIONS_DIR="$HARNESS_DIR/sessions"; RECOVERY_DIR="$SESSIONS_DIR/.recovery"; CLEANED_COUNT=0
if [ -d "$SESSIONS_DIR" ]; then
    for sd in "$SESSIONS_DIR"/*/; do
        [ -d "$sd" ] || continue
        sid=$(basename "$sd"); [ "$sid" = "$SESSION_ID" ] && continue; [ "$sid" = ".recovery" ] && continue
        sf="$sd/session.json"; [ -f "$sf" ] || continue
        pid=$(grep '"pid"' "$sf" 2>/dev/null | grep -o '[0-9]\+')
        if [ -z "$pid" ] || ! ps -p "$pid" > /dev/null 2>&1; then
            lf="$sd/loop-state.json"
            if [ -f "$lf" ]; then
                ls=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$lf" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                if [ "$ls" = "in_progress" ]; then
                    lfeat=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$lf" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                    latmp=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$lf" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
                    lphase=$(grep -o '"phase"[[:space:]]*:[[:space:]]*"[^"]*"' "$lf" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
                    mkdir -p "$RECOVERY_DIR"
                    cat > "$RECOVERY_DIR/interrupted.json" << INTEOF
{ "version":1, "interruptedAt":"$(date -u +%Y-%m-%dT%H:%M:%SZ)", "staleSessionId":"$sid", "feature":"$lfeat", "attemptAtInterrupt":${latmp:-1}, "tddPhase":"${lphase:-null}", "reason":"stale-session-detected" }
INTEOF
                    cp "$lf" "$RECOVERY_DIR/loop-state.json" 2>/dev/null
                    [ -f "$sd/autonomous-state.json" ] && cp "$sd/autonomous-state.json" "$RECOVERY_DIR/autonomous-state.json" 2>/dev/null
                fi
            fi
            rm -rf "$sd"; CLEANED_COUNT=$((CLEANED_COUNT + 1))
        fi
    done
fi

# --- Version & memory status ---
PLUGIN_VERSION=$(grep '"version"' "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/')
PROJECT_VERSION=$(cat "$HARNESS_DIR/.plugin-version" 2>/dev/null)
VERSION_MSG=""
[ -z "$PROJECT_VERSION" ] && VERSION_MSG="Harness not initialized - run /claude-harness:setup"
[ -n "$PROJECT_VERSION" ] && [ "$PLUGIN_VERSION" != "$PROJECT_VERSION" ] && \
    VERSION_MSG="Plugin v$PLUGIN_VERSION (project at v$PROJECT_VERSION) - run /claude-harness:setup to migrate"

EPISODIC_COUNT=0; FAILURES_COUNT=0; SUCCESSES_COUNT=0; RULES_COUNT=0; WORKING_COMPUTED=""; IS_V3=false
if [ -d "$HARNESS_DIR/memory" ]; then
    IS_V3=true
    [ -f "$HARNESS_DIR/memory/working/context.json" ] && WORKING_COMPUTED=$(grep -o '"computedAt"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/memory/working/context.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    [ -f "$HARNESS_DIR/memory/episodic/decisions.json" ] && EPISODIC_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/episodic/decisions.json" 2>/dev/null || echo "0")
    [ -f "$HARNESS_DIR/memory/procedural/failures.json" ] && FAILURES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/procedural/failures.json" 2>/dev/null || echo "0")
    [ -f "$HARNESS_DIR/memory/procedural/successes.json" ] && SUCCESSES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/procedural/successes.json" 2>/dev/null || echo "0")
    [ -f "$HARNESS_DIR/memory/learned/rules.json" ] && RULES_COUNT=$(grep -c '"id"' "$HARNESS_DIR/memory/learned/rules.json" 2>/dev/null || echo "0")
fi

FEATURES_FILE="$HARNESS_DIR/features/active.json"; AGENT_FILE="$HARNESS_DIR/agents/context.json"
LOOP_FILE="$SESSION_DIR/loop-state.json"; WORKING_FILE="$SESSION_DIR/context.json"

ACTIVE_FEATURE=""; FEATURE_SUMMARY=""
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

ORCH_FEATURE=""; ORCH_PHASE=""
if [ -f "$AGENT_FILE" ]; then
    ORCH_FEATURE=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGENT_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    ORCH_PHASE=$(grep -o '"orchestrationPhase"[[:space:]]*:[[:space:]]*"[^"]*"' "$AGENT_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

LOOP_FEATURE=""; LOOP_STATUS=""; LOOP_ATTEMPT=""; LOOP_MAX=""
if [ -f "$LOOP_FILE" ]; then
    LOOP_STATUS=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    if [ "$LOOP_STATUS" = "in_progress" ]; then
        LOOP_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
        LOOP_ATTEMPT=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
        LOOP_MAX=$(grep -o '"maxAttempts"[[:space:]]*:[[:space:]]*[0-9]*' "$LOOP_FILE" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    fi
fi

INT_FEATURE=""; INT_ATTEMPT=""; INT_PHASE=""
if [ -f "$RECOVERY_DIR/interrupted.json" ]; then
    INT_FEATURE=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' "$RECOVERY_DIR/interrupted.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    INT_ATTEMPT=$(grep -o '"attemptAtInterrupt"[[:space:]]*:[[:space:]]*[0-9]*' "$RECOVERY_DIR/interrupted.json" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    INT_PHASE=$(grep -o '"tddPhase"[[:space:]]*:[[:space:]]*"[^"]*"' "$RECOVERY_DIR/interrupted.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

LAST_SUMMARY=""
[ -f "$HARNESS_DIR/claude-progress.json" ] && LAST_SUMMARY=$(grep -o '"summary"[[:space:]]*:[[:space:]]*"[^"]*"' "$HARNESS_DIR/claude-progress.json" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

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

BOX_LINES=("CLAUDE HARNESS v$PLUGIN_VERSION")
if [ -n "$LOOP_LINE" ]; then
    BOX_LINES+=("---" "$LOOP_LINE" "Resume: /claude-harness:flow $LOOP_FEATURE")
fi
BOX_LINES+=("---" "$STATUS_LINE")
[ "$IS_V3" = true ] && BOX_LINES+=("Memory: $EPISODIC_COUNT decisions | $FAILURES_COUNT failures | $RULES_COUNT rules")
BOX_LINES+=("---" "/claude-harness:flow        Unified workflow (recommended)" "Flags: --no-merge --plan-only --autonomous --quick --fix")

USER_MSG=$(build_box "${BOX_LINES[@]}")

[ -n "$VERSION_MSG" ] && USER_MSG="$USER_MSG"$'\n'"     $VERSION_MSG"
if [ "$CACHE_UPDATED" = true ]; then
    USER_MSG="$USER_MSG"$'\n'"     Updated v$PLUGIN_VERSION_CACHED -> v$LATEST_VERSION. Restart Claude Code to load new version."
elif [ "$CACHE_IS_STALE" = true ]; then
    USER_MSG="$USER_MSG"$'\n'"     STALE CACHE: v$PLUGIN_VERSION_CACHED (v$LATEST_VERSION available)"
    USER_MSG="$USER_MSG"$'\n'"     Fix: claude plugin uninstall claude-harness && claude plugin install claude-harness github:panayiotism/claude-harness"
fi

# --- Build Claude context ---
CLAUDE_CONTEXT="=== CLAUDE HARNESS SESSION (v$PLUGIN_VERSION) ==="
CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nSession ID: $SESSION_ID\nSession Dir: .claude-harness/sessions/$SESSION_ID/\nPlugin Root: $CLAUDE_PLUGIN_ROOT"

if [ "$CACHE_UPDATED" = true ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** PLUGIN AUTO-UPDATED v$PLUGIN_VERSION_CACHED -> v$LATEST_VERSION ***\nTell user to restart Claude Code, then run setup to sync."
elif [ "$CACHE_IS_STALE" = true ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** STALE PLUGIN CACHE (auto-update failed) ***\nInstalled: v$PLUGIN_VERSION_CACHED | Latest: v$LATEST_VERSION\nTell user: claude plugin uninstall claude-harness && claude plugin install claude-harness github:panayiotism/claude-harness"
fi

if [ -n "$GITHUB_OWNER" ] && [ -n "$GITHUB_REPO" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n=== GITHUB (CACHED) ===\nOwner: $GITHUB_OWNER\nRepo: $GITHUB_REPO\nIMPORTANT: Use these cached values for ALL GitHub API calls. Do NOT re-parse git remote."
fi

if [ "$IS_V3" = true ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n=== MEMORY ARCHITECTURE v3.0 ==="
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nEpisodic Memory: $EPISODIC_COUNT decisions recorded"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nProcedural Memory: $FAILURES_COUNT failures, $SUCCESSES_COUNT successes"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nLearned Rules: $RULES_COUNT rules from user corrections"
    [ -n "$WORKING_COMPUTED" ] && CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nWorking Context: Last compiled $WORKING_COMPUTED" \
        || CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nWorking Context: Not compiled - run /start"
fi

[ -n "$VERSION_MSG" ] && CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nVersion: $VERSION_MSG"
[ -n "$ACTIVE_FEATURE" ] && [ "$ACTIVE_FEATURE" != "null" ] && \
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nRESUMING WORK:\nFeature: $ACTIVE_FEATURE\nSummary: $FEATURE_SUMMARY"
[ "$TOTAL_FEATURES" != "0" ] && \
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nFeatures: P:$PENDING_FEATURES WIP:$IN_PROGRESS Tests:$NEEDS_TESTS / $TOTAL_FEATURES total"

if [ -n "$INT_FEATURE" ]; then
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** INTERRUPTED SESSION DETECTED ***"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nFeature: $INT_FEATURE was interrupted at attempt $INT_ATTEMPT\nTDD Phase: ${INT_PHASE:-null}"
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\nRecovery: .claude-harness/sessions/.recovery/interrupted.json\nResume: /claude-harness:flow $INT_FEATURE\nIMPORTANT: On resume, flow will offer recovery options. Do NOT retry same approach blindly."
fi

[ -n "$LOOP_FEATURE" ] && [ "$LOOP_STATUS" = "in_progress" ] && \
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\n*** ACTIVE AGENTIC LOOP ***\nFeature: $LOOP_FEATURE\nAttempt: $LOOP_ATTEMPT of $LOOP_MAX\nStatus: In Progress"
[ -n "$ORCH_FEATURE" ] && [ "$ORCH_FEATURE" != "null" ] && [ "$ORCH_PHASE" != "completed" ] && \
    CLAUDE_CONTEXT="$CLAUDE_CONTEXT\n\nACTIVE ORCHESTRATION:\nFeature: $ORCH_FEATURE\nPhase: $ORCH_PHASE"
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
    "github": { "owner": "$GITHUB_OWNER", "repo": "$GITHUB_REPO" },
    "additionalContext": "$CLAUDE_CONTEXT_ESCAPED"
  }
}
EOF
