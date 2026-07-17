# Implementation - Detailed Phases

Covers Phase 2.5 (Context Isolation / Subagent Delegation), Phase 4 (Implementation), and Phase 4.1 (Verification).

## Phase 2.5: Context Isolation (Standard Mode)

**Skip this phase** if `--plan-only` or `--autonomous`. Autonomous mode has its own delegation loop (Phase A.4). Plan-only mode needs inline execution for interactive plan review.

After feature creation completes (feature entry exists in active.json with GitHub issue, branch, and acceptance criteria), delegate the remaining lifecycle to an isolated subagent for clean context.

### 2.5.1: Compile Subagent Prompt

The lifecycle instructions live in the `claude-harness:harness-implementer` agent definition -- the prompt only needs to carry **data**:

Read and compile from Phase 1 context (already loaded):
- **Feature entry**: full object from active.json (id, name, description, acceptanceCriteria, relatedFiles, verification, github refs)
- **Verification commands**: from `.claude-harness/config.json` verification section
- **Relevant failures**: max 5 concepts from `${MEMORY_DIR}/failures/`, filtered by feature's relatedFiles overlap
- **Success patterns**: max 5 concepts from `${MEMORY_DIR}/successes/`, filtered for similar file patterns
- **Recent decisions**: max 10 concepts from `${MEMORY_DIR}/decisions/`
- **Learned rules**: max 5 active Rule concepts from `${MEMORY_DIR}/rules/` applicable to this feature
- (Memory layers are OKF concept files -- read each directory's `index.md` first, then only the relevant concept files)
- **GitHub info**: owner/repo from Phase 1 cache
- **Flag states**: `--team` (boolean), `--quick` (boolean), `--no-merge` (boolean)
- **Team config**: `agentTeams` section from config.json (if `--team`)
- **Result file**: `.claude-harness/sessions/${CLAUDE_SESSION_ID}/result-{feature-id}.json`

**Format structured subagent prompt** (target: under 2,000 tokens):

```
Implement feature {feature-id}: {featureName}.

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

## Flags
quick: {true|false} | team: {true|false} | no-merge: {true|false}
{if --team: team config JSON}

## Result File
Write your result JSON to: {resultFile}
```

**Fallback**: if the `claude-harness:harness-implementer` agent type is unavailable (plugin agents disabled), delegate to `general-purpose` instead and append the lifecycle instructions from the agent definition (`agents/harness-implementer.md` body) to the prompt.

### 2.5.2: Delegate to Subagent

- Use the Agent tool with `subagent_type="claude-harness:harness-implementer"`
- Pass the compiled prompt from 2.5.1
- The subagent executes in its **own fresh context window** (complete isolation), runs Phases 3-6 autonomously, and is capped at **4 implementation attempts**
- Wait for subagent completion

### 2.5.3: Process Subagent Result

**Read the result file** (`{resultFile}` from the prompt). If missing, parse the `RESULT:` line from the subagent's reply. If neither exists: treat as `needs_review` and check external state:
- `git log --oneline -1` on feature branch for commit evidence
- `gh pr list --head {branch}` for PR evidence
- Log warning: "Subagent did not return a structured result -- checking external state"

**Process result based on status**:

**If `completed`**:
- **Persist memory updates** from the result (write OKF concept files per `schemas/okf-memory.md`, and list each new concept in its directory's `index.md`):
  - For each decision: write `${MEMORY_DIR}/decisions/dec-{NNN}-{slug}.md` (`type: Decision`; enforce 50-concept rolling window, delete oldest FIFO)
  - For each failure: write `${MEMORY_DIR}/failures/fail-{NNN}-{slug}.md` (`type: Failure`)
  - For each success: write `${MEMORY_DIR}/successes/suc-{NNN}-{slug}.md` (`type: Success`)
- **Archive feature**:
  1. Read `${FEATURES_FILE}` and `${ARCHIVE_FILE}` (create archive if missing)
  2. Add `"archivedAt"` timestamp, set `"status": "passing"` on the feature
  3. Append to `archived[]` in archive.json, remove from `features[]` in active.json
  4. Write BOTH files (archive first, then active)
  5. Verify: re-read active.json and confirm feature ID removed
- **Switch to main and clean up**:
  - `git checkout main && git pull origin main`
  - `git branch -d feature/{feature-id}` (safe delete)
  - `git fetch --prune`
- **Clear session state**: clear loop-state.json and the result file
- **Regenerate session briefing**: write `.claude-harness/session-briefing.md` if subagent didn't
- **Commit harness state updates to main** (CRITICAL -- orchestrator changes must be persisted):
  - `git add .claude-harness/ && git status --porcelain .claude-harness/`
  - If there are staged changes: `git commit -m "chore: update harness state (memory, features, briefing)" && git push origin main`
  - This captures: archived features, memory persistence, session briefing, progress updates

**If `escalated` or `failed`**:
- Persist memory updates (failures) from the result -- this is the distilled knowledge the next attempt needs
- **Re-delegate with a fresh subagent** if fewer than 3 delegations have been used for this feature:
  - Recompile the prompt (2.5.1) including the new failure entries under "Approaches to AVOID" and the escalation summary under a `## Previous Delegation` section
  - Increment the delegation counter in loop-state history
  - Go back to 2.5.2
- If delegation budget exhausted:
  - **Commit harness state updates**: `git add .claude-harness/ && git commit -m "chore: persist harness state after {feature-id} failure" && git push` (on current branch)
  - Display failure summary with attempt count, last approach, last error
  - Suggest: retry with `/claude-harness:flow {feature-id}`, or get help
  - Do NOT archive, do NOT switch to main

**If `needs_review`**:
- Display PR URL and status
- **Commit harness state updates** (if any): `git add .claude-harness/ && git commit -m "chore: persist harness state" && git push` (on current branch)
- Suggest: review PR then run `/claude-harness:merge`
- Do NOT archive

### 2.5.4: Proceed to Phase 7

After result processing, **skip directly to Phase 7** (Completion Report). Phases 3-6 were executed inside the subagent.

---

## Phase 4: Implementation

### Branch Verification and Loop State

1. **Branch verification**: `git branch --show-current` -- STOP if on main/master.

2. **Initialize loop state** (canonical Loop-State Schema v9):
   ```json
   {
     "version": 9,
     "feature": "feature-XXX", "featureName": "{description}",
     "type": "feature", "status": "in_progress",
     "attempt": 1, "maxAttempts": 12,
     "startedAt": "{ISO}", "history": [],
     "tasks": { "enabled": true, "chain": ["{task-ids}"], "current": null, "completed": [] },
     "team": null
   }
   ```
   `maxAttempts` 12 = 4 attempts per delegation x 3 delegations. Record each delegation boundary in `history`.

   If `--team`: set `team` field:
   ```json
   "team": {
     "enabled": true,
     "teamName": "{projectName}-{feature-id}",
     "leadMode": "delegate",
     "teammates": [
       { "role": "tester", "name": null, "status": "pending", "tasksCompleted": 0 },
       { "role": "implementer", "name": null, "status": "pending", "tasksCompleted": 0 },
       { "role": "reviewer", "name": null, "status": "pending", "tasksCompleted": 0 }
     ]
   }
   ```

3. Update task status: mark Implement task as in_progress (standard) or mark first team task as in_progress (team mode).

### Standard Implementation (no --team)

- Implement the feature directly based on the plan from Phase 3
- Follow ATDD: write acceptance tests first from Gherkin acceptance criteria (RED), then implement to pass (GREEN), then refactor
- Run verification commands after implementation
- On failure: record a Failure concept to `${MEMORY_DIR}/failures/`, increment attempts, retry with a DIFFERENT approach

### Phase 4.1: Verification and Memory Updates

- **Streaming memory updates** after each verification attempt (concept files per `schemas/okf-memory.md`, listed in the directory's `index.md`):
  - Fail: write `${MEMORY_DIR}/failures/fail-{NNN}-{slug}.md` (`type: Failure`; frontmatter id/title/timestamp/feature, body `# {approach}` + `## Errors` + `## Root Cause`), increment attempts, retry
  - Pass: write `${MEMORY_DIR}/successes/suc-{NNN}-{slug}.md` (`type: Success`; body `# {approach}` + `## Files` + `## Patterns`), mark loop "completed", update tasks (mark Implement/Verify/Accept completed, Checkpoint in_progress)

- **On escalation** (4 attempts inside a delegation): stop and return `escalated` with a summary of every approach tried and why it failed -- the orchestrator uses this to seed the next delegation.
