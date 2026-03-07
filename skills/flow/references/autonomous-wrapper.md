# Autonomous Wrapper - Detailed Phases

When `--autonomous` is set, the flow operates as a lean orchestrator loop that iterates all active features. Each feature runs in an isolated subagent context via the Task tool.

## Phase A.1: Initialize Autonomous State

1. **Read feature backlog**:
   - Set paths: `FEATURES_FILE=".claude-harness/features/active.json"`, `ARCHIVE_FILE=".claude-harness/features/archive.json"`, `MEMORY_DIR=".claude-harness/memory/"`
   - Read and filter features where status is NOT `"passing"`
   - If none eligible: display "No pending features" and **EXIT**

2. **Check for resume** (if `autonomous-state.json` exists):
   - Check `.claude-harness/sessions/.recovery/interrupted.json` for interrupt recovery
   - If marker exists and matches current feature: record interrupted attempt in history, increment counter
   - Read preserved state from `.recovery/` if needed, delete markers after processing
   - Read `.claude-harness/sessions/{session-id}/autonomous-state.json`
   - If exists: display resume summary, proceed
   - If not exists: create fresh state (next step)

3. **Create autonomous state file** at `.claude-harness/sessions/{session-id}/autonomous-state.json`:
   ```json
   {
     "version": 4,
     "mode": "autonomous",
     "startedAt": "{ISO timestamp}",
     "iteration": 0, "maxIterations": 20,
     "consecutiveFailures": 0, "maxConsecutiveFailures": 3,
     "completedFeatures": [], "skippedFeatures": [], "failedFeatures": [],
     "currentFeature": null,
     "contextIsolation": { "enabled": true, "subagentType": "general-purpose" },
     "featureResults": []
   }
   ```

4. **Parse and cache GitHub repo** (reuse across iterations):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   ```

5. **Read all memory layers IN PARALLEL**: failures.json, successes.json, decisions.json, rules.json

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

**Assemble all context the subagent needs** (effort: low -- mechanical data assembly):

Read and compile from cached memory (loaded in A.1):
- **Feature entry**: full object from active.json (id, name, description, acceptanceCriteria, relatedFiles, verification, github refs)
- **Verification commands**: from `.claude-harness/config.json` verification section
- **Relevant failures**: max 5 from `failures.json`, filtered by feature's relatedFiles overlap
- **Success patterns**: max 5 from `successes.json`, filtered for similar file patterns
- **Recent decisions**: max 10 from `decisions.json`
- **Learned rules**: all active rules from `rules.json` applicable to this feature (max 5)
- **GitHub info**: owner/repo from A.1 cache
- **Loop history**: previous attempts for this specific feature
- **Flag states**: `--team` (boolean), `--quick` (boolean), `--no-merge` (boolean)
- **Team config**: `agentTeams` section from config.json (if `--team`)

**Format structured subagent prompt** (target: under 3,000 tokens):

```
You are executing feature {feature-id}: {featureName} as part of an autonomous batch.
Run the full feature lifecycle (Phases 1-7) and return a structured result.

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

## Previous Attempts (if any)
{loop history from previous attempts of this feature}

## Instructions
1. Checkout the feature branch: git checkout {branch}
2. Plan the implementation {unless --quick: "(skip planning -- --quick mode)"}
3. Follow ATDD: write acceptance tests first from the Gherkin acceptance criteria (RED), then implement to pass all tests (GREEN), then refactor.
4. {if --team: "Create an Agent Team (tester, implementer, reviewer). Execute Mandatory Team Shutdown Gate before checkpoint."}
5. {if NOT --team: "Implement directly -- but still follow ATDD order: acceptance tests first, then implementation."}
6. Run ALL verification commands after implementation
7. On pass: stage ALL modified files including `.claude-harness/` state files (`git add .claude-harness/ && git add -A`), then commit as `feat({feature-id}): {description}`, push, create/update PR with `Closes #{issueNumber}`
8. On fail: retry with escalation (attempts 1-5: high effort, 6-10: max, 11-15: max + full memory). Max 15 attempts.
9. {if NOT --no-merge: "Merge PR (squash), close issue, delete branch, update feature status to 'passing', then archive"}
10. {if --no-merge: "Stop at checkpoint. Do not merge."}

## Return Format
End your response with this exact structured block:

RESULT:
status: completed | failed | escalated | needs_review
commitHash: {hash or null}
prNumber: {number or null}
attempts: {number}
featureStatus: passing | failed | needs_review | escalated
memoryUpdates:
  decisions: [{decision, rationale, impact}]
  failures: [{approach, errors, rootCause}]
  successes: [{approach, files, patterns}]
  patterns: [{pattern, source}]
summary: {one-line summary of what was done}
```

---

## Phase A.4: Execute Feature Flow (Subagent Delegation)

1. **Delegate feature to isolated subagent** (effort: low -- mechanical delegation):
   - Use Task tool with `subagent_type="general-purpose"`
   - Pass the compiled prompt from Phase A.4.0
   - The subagent runs the full standard flow (Phases 1-7) autonomously
   - Wait for subagent completion
   - Parse the RESULT block from the subagent's return message

2. **Handle subagent return parsing**:
   - Search for `RESULT:` prefix in the subagent's response
   - Parse key-value pairs (status, commitHash, prNumber, attempts, featureStatus, memoryUpdates, summary)
   - If RESULT block not found: treat as `needs_review`, check external state:
     - `git log --oneline -1` on feature branch for commit evidence
     - `gh pr list --head {branch}` for PR evidence
     - Log warning: "Subagent did not return structured result -- checking external state"

---

## Phase A.5: Post-Feature Processing

1. **Safety-net team cleanup check** (if `--team`):
   - Read `.claude-harness/agents/context.json`
   - If `teamState` is non-null: team cleanup failed inside subagent
     - Attempt cleanup: send shutdown requests, wait, clean up team resources
     - Check for orphaned tmux sessions: `tmux ls 2>/dev/null | grep "{teamName}"` -- kill if found
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

   **If `failed` or `escalated`**:
   - Add to `failedFeatures` with reason and attempt count
   - Increment `consecutiveFailures`

   **If `needs_review`**:
   - Add to `skippedFeatures` with reason `"needs_review"`
   - Do NOT increment `consecutiveFailures`

3. **Persist memory updates from subagent** (critical for cross-feature learning):
   - For each decision: append to `${MEMORY_DIR}/episodic/decisions.json` (enforce maxEntries 50, FIFO)
   - For each failure: append to `${MEMORY_DIR}/procedural/failures.json`
   - For each success: append to `${MEMORY_DIR}/procedural/successes.json`
   - For each pattern: merge into `${MEMORY_DIR}/procedural/patterns.json` (deduplicate)

4. **Record feature result** in autonomous-state `featureResults` array:
   ```json
   {
     "featureId": "{feature-id}",
     "status": "{from RESULT}",
     "attempts": "{from RESULT}",
     "commitHash": "{from RESULT}",
     "prNumber": "{from RESULT}",
     "duration": "{elapsed time}",
     "memoryUpdatesCount": "{total items persisted}"
   }
   ```

5. **Update autonomous state**: write updated state file with incremented iteration, updated feature lists.

6. **Switch to main and clean up branches**:
   - `git checkout main && git pull origin main`
   - If feature status is `completed` (merged): `git branch -d feature/{feature-id}` (safe delete)
   - `git fetch --prune`

7. **Reset session state**: Clear loop-state.json, clear task references, clear working-context.json.

8. **Commit harness state updates to main** (CRITICAL — orchestrator changes must be persisted):
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
