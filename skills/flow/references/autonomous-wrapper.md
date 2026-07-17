# Autonomous Wrapper - Detailed Phases

When `--autonomous` is set, the flow operates as a lean orchestrator loop that iterates all active features. Each feature runs in an isolated subagent context via the Agent tool (`subagent_type="claude-harness:harness-implementer"`).

**Unattended runs**: start the session with `claude --permission-mode acceptEdits` (or an equivalent settings profile) so routine edits don't prompt; the harness PermissionRequest hook still auto-denies destructive operations.

## Phase A.1: Initialize Autonomous State

1. **Read feature backlog**:
   - Set paths: `FEATURES_FILE=".claude-harness/features/active.json"`, `ARCHIVE_FILE=".claude-harness/features/archive.json"`, `MEMORY_DIR=".claude-harness/memory/"`
   - Read and filter features where status is NOT `"passing"`
   - If none eligible: display "No pending features" and **EXIT**

2. **Check for resume** (if `autonomous-state.json` exists):
   - Check `.claude-harness/sessions/.recovery/interrupted.json` for interrupt recovery
   - If marker exists and matches current feature: record interrupted attempt in history, increment counter
   - Read preserved state from `.recovery/` if needed, delete markers after processing
   - Read `.claude-harness/sessions/${CLAUDE_SESSION_ID}/autonomous-state.json`
   - If exists: display resume summary, proceed
   - If not exists: create fresh state (next step)

3. **Create autonomous state file** at `.claude-harness/sessions/${CLAUDE_SESSION_ID}/autonomous-state.json`:
   ```json
   {
     "version": 4,
     "mode": "autonomous",
     "startedAt": "{ISO timestamp}",
     "iteration": 0, "maxIterations": 20,
     "consecutiveFailures": 0, "maxConsecutiveFailures": 3,
     "completedFeatures": [], "skippedFeatures": [], "failedFeatures": [],
     "currentFeature": null,
     "contextIsolation": { "enabled": true, "subagentType": "claude-harness:harness-implementer" },
     "featureResults": []
   }
   ```

4. **GitHub repo**: use the cached owner/repo from the session context (injected at SessionStart); parse from `git remote get-url origin` only if absent.

5. **Read all memory layers IN PARALLEL**: the bundle index files `${MEMORY_DIR}/failures/index.md`, `${MEMORY_DIR}/successes/index.md`, `${MEMORY_DIR}/decisions/index.md`, `${MEMORY_DIR}/rules/index.md` (then only the relevant concept files)

6. **Display autonomous banner** showing: feature count, max iterations, merge/planning mode, GitHub info, memory stats, context isolation status.

---

## Phase A.2: Feature Selection (LOOP START)

1. **Re-read feature backlog**: Read `${FEATURES_FILE}`, filter eligible features (not passing/skipped/failed). If none remain: proceed to Phase A.7.

2. **Select next feature**: lowest ID (deterministic ordering). Update `currentFeature` and increment `iteration`.

3. **Read full feature entry** from active.json (entire object including acceptanceCriteria, relatedFiles, verification, github refs). Store for A.4.0 prompt compilation.

4. **Display iteration header**: iteration count, feature info, progress.

---

## Phase A.3: Conflict Detection

1. Switch to main and pull: `git checkout main && git pull origin main`
2. Checkout feature branch and rebase onto main.
3. **Handle rebase result**:
   - Success: proceed to A.4.0
   - Conflict: `git rebase --abort`, add to `skippedFeatures` with reason, go back to A.2

---

## Phase A.4.0: Compile Subagent Prompt

The lifecycle instructions live in the `claude-harness:harness-implementer` agent definition -- the prompt only carries **data**. Compile from cached memory (loaded in A.1):

- **Feature entry**: full object from active.json (id, name, description, acceptanceCriteria, relatedFiles, verification, github refs)
- **Verification commands**: from `.claude-harness/config.json` verification section
- **Relevant failures**: max 5 concepts from `${MEMORY_DIR}/failures/`, filtered by feature's relatedFiles overlap
- **Success patterns**: max 5 concepts from `${MEMORY_DIR}/successes/`, filtered for similar file patterns
- **Recent decisions**: max 10 concepts from `${MEMORY_DIR}/decisions/`
- **Learned rules**: all active Rule concepts from `${MEMORY_DIR}/rules/` applicable to this feature (max 5)
- **GitHub info**: owner/repo from A.1 cache
- **Previous delegations**: failure summaries from earlier delegations of THIS feature (if any)
- **Flag states**: `--team` (boolean), `--quick` (boolean), `--no-merge` (boolean)
- **Team config**: `agentTeams` section from config.json (if `--team`)
- **Result file**: `.claude-harness/sessions/${CLAUDE_SESSION_ID}/result-{feature-id}.json`

**Format structured subagent prompt** (target: under 2,000 tokens):

```
Implement feature {feature-id}: {featureName} as part of an autonomous batch.

## Feature
{feature JSON entry -- id, name, description, acceptanceCriteria, relatedFiles}

## GitHub
Owner: {owner} | Repo: {repo}
Issue: #{issueNumber} | Branch: {branch}

## Verification Commands
build: {build} | tests: {tests} | lint: {lint} | typecheck: {typecheck} | acceptance: {acceptance}

## Memory: Approaches to AVOID
{for each relevant failure: "- {approach} -> {rootCause}"}

## Memory: Success Patterns
{for each relevant success: "- {approach} ({feature})"}

## Memory: Learned Rules
{for each applicable rule: "- {title}: {description}"}

## Recent Decisions
{for each decision: "- {decision} ({feature})"}

## Previous Delegations (if any)
{failure/escalation summaries from earlier delegations of this feature}

## Flags
quick: {true|false} | team: {true|false} | no-merge: {true|false}
{if --team: team config JSON}

## Result File
Write your result JSON to: {resultFile}
```

**Fallback**: if the `claude-harness:harness-implementer` agent type is unavailable, delegate to `general-purpose` and append the lifecycle instructions from the agent definition (`agents/harness-implementer.md` body).

---

## Phase A.4: Execute Feature Flow (Subagent Delegation)

1. **Delegate feature to isolated subagent**:
   - Use the Agent tool with `subagent_type="claude-harness:harness-implementer"`
   - Pass the compiled prompt from Phase A.4.0
   - The subagent runs the full feature lifecycle autonomously (max 4 implementation attempts)
   - Wait for subagent completion

2. **Collect the result**:
   - Read the result file (`{resultFile}` from the prompt)
   - If missing: parse the `RESULT:` line from the subagent's reply
   - If neither exists: treat as `needs_review`, check external state:
     - `git log --oneline -1` on feature branch for commit evidence
     - `gh pr list --head {branch}` for PR evidence
     - Log warning: "Subagent did not return a structured result -- checking external state"

3. **Re-delegation on escalation**: if status is `escalated` or `failed` and this feature has used fewer than 3 delegations:
   - Persist the failure entries to procedural memory FIRST (they seed the next prompt)
   - Recompile the prompt with the escalation summary under `## Previous Delegations`
   - Delegate a fresh subagent (back to step 1). Do NOT count this as a completed iteration.

---

## Phase A.5: Post-Feature Processing

1. **Safety-net team cleanup check** (if `--team`):
   - Read `.claude-harness/agents/context.json`
   - If `teamState` is non-null: team cleanup failed inside subagent
     - Attempt cleanup: send shutdown requests, wait, clean up team resources
     - Check for orphaned legacy tmux sessions: `tmux ls 2>/dev/null | grep "{teamName}"` -- kill if found
     - If cleanup still fails: mark feature as `needs_review`, add to `skippedFeatures`, jump to A.6
   - Set `teamState` to null, write updated file

2. **Process subagent result** based on parsed status:

   **If `completed`**:
   - **Archive feature** (CRITICAL):
     1. Read `${FEATURES_FILE}`
     2. Find the completed feature entry by ID
     3. Read `${ARCHIVE_FILE}` (create with `{"version":3,"archived":[],"archivedFixes":[]}` if missing)
     4. Add `"archivedAt": "{ISO timestamp}"` and set `"status": "passing"`
     5. Append to `archived[]` in archive.json
     6. Remove from `features[]` in active.json
     7. Write BOTH files (`${ARCHIVE_FILE}` first, then `${FEATURES_FILE}`)
     8. **Verify**: Re-read `${FEATURES_FILE}` and confirm feature ID removed
   - Add feature ID to `completedFeatures`
   - Reset `consecutiveFailures` to 0

   **If `failed` or `escalated`** (delegation budget exhausted):
   - Add to `failedFeatures` with reason and attempt count
   - Increment `consecutiveFailures`

   **If `needs_review`**:
   - Add to `skippedFeatures` with reason `"needs_review"`
   - Do NOT increment `consecutiveFailures`

3. **Persist memory updates from the result** (critical for cross-feature learning; write OKF concept files per `schemas/okf-memory.md` and list each in its directory's `index.md`):
   - For each decision: write `${MEMORY_DIR}/decisions/dec-{NNN}-{slug}.md` (`type: Decision`; enforce 50-concept rolling window, delete oldest FIFO)
   - For each failure: write `${MEMORY_DIR}/failures/fail-{NNN}-{slug}.md` (`type: Failure`)
   - For each success: write `${MEMORY_DIR}/successes/suc-{NNN}-{slug}.md` (`type: Success`)
   - For each pattern: write `${MEMORY_DIR}/patterns/pat-{NNN}-{slug}.md` (`type: Pattern`; skip if an equivalent concept already exists)

4. **Record feature result** in autonomous-state `featureResults` array:
   ```json
   {
     "featureId": "{feature-id}",
     "status": "{from result}",
     "attempts": "{from result}",
     "delegations": "{count}",
     "commitHash": "{from result}",
     "prNumber": "{from result}",
     "duration": "{elapsed time}",
     "memoryUpdatesCount": "{total items persisted}"
   }
   ```

5. **Update autonomous state**: write updated state file with incremented iteration, updated feature lists. Delete the feature's result file.

6. **Switch to main and clean up branches**:
   - `git checkout main && git pull origin main`
   - If feature status is `completed` (merged): `git branch -d feature/{feature-id}` (safe delete)
   - `git fetch --prune`

7. **Reset session state**: Clear loop-state.json, clear task references.

8. **Commit harness state updates to main** (CRITICAL -- orchestrator changes must be persisted):
   - `git add .claude-harness/ && git status --porcelain .claude-harness/`
   - If there are staged changes: `git commit -m "chore: update harness state after {feature-id}" && git push origin main`
   - This captures: archived features, memory persistence, session briefing, progress updates
   - Must happen BEFORE the next feature iteration to keep state consistent

9. **Brief per-feature report**: feature ID, status, attempts, commit hash, PR number, duration, memory updates count, progress (N/M features complete).

---

## Phase A.6: Loop Continuation Check

**Check termination conditions** (in order):
1. No eligible features remaining -> Phase A.7
2. `iteration` reached `maxIterations` (20) -> Phase A.7
3. `consecutiveFailures` reached `maxConsecutiveFailures` (3) -> Phase A.7
4. All remaining features skipped/failed -> Phase A.7

**If continuing**: write state, go back to A.2.

---

## Phase A.7: Autonomous Completion Report

1. **Generate final report**: duration, iterations, completed/skipped/failed features with details, per-feature results summary, total memory updates.

2. **Final cleanup**: ensure on main, clear autonomous state, clean up task references.
