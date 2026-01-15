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

3. If `.claude-harness/` already exists, skip migration (assume already migrated)

4. **Create missing state files** (for plugin updates):
   - Check if each required state file exists, create with defaults if missing:
   - `.claude-harness/loop-state.json` (if missing):
     ```json
     {
       "version": 1,
       "feature": null,
       "status": "idle",
       "attempt": 0,
       "maxAttempts": 10,
       "verification": {},
       "history": []
     }
     ```
   - `.claude-harness/working-context.json` (if missing):
     ```json
     {
       "version": 1,
       "activeFeature": null,
       "summary": null,
       "workingFiles": {},
       "decisions": [],
       "nextSteps": []
     }
     ```
   - Report: "Created missing state file: {filename}"

## Phase 1: Context Compilation (Memory System)

1. **Compile working context from memory layers**:
   - Clear/initialize `.claude-harness/memory/working/context.json`
   - Read `.claude-harness/features/active.json` (or legacy `feature-list.json`) to identify active feature

2. **Query procedural memory for failures to avoid**:
   - Read `.claude-harness/memory/procedural/failures.json`
   - If active feature exists, filter entries where `feature` matches or `files` overlap with `relatedFiles`
   - Extract top 5 most recent relevant failures
   - Add to `relevantMemory.avoidApproaches` in working context

3. **Query procedural memory for successful approaches**:
   - Read `.claude-harness/memory/procedural/successes.json`
   - Filter entries for similar file patterns or feature types
   - Extract top 5 most relevant successes
   - Add to `relevantMemory.projectPatterns` in working context

4. **Query episodic memory for recent decisions**:
   - Read `.claude-harness/memory/episodic/decisions.json`
   - Get entries from last 7 days or last 20 entries (whichever is smaller)
   - Add to `relevantMemory.recentDecisions` in working context

5. **Write compiled context**:
   - Update `.claude-harness/memory/working/context.json`:
     ```json
     {
       "version": 3,
       "computedAt": "{ISO timestamp}",
       "sessionId": "{unique-id}",
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

6.5. **Load and display learned rules from user corrections**:
   - Read `.claude-harness/memory/learned/rules.json`
   - If file exists and has active rules (`rules` array with `active: true`):

   - Filter rules for current context:
     - If active feature exists, include rules where:
       - `applicability.always` is true, OR
       - `applicability.features` includes current feature, OR
       - `applicability.filePatterns` overlap with feature's `relatedFiles`
     - If no active feature, include all active rules

   - Add rules to working context:
     - Update `.claude-harness/memory/working/context.json`:
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

10. Read `.claude-harness/features/active.json` (or legacy `feature-list.json`) to identify next priority
   - If the file is too large to read (>25000 tokens), use: `grep -A 5 "passes.*false" .claude-harness/features/active.json` to see pending features
   - Run `/claude-harness:checkpoint` to auto-archive completed features and reduce file size

11. Optionally check `.claude-harness/features/archive.json` (or legacy `feature-archive.json`) to see completed feature count/history

## Phase 3: Loop & Orchestration State

12. **Check active loop state** (PRIORITY):
   - Read `.claude-harness/loops/state.json` (or legacy `.claude-harness/loop-state.json`)
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
     │  Resume: /claude-harness:do {feature}                          │
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
     │  Resume: /claude-harness:do {feature}                          │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - If `status` is "escalated":
     - Show escalation reason and history summary
     - Recommend: increase maxAttempts or provide guidance

12b. **Check pending fixes**:
   - Read `.claude-harness/features/active.json`
   - Check `fixes` array for entries with `status` != "passing"
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
   - Check `pendingHandoffs` array for work waiting to be continued
   - Check `agentResults` for recently completed agent work
   - If active orchestration exists, recommend: "Run `/claude-harness:orchestrate {feature-id}` to resume"

14. Check procedural memory hotspots:
   - Read `.claude-harness/memory/procedural/patterns.json` if it exists
   - Report any `codebaseInsights.hotspots` that may affect current work
   - Show success/failure rates if significant history exists

## Phase 4: GitHub Integration (if MCP configured)

15. Check GitHub MCP connection status

16. **Parse repository owner and name from git remote** (MANDATORY before any GitHub API calls):
    ```bash
    # Get the remote URL
    REMOTE_URL=$(git remote get-url origin 2>/dev/null)

    # Parse owner and repo from URL (handles both SSH and HTTPS formats)
    # SSH format: git@github.com:owner/repo.git
    # HTTPS format: https://github.com/owner/repo.git

    if [[ "$REMOTE_URL" =~ git@github.com:([^/]+)/([^.]+) ]]; then
      OWNER="${BASH_REMATCH[1]}"
      REPO="${BASH_REMATCH[2]}"
    elif [[ "$REMOTE_URL" =~ github.com/([^/]+)/([^/.]+) ]]; then
      OWNER="${BASH_REMATCH[1]}"
      REPO="${BASH_REMATCH[2]}"
    fi
    ```

    **CRITICAL**: Always run `git remote get-url origin` and parse the actual URL.
    NEVER guess, cache, or reuse owner/repo from previous sessions or other projects.
    The URL parsing must happen fresh for every GitHub API call in the current working directory.

17. Fetch and display GitHub dashboard (using parsed OWNER and REPO):
   - Open issues with "feature" label
   - Open PRs from feature branches
   - CI/CD status for open PRs
   - Cross-reference with .claude-harness/features/active.json

18. Sync GitHub Issues with .claude-harness/features/active.json:
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
      1. **Active loop (fix)**: Resume with `/claude-harness:do {fix-id}`
      2. **Active loop (feature)**: Resume with `/claude-harness:do {feature-id}`
      3. **Escalated loop**: Review history and provide guidance, or increase maxAttempts
      4. **Pending fixes**: Resume fix with `/claude-harness:do {fix-id}`
      5. **Pending handoffs**: Resume orchestration with `/claude-harness:orchestrate {feature-id}`
      6. **Pending features**: Start implementation:
         - Simple feature: `/claude-harness:do {feature-id}`
         - Complex feature: `/claude-harness:orchestrate {feature-id}`
      7. **No features**: Add one with `/claude-harness:do "description"`
      8. **Create fix for completed feature**: `/claude-harness:do --fix {feature-id} "bug description"`
