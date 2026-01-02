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

## Phase 1: Local Status

1. **Load working context** (if exists):
   - Read `.claude-harness/working-context.json`
   - If `activeFeature` is set, display prominently:
     ```
     === Resuming Work ===
     Feature: {activeFeature} - {summary}
     Working files: {list workingFiles with roles}
     Key decisions: {list decisions}
     Next steps: {list nextSteps}
     ```
   - This orients the session before other status info

2. Execute `./.claude-harness/init.sh` to see environment status (if it exists)

3. Read `.claude-harness/claude-progress.json` for session context

4. Read `.claude-harness/feature-list.json` to identify next priority
   - If the file is too large to read (>25000 tokens), use: `grep -A 5 "passes.*false" .claude-harness/feature-list.json` to see pending features
   - Run `/claude-harness:checkpoint` to auto-archive completed features and reduce file size

5. Optionally check `.claude-harness/feature-archive.json` to see completed feature count/history

## Phase 2: Loop & Orchestration State

6. **Check active loop state** (PRIORITY):
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
     │  Resume: /claude-harness:implement {feature}                   │
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
     │  Resume: /claude-harness:implement {feature}                   │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - If `status` is "escalated":
     - Show escalation reason and history summary
     - Recommend: increase maxAttempts or provide guidance

6b. **Check pending fixes**:
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

7. Check orchestration state:
   - Read `.claude-harness/agent-context.json` if it exists
   - Check for `currentSession.activeFeature` - indicates incomplete orchestration
   - Check `pendingHandoffs` array for work waiting to be continued
   - Check `agentResults` for recently completed agent work
   - If active orchestration exists, recommend: "Run `/claude-harness:orchestrate {feature-id}` to resume"

7. Check agent memory:
   - Read `.claude-harness/agent-memory.json` if it exists
   - Report any `codebaseInsights.hotspots` that may affect current work
   - Show `agentPerformance` summary if significant history exists

## Phase 3: GitHub Integration (if MCP configured)

8. Check GitHub MCP connection status

9. Fetch and display GitHub dashboard:
   - Open issues with "feature" label
   - Open PRs from feature branches
   - CI/CD status for open PRs
   - Cross-reference with .claude-harness/feature-list.json

10. Sync GitHub Issues with .claude-harness/feature-list.json:
   - For each GitHub issue with "feature" label NOT in .claude-harness/feature-list.json:
     - Add new entry with issueNumber linked
   - For each feature in .claude-harness/feature-list.json with passes=true:
     - If linked GitHub issue is still open, close it
   - Report sync results

## Phase 4: Recommendations

12. Report session summary:
    - Current state and blockers
    - Pending features and fixes prioritized
    - GitHub sync results
    - Recommended next action (in priority order):
      1. **Active loop (fix)**: Resume with `/claude-harness:implement {fix-id}`
      2. **Active loop (feature)**: Resume with `/claude-harness:implement {feature-id}`
      3. **Escalated loop**: Review history and provide guidance, or increase maxAttempts
      4. **Pending fixes**: Resume fix with `/claude-harness:implement {fix-id}`
      5. **Pending handoffs**: Resume orchestration with `/claude-harness:orchestrate {feature-id}`
      6. **Pending features**: Start implementation:
         - Simple feature: `/claude-harness:implement {feature-id}`
         - Complex feature: `/claude-harness:orchestrate {feature-id}`
      7. **No features**: Add one with `/claude-harness:feature <description>`
      8. **Create fix for completed feature**: `/claude-harness:fix {feature-id} "bug description"`
