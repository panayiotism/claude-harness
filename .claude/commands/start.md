---
description: Start a harness session - shows status, GitHub integration, and syncs issues
---

Run the initialization script and prepare for a new coding session:

## Phase 0: Auto-Migration (Legacy Files)

Before anything else, check if legacy root-level harness files need migration:

1. Check if any of these files exist in the project root:
   - `feature-list.json`
   - `feature-archive.json`
   - `claude-progress.json`
   - `working-context.json`
   - `agent-context.json`
   - `agent-memory.json`
   - `init.sh`

2. If any legacy files exist AND `.claude-harness/` directory does NOT exist:
   - Create `.claude-harness/` directory
   - Move each file to `.claude-harness/`:
     - `mv feature-list.json .claude-harness/`
     - `mv feature-archive.json .claude-harness/`
     - `mv claude-progress.json .claude-harness/`
     - `mv working-context.json .claude-harness/`
     - `mv agent-context.json .claude-harness/`
     - `mv agent-memory.json .claude-harness/`
     - `mv init.sh .claude-harness/`
   - Report to user: "Migrated harness files to .claude-harness/ directory"

3. If `.claude-harness/` already exists, check for feature file migration:
   - If `feature-list.json` OR `feature-archive.json` exist at root level:
     - Create `.claude-harness/features/` directory if needed: `mkdir -p .claude-harness/features/`
     - Migrate files with renaming:
       - `mv feature-list.json .claude-harness/features/active.json` (if exists)
       - `mv feature-archive.json .claude-harness/features/archive.json` (if exists)
     - Also check for old files in `.claude-harness/` root:
       - `mv .claude-harness/feature-list.json .claude-harness/features/active.json` (if exists)
       - `mv .claude-harness/feature-archive.json .claude-harness/features/archive.json` (if exists)
     - Report to user: "Migrated feature files to .claude-harness/features/ with updated names"

4. **Create missing state files** (for plugin updates):
   - Check if each required state file exists, create with defaults if missing:
   - `.claude-harness/memory/learned/rules.json` (if missing):
     - First create directory if needed: `mkdir -p .claude-harness/memory/learned`
     - Then create file with defaults:
     ```json
     {
       "version": 3,
       "lastUpdated": "{ISO timestamp}",
       "metadata": {
         "totalRules": 0,
         "projectSpecific": 0,
         "general": 0,
         "lastReflection": null
       },
       "rules": []
     }
     ```
   - Report: "Created missing state file: {filename}"

   **Note**: Loop state and working context are now session-scoped and created at runtime in `.claude-harness/sessions/{session-id}/`. Legacy files at `.claude-harness/loop-state.json` and `.claude-harness/working-context.json` are no longer created.

## Phase 0.5: Set Paths

1. **Set path variables**:
   - `FEATURES_FILE=".claude-harness/features/active.json"`
   - `ARCHIVE_FILE=".claude-harness/features/archive.json"`
   - `MEMORY_DIR=".claude-harness/memory/"`
   - `SESSION_DIR=".claude-harness/sessions/{session-id}/"`

**Important**: All subsequent phases must use these path variables instead of hardcoded paths.

## Phase 1: Context Compilation (Memory System)

**Session ID**: The SessionStart hook automatically generates a unique session ID and creates a session directory at `.claude-harness/sessions/{session-id}/`. All session-specific state files should use this directory. The session ID is provided in the hook output as `sessionId` and `sessionDir`.

**OPTIMIZATION**: Read all memory layers IN PARALLEL for faster startup.

1. **Initialize session context**:
   - Get session directory from SessionStart hook output (`.claude-harness/sessions/{session-id}/`)
   - Get cached GitHub owner/repo from SessionStart hook output (`github.owner`, `github.repo`)
   - Clear/initialize session context file: `.claude-harness/sessions/{session-id}/context.json`

2. **Read all memory layers IN PARALLEL** (single message with multiple Read tool calls):
   - `${FEATURES_FILE}` (to identify active feature)
   - `${MEMORY_DIR}/procedural/failures.json`
   - `${MEMORY_DIR}/procedural/successes.json`
   - `${MEMORY_DIR}/episodic/decisions.json`
   - `${MEMORY_DIR}/learned/rules.json`

   **IMPORTANT**: Use parallel tool calls - do NOT read these files sequentially.
   This reduces context compilation time by 30-40%.

3. **Process memory data** (after all reads complete):
   - **Failures to avoid**:
     - If active feature exists, filter entries where `feature` matches or `files` overlap with `relatedFiles`
     - Extract top 5 most recent relevant failures
     - Add to `relevantMemory.avoidApproaches`

   - **Successful approaches**:
     - Filter entries for similar file patterns or feature types
     - Extract top 5 most relevant successes
     - Add to `relevantMemory.projectPatterns`

   - **Recent decisions**:
     - Get entries from last 7 days or last 20 entries (whichever is smaller)
     - Add to `relevantMemory.recentDecisions`

4. **Write compiled context** (to session-scoped path):
   - Update `.claude-harness/sessions/{session-id}/context.json`:
     ```json
     {
       "version": 3,
       "computedAt": "{ISO timestamp}",
       "sessionId": "{unique-id}",
       "github": {
         "owner": "{from SessionStart hook}",
         "repo": "{from SessionStart hook}"
       },
       "activeFeature": "{feature-id or null}",
       "relevantMemory": {
         "recentDecisions": [{...}],
         "projectPatterns": [{...}],
         "avoidApproaches": [{...}]
       },
       "currentTask": {
         "description": "{feature description}",
         "files": ["{relatedFiles}"],
         "acceptanceCriteria": ["{verification}"]
       },
       "compilationLog": ["Loaded N failures", "Loaded N successes", ...]
     }
     ```

6. **Display memory summary**:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  📚 MEMORY CONTEXT COMPILED                                     │
   ├─────────────────────────────────────────────────────────────────┤
   │  Recent decisions: {N} loaded                                   │
   │  Success patterns: {N} loaded                                   │
   │  Approaches to AVOID: {N} loaded                                │
   └─────────────────────────────────────────────────────────────────┘
   ```

   If `avoidApproaches` has entries, display prominently:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  ⚠️  APPROACHES TO AVOID (from past failures)                   │
   ├─────────────────────────────────────────────────────────────────┤
   │  • {failure.approach} - {failure.rootCause}                     │
   │  • {failure.approach} - {failure.rootCause}                     │
   └─────────────────────────────────────────────────────────────────┘
   ```

## Phase 1.6: Load Learned Rules

6.5. **Process learned rules** (already read in parallel in step 2):
   - Use data from `${MEMORY_DIR}/learned/rules.json` (already loaded)
   - If file exists and has active rules (`rules` array with `active: true`):

   - Filter rules for current context:
     - If active feature exists, include rules where:
       - `applicability.always` is true, OR
       - `applicability.features` includes current feature, OR
       - `applicability.filePatterns` overlap with feature's `relatedFiles`
     - If no active feature, include all active rules

   - Add rules to working context:
     - Update `.claude-harness/sessions/{session-id}/context.json`:
       ```json
       {
         "relevantMemory": {
           "recentDecisions": [...],
           "projectPatterns": [...],
           "avoidApproaches": [...],
           "learnedRules": [
             {
               "id": "rule-001",
               "title": "Always use absolute imports",
               "description": "Use @/components/... not relative paths",
               "scope": "coding-style"
             }
           ]
         }
       }
       ```

   - Display learned rules if any exist:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  📚 LEARNED RULES (from your corrections)                       │
     ├─────────────────────────────────────────────────────────────────┤
     │  • {rule.title}                                                 │
     │  • {rule.title}                                                 │
     │  • {rule.title}                                                 │
     ├─────────────────────────────────────────────────────────────────┤
     │  {N} rules active (auto-captured at checkpoint)                 │
     └─────────────────────────────────────────────────────────────────┘
     ```

   - If no learned rules exist yet, skip this section (no output)

## Phase 2: Local Status

7. **Load working context** (if exists):
   - Read `.claude-harness/working-context.json` (legacy) or use compiled context
   - If `activeFeature` is set, display prominently:
     ```
     === Resuming Work ===
     Feature: {activeFeature} - {summary}
     Working files: {list workingFiles with roles}
     Key decisions: {list decisions}
     Next steps: {list nextSteps}
     ```
   - This orients the session before other status info

8. Execute `./.claude-harness/init.sh` to see environment status (if it exists)

9. Read `.claude-harness/claude-progress.json` for session context

10. Read `${FEATURES_FILE}` to identify next priority
   - If the file is too large to read (>25000 tokens), use: `grep -A 5 "passes.*false" ${FEATURES_FILE}` to see pending features
   - Run `/claude-harness:checkpoint` to auto-archive completed features and reduce file size

11. Optionally check `${ARCHIVE_FILE}` to see completed feature count/history

## Phase 3: Loop & Orchestration State

12. **Check active loop state** (PRIORITY):
   - **Check for interrupt recovery** (v6.3.0 — highest priority):
     - Read `.claude-harness/sessions/.recovery/interrupted.json`
     - If marker file exists:
       ```
       ┌─────────────────────────────────────────────────────────────────┐
       │  INTERRUPTED SESSION DETECTED                                  │
       ├─────────────────────────────────────────────────────────────────┤
       │  Feature: {feature}                                            │
       │  TDD Phase: {tddPhase}                                        │
       │  Attempt: {attemptAtInterrupt}/{maxAttempts}                   │
       │  Stale Team: {staleTeamName} (dead — will create new)         │
       │                                                                │
       │  Resume: /claude-harness:flow {feature}                        │
       │  (Recovery options will be presented on resume)                │
       └─────────────────────────────────────────────────────────────────┘
       ```
   - Read session-scoped loop state: `.claude-harness/sessions/{session-id}/loop-state.json`
   - If session file doesn't exist, check legacy paths: `.claude-harness/loops/state.json` or `.claude-harness/loop-state.json`
   - Check `type` field to determine if this is a feature or fix
   - If `status` is "in_progress" and `type` is "feature":
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  🔄 ACTIVE AGENTIC LOOP                                        │
     ├─────────────────────────────────────────────────────────────────┤
     │  Feature: {feature}                                            │
     │  Attempt: {attempt}/{maxAttempts}                              │
     │  Last approach: {history[-1].approach}                         │
     │  Last result: {history[-1].result}                             │
     │                                                                │
     │  Resume: /claude-harness:flow {feature}                         │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - If `status` is "in_progress" and `type` is "fix":
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  🔧 ACTIVE FIX                                                 │
     ├─────────────────────────────────────────────────────────────────┤
     │  Fix: {feature}                                                │
     │  Linked to: {linkedTo.featureName} ({linkedTo.featureId})      │
     │  Attempt: {attempt}/{maxAttempts}                              │
     │  Last approach: {history[-1].approach}                         │
     │  Last result: {history[-1].result}                             │
     │                                                                │
     │  Resume: /claude-harness:flow {feature}                         │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - If `status` is "escalated":
     - Show escalation reason and history summary
     - Recommend: increase maxAttempts or provide guidance

12b. **Check pending fixes**:
   - Read `${FEATURES_FILE}`   - Check `fixes` array for entries with `status` != "passing"
   - If pending fixes exist:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  📋 PENDING FIXES                                              │
     ├─────────────────────────────────────────────────────────────────┤
     │  {fix-id}: {name}                                              │
     │    Linked to: {linkedTo.featureName}                           │
     │    Status: {status}                                            │
     │  ...                                                           │
     └─────────────────────────────────────────────────────────────────┘
     ```

13. Check orchestration state:
   - Read `.claude-harness/agents/context.json` (or legacy `agent-context.json`) if it exists
   - Check for `currentSession.activeFeature` - indicates incomplete orchestration
   - Check `agentResults` for recently completed agent work
   - If active orchestration exists, recommend: "Run `/claude-harness:flow {feature-id}` to resume"

14. Check procedural memory hotspots:
   - Read `${MEMORY_DIR}/procedural/patterns.json` if it exists   - Report any `codebaseInsights.hotspots` that may affect current work
   - Show success/failure rates if significant history exists

## Phase 4: GitHub Integration (if MCP configured)

15. Check GitHub MCP connection status

16. **Get GitHub owner/repo** (use cached from SessionStart):
    - Use cached `github.owner` and `github.repo` from SessionStart hook output
    - These values were parsed once at session start and cached for the entire session
    - If not available (older hook version), fall back to parsing:
      ```bash
      REMOTE_URL=$(git remote get-url origin 2>/dev/null)
      # Parse SSH or HTTPS format
      ```

    **OPTIMIZATION**: SessionStart hook now parses and caches GitHub repo info.
    All commands in this session can reuse these values without re-parsing.

17. Fetch and display GitHub dashboard (using OWNER and REPO):
   - Open issues with "feature" label
   - Open PRs from feature branches
   - CI/CD status for open PRs
   - Cross-reference with `${FEATURES_FILE}`

18. Sync GitHub Issues with `${FEATURES_FILE}`:
   - For each GitHub issue with "feature" label NOT in active.json:
     - Add new entry with issueNumber linked
   - For each feature in active.json with status="passing" or passes=true:
     - If linked GitHub issue is still open, close it
   - Report sync results

## Phase 5: Recommendations

19. Report session summary:
    - Current state and blockers
    - Pending features and fixes prioritized
    - GitHub sync results
    - Recommended next action (in priority order):
      1. **Active loop (fix)**: Resume with `/claude-harness:flow {fix-id}`
      2. **Active loop (feature)**: Resume with `/claude-harness:flow {feature-id}`
      3. **Escalated loop**: Review history and provide guidance, or increase maxAttempts
      4. **Pending fixes**: Resume fix with `/claude-harness:flow {fix-id}`
      5. **No features (new project)**: Bootstrap with `/claude-harness:prd-breakdown @./prd.md` to analyze PRD and extract features
      7. **Pending features**: Start implementation with `/claude-harness:flow {feature-id}`
      8. **No features (existing project)**: Add one with `/claude-harness:flow "description"`
      9. **Create fix for completed feature**: `/claude-harness:flow --fix {feature-id} "bug description"`
