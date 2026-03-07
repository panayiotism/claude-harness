# Implementation - Detailed Phases

Covers Phase 2.5 (Context Isolation / Subagent Delegation), Phase 4 (Implementation), and Phase 4.1 (Verification).

## Phase 2.5: Context Isolation (Standard Mode)

**Skip this phase** if `--plan-only` or `--autonomous`. Autonomous mode has its own delegation loop (Phase A.4). Plan-only mode needs inline execution for interactive plan review.

After feature creation completes (feature entry exists in active.json with GitHub issue, branch, and acceptance criteria), delegate the remaining lifecycle to an isolated subagent for clean context.

### 2.5.1: Compile Subagent Prompt

**Assemble all context the subagent needs** (effort: low -- mechanical data assembly):

Read and compile from Phase 1 context (already loaded):
- **Feature entry**: full object from active.json (id, name, description, acceptanceCriteria, relatedFiles, verification, github refs)
- **Verification commands**: from `.claude-harness/config.json` verification section
- **Relevant failures**: max 5 from `failures.json`, filtered by feature's relatedFiles overlap
- **Success patterns**: max 5 from `successes.json`, filtered for similar file patterns
- **Recent decisions**: max 10 from `decisions.json`
- **Learned rules**: max 5 active rules from `rules.json` applicable to this feature
- **GitHub info**: owner/repo from Phase 1 cache
- **Flag states**: `--team` (boolean), `--quick` (boolean), `--no-merge` (boolean)
- **Team config**: `agentTeams` section from config.json (if `--team`)

**Format structured subagent prompt** (target: under 3,000 tokens):

```
You are implementing feature {feature-id}: {featureName}.
Execute the full feature lifecycle and return a structured result.

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

## Instructions
1. Checkout the feature branch: git checkout {branch}
2. Plan the implementation {unless --quick: "(skip planning -- --quick mode)"}
3. Follow ATDD: write acceptance tests first from the Gherkin acceptance criteria (RED), then implement to pass all tests (GREEN), then refactor.
4. {if --team: "Create an Agent Team (tester, implementer, reviewer). Execute Mandatory Team Shutdown Gate before checkpoint."}
5. {if NOT --team: "Implement directly -- but still follow ATDD order: acceptance tests first, then implementation."}
6. Run ALL verification commands after implementation
7. On pass: stage ALL modified files including `.claude-harness/` state files (`git add .claude-harness/ && git add -A`), then commit as `feat({feature-id}): {description}`, push, create/update PR with `Closes #{issueNumber}`
8. On fail: retry with escalation (attempts 1-5: high effort, 6-10: max, 11-15: max + full memory). Max 15 attempts.
9. {if NOT --no-merge: "Merge PR (squash), close issue, delete branch, update feature status to 'passing', then archive: read archive.json (create if missing), append feature with archivedAt timestamp, remove from active.json, write both files"}
10. {if --no-merge: "Stop at checkpoint. Do not merge."}
11. Compile session briefing: write `.claude-harness/session-briefing.md` with condensed context. Keep under 120 lines.

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
summary: {one-line summary of what was done}
```

### 2.5.2: Delegate to Subagent

- Use Task tool with `subagent_type="general-purpose"`
- Pass the compiled prompt from 2.5.1
- The subagent executes in its **own fresh context window** (complete isolation)
- The subagent runs Phases 3-6 autonomously
- Wait for subagent completion

### 2.5.3: Process Subagent Result

**Parse the RESULT block** from the subagent's response:
- Search for `RESULT:` prefix in the subagent's return message
- Parse key-value pairs (status, commitHash, prNumber, attempts, featureStatus, memoryUpdates, summary)
- If RESULT block not found: treat as `needs_review`, check external state:
  - `git log --oneline -1` on feature branch for commit evidence
  - `gh pr list --head {branch}` for PR evidence
  - Log warning: "Subagent did not return structured result -- checking external state"

**Process result based on status**:

**If `completed`**:
- **Persist memory updates** from subagent:
  - For each decision: append to `${MEMORY_DIR}/episodic/decisions.json` (enforce maxEntries 50, FIFO)
  - For each failure: append to `${MEMORY_DIR}/procedural/failures.json`
  - For each success: append to `${MEMORY_DIR}/procedural/successes.json`
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
- **Clear session state**: clear loop-state.json, working-context.json
- **Regenerate session briefing**: write `.claude-harness/session-briefing.md` if subagent didn't
- **Commit harness state updates to main** (CRITICAL — orchestrator changes must be persisted):
  - `git add .claude-harness/ && git status --porcelain .claude-harness/`
  - If there are staged changes: `git commit -m "chore: update harness state (memory, features, briefing)" && git push origin main`
  - This captures: archived features, memory persistence, session briefing, progress updates

**If `failed` or `escalated`**:
- Persist memory updates (failures)
- **Commit harness state updates**: `git add .claude-harness/ && git commit -m "chore: persist harness state after {feature-id} failure" && git push` (on current branch)
- Display failure summary with attempt count, last approach, last error
- Suggest: retry with `/claude-harness:flow {feature-id}`, increase maxAttempts, or get help
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
     "attempt": 1, "maxAttempts": 15,
     "startedAt": "{ISO}", "history": [],
     "tasks": { "enabled": true, "chain": ["{task-ids}"], "current": null, "completed": [] },
     "team": null
   }
   ```
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
- On failure: record to failures.json, increment attempts, retry with escalation

### Phase 4.1: Verification and Memory Updates

- **Streaming memory updates** after each verification attempt:
  - Fail: append to failures.json (id, feature, approach, errors, rootCause), increment attempts, retry
  - Pass: append to successes.json (id, feature, approach, files, patterns), mark loop "completed", update tasks (mark Implement/Verify/Accept completed, Checkpoint in_progress)

- **On escalation** (max attempts): show summary, offer options (increase attempts, get help, abort). Do NOT checkpoint.
