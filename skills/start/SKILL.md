---
name: start
description: Start a coding session with full context compilation, GitHub sync, and memory loading. Use for session start, project status check, context restoration, loop state recovery, GitHub issue synchronization, and feature priority review.
allowed-tools: "Bash(git *), Bash(gh *)"
---

# Start - Session Initialization and Context Compilation

Prepare for a new coding session: compile memory context, show status, sync GitHub.

Session ID: ${CLAUDE_SESSION_ID} — session state lives in `.claude-harness/sessions/${CLAUDE_SESSION_ID}/`.

## Current Harness Snapshot (auto-compiled at invocation)

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/compile-briefing.py" .claude-harness 2>/dev/null || echo "(harness state not initialized - run /claude-harness:setup)"`

## Phase 0: Migration Check

Migrations are handled by `setup.sh`, which the SessionStart hook runs automatically whenever the plugin version changes. Only act here if legacy files are visible at the project root (`feature-list.json`, `feature-archive.json`, `claude-progress.json`, `working-context.json`, `agent-context.json`, `agent-memory.json`, `init.sh`): run `bash {plugin-root}/setup.sh` once (plugin root is in the session context) and report what it migrated.

## Phase 0.5: Set Paths

1. **Set path variables**:
   - `FEATURES_FILE=".claude-harness/features/active.json"`
   - `ARCHIVE_FILE=".claude-harness/features/archive.json"`
   - `MEMORY_DIR=".claude-harness/memory/"`
   - `SESSION_DIR=".claude-harness/sessions/${CLAUDE_SESSION_ID}/"`

**Important**: All subsequent phases must use these path variables instead of hardcoded paths.

## Phase 1: Context Compilation (Memory System)

The snapshot above already contains the compiled overview (features, recent decisions, failures to avoid, learned rules, last session). Use it directly - do NOT re-read the memory files unless you need detail beyond the snapshot.

1. **Deep-dive reads (only when needed)**: if the active feature requires filtering memory by `relatedFiles`, read the specific files IN PARALLEL (single message, multiple Read calls):
   - `${FEATURES_FILE}` (full feature entries)
   - `${MEMORY_DIR}/procedural/failures.json`
   - `${MEMORY_DIR}/procedural/successes.json`
   - `${MEMORY_DIR}/episodic/decisions.json`
   - `${MEMORY_DIR}/learned/rules.json`

2. **Write compiled context** to `${SESSION_DIR}/context.json`:
   ```json
   {
     "version": 3,
     "computedAt": "{ISO timestamp}",
     "sessionId": "${CLAUDE_SESSION_ID}",
     "github": { "owner": "{from session context}", "repo": "{from session context}" },
     "activeFeature": "{feature-id or null}",
     "relevantMemory": {
       "recentDecisions": [{...}],
       "projectPatterns": [{...}],
       "avoidApproaches": [{...}],
       "learnedRules": [{...}]
     },
     "currentTask": {
       "description": "{feature description}",
       "files": ["{relatedFiles}"],
       "acceptanceCriteria": ["{verification}"]
     }
   }
   ```
   - `relevantMemory` filtering: failures/successes where `feature` matches or `files` overlap the active feature's `relatedFiles` (top 5 each); decisions from the last 7 days or last 20 entries; learned rules where `applicability.always` is true, or `applicability.features`/`filePatterns` match the active feature.

3. **Display memory summary**:
   ```
   MEMORY CONTEXT COMPILED
   Recent decisions: {N} loaded
   Success patterns: {N} loaded
   Approaches to AVOID: {N} loaded
   Learned rules: {N} active
   ```
   If `avoidApproaches` or learned rules have entries, list them prominently.

## Phase 1.7: Refresh Session Briefing

**Regenerate persistent session briefing** at `.claude-harness/session-briefing.md` (same format as the snapshot above, keep under 120 lines). This keeps the briefing fresh for the next session start. Report: "Session briefing refreshed".

## Phase 2: Local Status

1. If the compiled context has an `activeFeature`, display prominently:
   ```
   === Resuming Work ===
   Feature: {activeFeature} - {summary}
   Working files: {relatedFiles}
   Next steps: {from briefing}
   ```

2. Read `.claude-harness/claude-progress.json` for last-session summary and blockers.

3. Read `${FEATURES_FILE}` to identify next priority.
   - If the file is too large to read (>25000 tokens), use `grep` for pending features and run `/claude-harness:checkpoint` to archive completed ones.

## Phase 3: Loop & Orchestration State

4. **Check active loop state** (PRIORITY):
   - **Interrupt recovery first**: read `.claude-harness/sessions/.recovery/interrupted.json`. If it exists:
     ```
     INTERRUPTED SESSION DETECTED
     Feature: {feature} | TDD Phase: {tddPhase} | Attempt: {attemptAtInterrupt}
     Resume: /claude-harness:flow {feature}  (recovery options will be presented)
     ```
   - Read `${SESSION_DIR}/loop-state.json` (legacy fallbacks: `.claude-harness/loops/state.json`, `.claude-harness/loop-state.json`)
   - If `status` is "in_progress": display feature/fix, attempt count, last approach and result, and the resume command `/claude-harness:flow {feature}`
   - If `status` is "escalated": show escalation reason and history summary; recommend providing guidance or retrying with a fresh delegation

5. **Check pending fixes**: read `${FEATURES_FILE}` `fixes` array for entries with `status` != "passing" and list them with their linked features.

6. **Check orchestration state**: read `.claude-harness/agents/context.json` if it exists.
   - `currentSession.activeFeature` set -> incomplete orchestration; recommend `/claude-harness:flow {feature-id}` to resume
   - `teamState` non-null -> display the team roster and status. Note: Agent Teams do not survive session restarts; if teammates are gone, flow will offer to spawn fresh ones or fall back to direct implementation.

7. **Check procedural memory hotspots**: read `${MEMORY_DIR}/procedural/patterns.json` if it exists; report any `codebaseInsights.hotspots` affecting current work.

## Phase 4: GitHub Integration

8. **Get GitHub owner/repo**: use the cached values from the session context (injected at SessionStart). Only if absent, parse once from `git remote get-url origin`.

9. **Fetch and display GitHub dashboard** (requires `gh` CLI; on failure check `gh auth status` and skip gracefully):
   - Open feature issues: `gh issue list --label feature --json number,title,labels`
   - Open PRs: `gh pr list --json number,title,headRefName,statusCheckRollup`
   - Cross-reference with `${FEATURES_FILE}`

10. **Sync GitHub Issues with `${FEATURES_FILE}`**:
    - For each GitHub issue with "feature" label NOT in active.json: add new entry with issueNumber linked
    - For each feature in active.json with status="passing" or passes=true: if the linked issue is still open, `gh issue close {number}`
    - Report sync results

## Phase 5: Recommendations

11. Report session summary:
    - Current state and blockers
    - Pending features and fixes prioritized
    - GitHub sync results
    - Recommended next action (in priority order):
      1. **Active loop (fix)**: Resume with `/claude-harness:flow {fix-id}`
      2. **Active loop (feature)**: Resume with `/claude-harness:flow {feature-id}`
      3. **Escalated loop**: Review history and provide guidance
      4. **Pending fixes**: Resume fix with `/claude-harness:flow {fix-id}`
      5. **No features (new project)**: Bootstrap with `/claude-harness:prd-breakdown @./prd.md`
      6. **Pending features**: Start implementation with `/claude-harness:flow {feature-id}`
      7. **No features (existing project)**: Add one with `/claude-harness:flow "description"`
      8. **Create fix for completed feature**: `/claude-harness:flow --fix {feature-id} "bug description"`
