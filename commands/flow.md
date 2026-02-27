---
description: Unified end-to-end workflow - creates, implements, checkpoints, and merges features automatically
argument-hint: "DESCRIPTION" | FEATURE-ID | --fix FEATURE-ID "bug description" | --autonomous | --plan-only | --team
---

The single command for all development workflows. Handles the entire feature lifecycle from creation to merge.

Arguments: $ARGUMENTS

---

## Overview

`/claude-harness:flow` is the unified development command. All workflows run through this single entry point with flags:

```
/claude-harness:flow "Add dark mode support"           # Standard workflow
/claude-harness:flow --autonomous                      # Batch process all features
/claude-harness:flow --plan-only "Big refactor"        # Plan only, implement later
/claude-harness:flow --team "Add user login"           # ATDD with Agent Team (3 teammates)
```

**Lifecycle**: Context → Creation → Planning → Implementation → Verification → Checkpoint → Merge

**ATDD Team Lifecycle** (with `--team`): Context → Creation (with Gherkin criteria) → Planning → **Team Spawn** → Acceptance Tests (RED) → Implementation (GREEN) → Review → Verify → Checkpoint → Merge

---

## Effort Controls (Opus 4.6+)

Opus 4.6 supports effort levels (low/medium/high/max). Apply per phase:

| Phase | Effort | Why |
|-------|--------|-----|
| Context Compilation | low | Mechanical data loading |
| Feature Creation / Selection / Conflict Detection | low | Template-based, deterministic |
| Planning | max | Determines approach quality, avoids past failures |
| Implementation | high | Core coding, escalate to max on retry |
| Verification / Debug | max | Root-cause analysis needs deepest reasoning |
| Checkpoint / Merge | low | Mechanical operations |
| Subagent Delegation (autonomous) | low | Mechanical prompt assembly and result parsing |

**Adaptive Escalation** (progressive on retries): Attempts 1-5: high. Attempts 6-10: max. Attempts 11-15: max + full procedural memory.

On models without effort controls, all phases run at default effort.

---

## Phase 0.1: Argument Parsing

1. **Parse arguments**:
   - Empty: Show interactive menu for feature selection
   - Matches `feature-\d+`: Resume existing feature
   - Matches `fix-feature-\d+-\d+`: Resume existing fix
   - `--fix <feature-id> "description"`: Create fix linked to feature
   - Otherwise: Create new feature from description

2. **Parse options**:
   - `--no-merge`: Skip merge phase (stop at checkpoint)
   - `--quick`: Implement directly without planning phase
   - `--plan-only`: Stop after Phase 3. Resume later with feature ID.
   - `--autonomous`: Outer loop — iterate all active features
   - `--team`: Use Agent Teams for ATDD implementation (requires `agentTeams.enabled` in config.json)

3. **Mode validation**:
   - `--autonomous`: Compatible with `--no-merge`, `--quick`, and `--team`. Proceed to Autonomous Wrapper.
   - `--plan-only`: Proceeds through Phases 0-3 then STOPS. Incompatible with `--team`.
   - `--team`: Compatible with `--autonomous`, `--no-merge`. Incompatible with `--quick` (teams need planning) and `--plan-only` (no team to create yet).

---

## Phase 0.2: Team Preflight (if --team)

2.5. **Verify Agent Teams environment**:
   - Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var is set to `1`
   - If not set: display error with instructions to enable in config.json → run `/claude-harness:setup`, then STOP
   - Read `.claude-harness/config.json` `agentTeams` section:
     - Verify `agentTeams.enabled` is `true`. If not: display "Enable agentTeams in config.json" and STOP
     - Cache team config: `defaultTeamSize`, `roles`, `requirePlanApproval`, `teammateModel`

---

## Autonomous Wrapper (if --autonomous)

When `--autonomous` is set, the flow operates as a **lean orchestrator loop** that iterates all active features. Each feature is executed in an **isolated subagent context** via the Task tool, providing complete context isolation between features. The orchestrator handles only feature selection, conflict detection, result processing, and state management.

See **Effort Controls** table above for per-phase effort levels. Progressive escalation on retries per feature applies within each subagent.

### Context Isolation (Autonomous Mode)

Each feature is delegated to a `general-purpose` subagent via the Task tool. This provides:

- **Fresh context window**: Each feature starts with zero accumulated context from previous features
- **Clean token budget**: No context waste from irrelevant details of previous features
- **Contained failures**: A failing feature's debugging context does not pollute the next feature
- **Memory continuity**: The orchestrator persists memory updates between features, so learnings from Feature A are available to Feature B through procedural/episodic memory (not through raw context accumulation)
- **Team containment**: When `--team` is used, the Agent Team lifecycle is fully contained within the subagent — no zombie agents leak to the orchestrator

---

### Phase A.1: Initialize Autonomous State

4. **Read feature backlog**:
   - Set paths: `FEATURES_FILE=".claude-harness/features/active.json"`, `ARCHIVE_FILE=".claude-harness/features/archive.json"`, `MEMORY_DIR=".claude-harness/memory/"`
   - Read and filter features where status is NOT `"passing"`
   - If none eligible: display "No pending features" and **EXIT**

5. **Check for resume** (if `autonomous-state.json` exists):
   - Check `.claude-harness/sessions/.recovery/interrupted.json` for interrupt recovery
   - If marker exists and matches current feature: record interrupted attempt in history, increment counter
   - Read preserved state from `.recovery/` if needed, delete markers after processing
   - Read `.claude-harness/sessions/{session-id}/autonomous-state.json`
   - If exists: display resume summary, proceed
   - If not exists: create fresh state (step 6)

6. **Create autonomous state file** at `.claude-harness/sessions/{session-id}/autonomous-state.json`:
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

7. **Parse and cache GitHub repo** (reuse across iterations):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   ```

8. **Read all memory layers IN PARALLEL**: failures.json, successes.json, decisions.json, rules.json

9. **Display autonomous banner** showing: feature count, max iterations, merge/planning mode, GitHub info, memory stats, context isolation status.

---

### Phase A.2: Feature Selection (LOOP START)

10. **Re-read feature backlog**:
    - Read `${FEATURES_FILE}`, filter eligible features (not passing/skipped/failed)
    - If none remain: proceed to Phase A.7

11. **Select next feature**: lowest ID (deterministic ordering). Update `currentFeature` and increment `iteration`.

12. **Read full feature entry** from active.json (entire object including acceptanceCriteria, relatedFiles, verification, github refs). Store for A.4.0 prompt compilation.

13. **Display iteration header**: iteration count, feature info, progress.

---

### Phase A.3: Conflict Detection

14. Switch to main and pull: `git checkout main && git pull origin main`

15. Checkout feature branch and rebase onto main.

16. **Handle rebase result**:
    - Success: proceed to A.4.0
    - Conflict: `git rebase --abort`, add to `skippedFeatures` with reason, go back to A.2

---

### Phase A.4.0: Compile Subagent Prompt

17. **Assemble all context the subagent needs** (effort: low — mechanical data assembly):

    Read and compile from cached memory (loaded in A.1):
    - **Feature entry**: full object from active.json (id, name, description, acceptanceCriteria, relatedFiles, verification, github refs)
    - **Verification commands**: from `.claude-harness/config.json` verification section
    - **Relevant failures**: max 5 from `failures.json`, filtered by feature's relatedFiles overlap or similar feature type
    - **Success patterns**: max 5 from `successes.json`, filtered for similar file patterns
    - **Recent decisions**: max 10 from `decisions.json`
    - **Learned rules**: all active rules from `rules.json` applicable to this feature (max 5)
    - **GitHub info**: owner/repo from A.1 cache
    - **Loop history**: previous attempts for this specific feature (if resuming from failedFeatures or interrupted state)
    - **Flag states**: `--team` (boolean), `--quick` (boolean), `--no-merge` (boolean)
    - **Team config**: `agentTeams` section from config.json (if `--team`)

18. **Format structured subagent prompt** (target: under 3,000 tokens):

    ```
    You are executing feature {feature-id}: {featureName} as part of an autonomous batch.
    Run the full feature lifecycle (Phases 1-7) and return a structured result.

    ## Feature
    {feature JSON entry — id, name, description, acceptanceCriteria, relatedFiles}

    ## GitHub
    Owner: {owner} | Repo: {repo}
    Issue: #{issueNumber} | Branch: {branch}

    ## Verification Commands
    build: {build} | tests: {tests} | lint: {lint} | typecheck: {typecheck} | acceptance: {acceptance}

    ## Memory: Approaches to AVOID
    {for each relevant failure: "- {approach} → {rootCause}"}

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
    2. Plan the implementation {unless --quick: "(skip planning — --quick mode)"}
    3. Follow ATDD: write acceptance tests first from the Gherkin acceptance criteria (RED), then implement to pass all tests (GREEN), then refactor.
    4. {if --team: "Create an Agent Team (tester, implementer, reviewer). Tester writes acceptance tests, implementer makes them pass, reviewer validates. Execute Mandatory Team Shutdown Gate (22T) before checkpoint."}
    5. {if NOT --team: "Implement directly — but still follow ATDD order: acceptance tests first, then implementation."}
    6. Run ALL verification commands after implementation
    7. On pass: commit as `feat({feature-id}): {description}`, push, create/update PR with `Closes #{issueNumber}`
    8. On fail: retry with escalation (attempts 1-5: high effort, 6-10: max, 11-15: max + full memory). Max 15 attempts.
    9. {if NOT --no-merge: "Merge PR (squash), close issue, delete branch, update feature status to 'passing', then archive: read .claude-harness/features/archive.json (create with {\"version\":3,\"archived\":[],\"archivedFixes\":[]} if missing), append the feature entry with archivedAt timestamp to archived[], remove feature from active.json features[], write both files"}
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

### Phase A.4: Execute Feature Flow (Subagent Delegation)

19. **Delegate feature to isolated subagent** (effort: low — mechanical delegation):
    - Use Task tool with `subagent_type="general-purpose"`
    - Pass the compiled prompt from Phase A.4.0
    - The subagent executes in its **own fresh context window** (complete isolation from orchestrator)
    - The subagent runs the full standard flow (Phases 1-7) autonomously:
      - Phase 1: Context compilation (using passed-in context, minimal I/O)
      - Phase 2: Feature creation (if status is `pending`)
      - Phase 3: Planning (unless `--quick`)
      - Phase 3.7: Team roster + Phase 4 Team (if `--team`)
      - Phase 4: Implementation with retry loop (up to 15 attempts)
      - Phase 5: Checkpoint (commit, push, PR)
      - Phase 6: Merge (unless `--no-merge`)
    - Wait for subagent completion
    - Parse the RESULT block from the subagent's return message

20. **Handle subagent return parsing**:
    - Search for `RESULT:` prefix in the subagent's response
    - Parse key-value pairs (status, commitHash, prNumber, attempts, featureStatus, memoryUpdates, summary)
    - If RESULT block not found: treat as `needs_review`, check external state:
      - `git log --oneline -1` on feature branch for commit evidence
      - `gh pr list --head {branch}` for PR evidence
      - Log warning: "Subagent did not return structured result — checking external state"

---

### Phase A.5: Post-Feature Processing

21. **Safety-net team cleanup check** (if `--team`):
    - Read `.claude-harness/agents/context.json`
    - If `teamState` is non-null: team cleanup failed inside subagent
      - Attempt cleanup: send shutdown requests, wait, clean up team resources
      - Check for orphaned tmux sessions: `tmux ls 2>/dev/null | grep "{teamName}"` — kill if found
      - If cleanup still fails: mark feature as `needs_review` with reason "team-cleanup-failed", add to `skippedFeatures`, jump to A.6
    - Set `teamState` to null, write updated file

22. **Process subagent result** based on parsed status:

    **If `completed`**:
    - **Archive feature** (CRITICAL — this is the step that was previously missed):
      1. Read `${FEATURES_FILE}` (`.claude-harness/features/active.json`)
      2. Find the completed feature entry by ID (`currentFeature`)
      3. Read `${ARCHIVE_FILE}` (`.claude-harness/features/archive.json`). If file is missing, create with `{"version":3,"archived":[],"archivedFixes":[]}`
      4. Add `"archivedAt": "{ISO timestamp}"` and set `"status": "passing"` on the feature entry
      5. Append the feature entry to the `archived[]` array in archive.json
      6. Remove the feature from the `features[]` array in active.json
      7. Write BOTH files (`${ARCHIVE_FILE}` first, then `${FEATURES_FILE}`)
      8. **Verify**: Re-read `${FEATURES_FILE}` and confirm the feature ID is no longer in the `features[]` array. If still present, retry the removal once.
    - Add feature ID to `completedFeatures` in autonomous-state
    - Reset `consecutiveFailures` to 0

    **If `failed` or `escalated`**:
    - Add to `failedFeatures` with reason and attempt count
    - Increment `consecutiveFailures`

    **If `needs_review`**:
    - Add to `skippedFeatures` with reason `"needs_review"`
    - Do NOT increment `consecutiveFailures`

23. **Persist memory updates from subagent** (critical for cross-feature learning):
    - For each decision in `memoryUpdates.decisions`:
      - Append to `${MEMORY_DIR}/episodic/decisions.json` with id, timestamp, feature
      - Enforce maxEntries (50) — FIFO if exceeded
    - For each failure in `memoryUpdates.failures`:
      - Append to `${MEMORY_DIR}/procedural/failures.json`
    - For each success in `memoryUpdates.successes`:
      - Append to `${MEMORY_DIR}/procedural/successes.json`
    - For each pattern in `memoryUpdates.patterns`:
      - Merge into `${MEMORY_DIR}/procedural/patterns.json` (deduplicate)

24. **Record feature result** in autonomous-state `featureResults` array:
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

25. **Update autonomous state**: write updated state file with incremented iteration, updated feature lists.

26. **Switch to main and clean up branches**:
    - `git checkout main && git pull origin main`
    - If feature status is `completed` (merged): delete local branch: `git branch -d feature/{feature-id}` (safe delete — only works if fully merged)
    - Prune stale remote tracking refs: `git fetch --prune`

27. **Reset session state**: Clear loop-state.json, clear task references, clear working-context.json (all session-scoped files).

28. **Brief per-feature report**: feature ID, status, attempts, commit hash, PR number, duration, memory updates count, progress (N/M features complete).

---

### Phase A.6: Loop Continuation Check

29. **Check termination conditions** (in order):
    1. No eligible features remaining → Phase A.7
    2. `iteration` reached `maxIterations` (20) → Phase A.7
    3. `consecutiveFailures` reached `maxConsecutiveFailures` (3) → Phase A.7
    4. All remaining features skipped/failed → Phase A.7

30. **If continuing**: write state, go back to A.2.

---

### Phase A.7: Autonomous Completion Report

31. **Generate final report**: duration, iterations, completed/skipped/failed features with details, per-feature results summary, total memory updates (decisions/patterns/rules persisted across all features).

32. **Final cleanup**: ensure on main, clear autonomous state, clean up task references.

---

## Phase 1: Context Compilation (Auto-Start)

Read all memory layers IN PARALLEL for speed.

3. **Set paths**:
   ```bash
   FEATURES_FILE=".claude-harness/features/active.json"
   MEMORY_DIR=".claude-harness/memory/"
   ARCHIVE_FILE=".claude-harness/features/archive.json"
   ```

4. **Parse and cache GitHub repo** (do this ONCE):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   ```
   Parse owner/repo from SSH or HTTPS URL. Store for reuse.

5. **Read IN PARALLEL**: failures.json, successes.json, decisions.json, rules.json, active.json

6. **Compile working context** to `.claude-harness/sessions/{session-id}/context.json`:
   ```json
   {
     "version": 3, "computedAt": "{ISO}", "sessionId": "{session-id}",
     "github": { "owner": "{parsed}", "repo": "{parsed}" },
     "activeFeature": null,
     "relevantMemory": { "recentDecisions": [], "projectPatterns": [], "avoidApproaches": [], "learnedRules": [] }
   }
   ```

7. **Display context summary**: memory stats, GitHub info.

---

## Phase 2: Feature Creation

Use cached GitHub owner/repo from Phase 1.

8. **Generate feature ID**: Read active.json, find highest ID, generate next `feature-XXX`.

8.5. **Define acceptance criteria** (ATDD — always on):
   - If feature has existing `acceptanceCriteria` (from PRD breakdown): use those
   - Otherwise: generate Gherkin acceptance criteria from the feature description
   - Format each criterion as structured Gherkin:
     ```json
     {
       "scenario": "Descriptive scenario name",
       "given": "precondition (context setup)",
       "when": "action performed",
       "then": "expected outcome"
     }
     ```
   - Aim for 2-5 scenarios covering: happy path, error cases, edge cases

9. **Create GitHub Issue**: `mcp__github__create_issue` with labels `["feature", "claude-harness", "flow"]`, body with Problem/Solution/Acceptance Criteria (Gherkin)/Verification. Include acceptance criteria as a `## Acceptance Tests` section using Gherkin format:
   ```
   ## Acceptance Tests

   **Scenario: {scenario}**
   - Given {given}
   - When {when}
   - Then {then}
   ```
   STOP if fails.

10. **Create and checkout branch**: `mcp__github__create_branch`, then `git fetch origin && git checkout feature/feature-XXX`. Verify branch.

11. **Create feature entry** in active.json: id, name, status "in_progress", `acceptanceCriteria` array (from step 8.5), github refs, verificationCommands, maxAttempts 15.

---

## Phase 3: Planning (unless --quick)

13. **Query procedural memory** (effort: max): Check past failures/successes. Warn if planned approach matches past failure.

14. **Analyze requirements**: Break down, identify files, calculate impact.

15. **Generate plan**: Store in feature entry or session context.

---

## Phase 3.5: Create Task Breakdown

Uses Claude Code's native Tasks for visual progress tracking.

15.5. **Create task chain** (6 tasks for standard flow):
    - Task 1: "Research {feature}" → Task 2: "Plan {feature}" → Task 3: "Implement {feature}" → Task 4: "Verify {feature}" → Task 5: "Accept {feature}" → Task 6: "Checkpoint {feature}"
    - Each blocked by previous. Store IDs in loop-state.
    - If TaskCreate fails, retry once then continue with manual tracking.

15.7. Mark Task 1 as in_progress (research begins in Phase 3).

---

## Phase 3.7: Team Roster (if --team)

15.8. **Prepare team structure** from config.json `agentTeams`:
   - Team name: `"{projectName}-{feature-id}"`
   - Roles from config (default: `["implementer", "reviewer", "tester"]`)
   - Model override from config `teammateModel` (null = inherit lead's model)

15.9. **Prepare ATDD spawn prompts** for each role:

   **Tester** (spawns first — writes acceptance tests):
   ```
   You are the Tester for {feature-id}: {featureName}.

   YOUR PRIMARY TASK: Write executable acceptance tests from these Gherkin criteria BEFORE any implementation exists.
   This is the RED phase of ATDD — tests MUST fail initially (there's no implementation yet).

   Acceptance Criteria:
   {for each criterion in acceptanceCriteria}
   Scenario: {scenario}
     Given {given}
     When {when}
     Then {then}
   {end}

   Test framework: {from config.json verification.tests}
   Acceptance test command: {from config.json verification.acceptance}
   Project patterns: {from procedural memory test patterns}

   Write tests that are:
   - Executable with the project's test framework
   - Focused on behavior (not implementation details)
   - Independent of each other
   - Clear about expected outcomes

   After writing tests, run them to confirm they execute (failures expected in RED phase).
   ```

   **Implementer** (spawns in parallel — plans approach):
   ```
   You are the Implementer for {feature-id}: {featureName}.

   YOUR PRIMARY TASK: Make all acceptance tests pass (GREEN phase of ATDD).

   Wait for the Tester to complete writing acceptance tests (Task 1).
   Then implement the feature to make every test pass.

   Plan: {from Phase 3}
   Acceptance Criteria: {acceptanceCriteria summary}
   Related files: {relatedFiles}
   Verification commands: {from config.json}

   Past failures to AVOID: {from procedural memory, last 3}
   Learned rules: {from learned rules}

   Follow test-driven approach:
   1. Read the acceptance tests the Tester wrote
   2. Implement minimal code to make each test pass
   3. Refactor while keeping tests green
   4. Run ALL verification commands before marking complete
   ```

   **Reviewer** (spawns last — reviews after implementation):
   ```
   You are the Reviewer for {feature-id}: {featureName}.

   YOUR PRIMARY TASK: Review the implementation for quality, security, and adherence to patterns.

   Wait for the Implementer to complete (Task 3). Then review:

   Code standards: {from semantic memory architecture.patterns}
   Project patterns: {from procedural memory patterns}
   Acceptance criteria: {acceptanceCriteria — verify all are covered}

   Review checklist:
   - [ ] All acceptance criteria covered by tests
   - [ ] No security vulnerabilities (OWASP top 10)
   - [ ] Follows existing code patterns and naming conventions
   - [ ] Error handling for edge cases
   - [ ] No unnecessary complexity or over-engineering
   - [ ] Clean, readable code

   Report findings with severity: CRITICAL (must fix), WARNING (should fix), INFO (suggestion).
   ```

15.10. Store roster in session context for checkpoint persistence.

---

## Phase 3.8: Plan-Only Gate (if --plan-only)

If `--plan-only`: display plan summary (feature ID, issue, branch) with resume command and **EXIT**.

---

## Phase 4: Implementation

16. **Branch verification**: `git branch --show-current` — STOP if on main/master.

17. **Initialize loop state** (canonical Loop-State Schema v9):
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

17.5. Update task status: mark Implement task as in_progress (standard) or mark first team task as in_progress (team mode).

---

### Phase 4 (Standard — no --team): Direct Implementation

18. **Implement the feature** directly based on the plan from Phase 3:
    - Follow ATDD: write acceptance tests first from Gherkin acceptance criteria (RED), then implement to pass (GREEN), then refactor
    - Run verification commands after implementation
    - On failure: record to failures.json, increment attempts, retry with escalation

---

### Phase 4 (Team — if --team): ATDD with Agent Teams

18T. **Create the Agent Team**:
   - Tell Claude to create an agent team named `"{teamName}"` with delegate mode
   - Spawn 3 teammates using the prompts from Phase 3.7:
     - Tester (with `requirePlanApproval: true` from config)
     - Implementer (with `requirePlanApproval: true` from config)
     - Reviewer (no plan approval needed)
   - If `agentTeams.teammateModel` is set, specify model for each teammate
   - Update loop-state `team.teammates[].name` with spawned teammate names
   - Update `.claude-harness/agents/context.json` with `teamState`

19T. **Create ATDD shared task chain** (6 tasks with dependencies):
   ```
   Task 1: "Write acceptance tests for {feature}" (tester)       ── no deps
   Task 2: "Plan implementation for {feature}" (implementer)     ── no deps
   Task 3: "Implement {feature}" (implementer)                    ── blocked by Task 1, Task 2
   Task 4: "Code review {feature}" (reviewer)                     ── blocked by Task 3
   Task 5: "Address review feedback for {feature}" (implementer)  ── blocked by Task 4
   Task 6: "Final verification for {feature}" (tester)            ── blocked by Task 5
   ```
   Tasks 1 and 2 run in parallel. The implementer cannot start coding until acceptance tests exist.

20T. **Monitor team progress**:
   - The lead (this session) operates in delegate mode — coordination only
   - `TeammateIdle` hook enforces: no uncommitted changes, verification passing
   - `TaskCompleted` hook enforces ATDD gates:
     - Task 1 (RED): acceptance tests exist and can be executed
     - Task 3 (GREEN): acceptance tests pass
     - Task 6 (VERIFY): ALL verification commands pass
   - When teammates send messages, review and redirect if needed
   - Periodically check task list progress

21T. **Handle team completion or failure**:
   - **Success**: All 6 tasks complete → shut down teammates → clean up team → proceed to Phase 4.1
   - **Teammate failure**: If a teammate stops with errors:
     - Spawn replacement teammate with same role and context
     - Increment attempt count
   - **Team failure** (max attempts exhausted):
     - Shut down all teammates
     - Clean up team resources
     - Record failure to procedural memory
     - Fall back to standard Phase 4 (direct implementation) as safety net

22T. **Mandatory Team Shutdown Gate** (MUST complete before Phase 5):

   This gate ensures ALL teammates are fully stopped before proceeding. Skipping this creates zombie agents that drain CPU/RAM.

   **Step A — Request shutdown for each teammate** (in parallel):
   - For each teammate in the team roster:
     - Send shutdown request: "Please shut down now. Your work is complete."
     - Record shutdown request time

   **Step B — Verify shutdown with polling loop** (max 60 seconds):
   ```
   attempts = 0
   max_poll_attempts = 12  (every 5 seconds for 60s total)
   while attempts < max_poll_attempts:
     Check each teammate status (via team list / Shift+Up/Down)
     If ALL teammates stopped: BREAK → proceed to Step C
     If any still running: wait 5 seconds, increment attempts
   ```

   **Step C — Handle stragglers** (if any teammate still running after 60s):
   - For each still-running teammate:
     - Send forceful message: "You must shut down immediately. Ignoring will result in forced cleanup."
     - Wait 10 seconds
     - If STILL running: proceed anyway — the team cleanup command will report which teammates couldn't be stopped
   - **Log warning** to stderr and loop-state history: "Teammate {name} ({role}) did not shut down within timeout"

   **Step D — Run team cleanup**:
   - Execute team cleanup command (this removes shared team resources)
   - If cleanup fails because teammates are still active:
     - Log the failure
     - **In autonomous mode**: this is CRITICAL — do NOT proceed to next feature. Mark current feature as "needs_review" and add to `skippedFeatures` with reason "team-cleanup-failed"
     - **In standard mode**: warn user, suggest manual tmux session cleanup

   **Step E — Verify and persist**:
   - Confirm no orphaned tmux sessions remain for this team: `tmux ls 2>/dev/null | grep "{teamName}"` — if found, kill: `tmux kill-session -t "{teamName}"`
   - Persist team results to `agents/context.json` `agentResults`
   - Set `agents/context.json` `teamState` to null
   - Update loop-state `team.teammates[].status` to "completed"
   - Update loop-state `team.enabled` to false

   **IMPORTANT**: The flow MUST NOT proceed to Phase 5 (Checkpoint) until Step E completes successfully. This is a hard gate, not a soft recommendation.

---

### Phase 4.1: Verification and Memory Updates

19. **Streaming memory updates** after each verification attempt:
    - Fail: append to failures.json (id, feature, approach, errors, rootCause), increment attempts, retry
    - Pass: append to successes.json (id, feature, approach, files, patterns), mark loop "completed", update tasks (mark Implement/Verify/Accept completed, Checkpoint in_progress)

20. **On escalation** (max attempts): show summary, offer options (increase attempts, get help, abort). Do NOT checkpoint.

---

## Phase 5: Auto-Checkpoint

Triggers when verification passes. This phase mirrors `/claude-harness:checkpoint` to ensure all memory layers are updated.

### 5.1: Update Progress

21. Update `.claude-harness/claude-progress.json` with session summary, blockers, next steps.

### 5.2: Capture Working Context

21.5. Update session-scoped working context `.claude-harness/sessions/{session-id}/working-context.json`:
   - Set `activeFeature`, `summary`, populate `workingFiles` from feature's `relatedFiles` + `git status`
   - Populate `decisions` with key architectural/implementation decisions made
   - Set `nextSteps` to immediate actionable items
   - Keep concise (~25-40 lines)

### 5.3: Persist to Memory Layers

22. **Persist session decisions to episodic memory**:
   - Read `${MEMORY_DIR}/episodic/decisions.json`
   - For each key decision made during this session, append entry with id, timestamp, feature, decision, rationale, alternatives, impact
   - If entries exceed `maxEntries` (50), remove oldest (FIFO)
   - Write updated file

22.1. **Update semantic memory with discovered patterns**:
   - Read `${MEMORY_DIR}/semantic/architecture.json`
   - Update `structure`, `patterns.naming`, `patterns.fileOrganization`, `patterns.codeStyle` based on work done
   - Write updated file

22.2. **Update semantic entities** (if new concepts discovered):
   - Read `${MEMORY_DIR}/semantic/entities.json`
   - Append new concepts/entities with name, type, location, relationships
   - Write updated file

22.3. **Update procedural patterns**:
   - Read `${MEMORY_DIR}/procedural/patterns.json`
   - Extract reusable patterns from this session (code patterns, naming conventions, project-specific rules)
   - Merge into existing patterns (don't duplicate)
   - Write updated file

### 5.4: Auto-Reflect on User Corrections

22.4. **Run reflection** (auto mode):
   - Scan conversation for user correction patterns
   - For corrections with high confidence: auto-save to `${MEMORY_DIR}/learned/rules.json`
   - For lower confidence: queue for manual review (don't save)
   - Display results if rules were extracted:
     ```
     AUTO-REFLECTION
     High-confidence rules auto-saved: {N}
     • {rule title}
     ```
   - If no corrections detected: continue silently

### 5.5: Persist Orchestration Memory

22.5. **Persist orchestration memory** (if agent results exist):
   - Read `.claude-harness/agents/context.json`
   - For completed agent results: add to `${MEMORY_DIR}/procedural/successes.json`
   - For failed agent results: add to `${MEMORY_DIR}/procedural/failures.json`
   - Merge `discoveredPatterns` into `${MEMORY_DIR}/procedural/patterns.json`
   - Persist `architecturalDecisions` to `${MEMORY_DIR}/episodic/decisions.json`
   - Clear `agentResults`, set `currentSession` to null

### 5.6: Commit, Push, PR

23. Commit `feat(feature-XXX): {description}`, push to remote
24. Create/update PR via `mcp__github__create_pull_request`: title, body with Closes #{issue}
24.5. Mark Checkpoint task completed.
25. Display checkpoint summary: commit hash, PR number, task status.

---

## Phase 6: Auto-Merge (unless --no-merge)

Only proceeds if PR approved and CI passes.

26. Check PR status via `mcp__github__get_pull_request_status`
27. If ready: merge (squash), close issue, delete remote branch (via GitHub API), update status to "passing", archive feature
28. If needs review: display PR URL with resume/merge commands
29. **Final cleanup**:
    - Switch to main: `git checkout main && git pull origin main`
    - **Delete local feature branch**: `git branch -d feature/{feature-id}` (use `-d` not `-D` — safe delete only works if branch is fully merged)
    - Prune stale remote tracking refs: `git fetch --prune`
    - Clear loop state

---

## Phase 7: Completion Report

29.5. Clean up tasks (all 6 should be completed, remain in history).

30. Display final status: feature ID, description, issue (closed), PR (merged), tasks 6/6, attempts, duration, memory updates (decisions/patterns/rules).

---

## Resume Behavior

31. `/claude-harness:flow feature-XXX`:
    - **Check interrupt recovery** (priority): Read `.claude-harness/sessions/.recovery/interrupted.json`
    - If marker matches resumed feature:
      - Read preserved loop-state from `.recovery/`
      - Display recovery banner with feature info, interrupt time, attempt count
      - **In autonomous**: always FRESH APPROACH (option 1)
      - **In standard**: present 3 options via AskUserQuestion:
        1. FRESH APPROACH (recommended) — increment attempt, record interrupted attempt in history, load procedural memory
        2. RETRY SAME — same counter, don't add to history
        3. RESET — start from Phase 3 with fresh state
      - All options: copy preserved state, delete recovery markers
    - **If no marker**: resume from feature status:
      - `pending` → Phase 3, `in_progress` → Phase 4, `needs_review` → Phase 6, `passing` → already complete

32. Interrupted flow: state preserved in `.recovery/`, auto-detected and recovered.

---

## Error Handling

33. **GitHub API failures**: Retry with exponential backoff. If persistent: pause and inform user.
34. **Verification failures**: Record to procedural memory, try alternative, escalate after maxAttempts.
35. **Merge conflicts**: Inform user, offer rebase or manual resolution.

---

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/flow "Add X"` | Full lifecycle: implement → verify → checkpoint → merge |
| `/flow feature-XXX` | Resume existing feature from current phase |
| `/flow --no-merge "Add X"` | Stop at checkpoint |
| `/flow --quick "Simple fix"` | Skip planning, implement directly |
| `/flow --plan-only "Big feature"` | Plan only, implement later |
| `/flow --fix feature-001 "Bug"` | Create and complete a bug fix |
| `/flow --autonomous` | Batch process all features |
| `/flow --autonomous --no-merge` | Batch, stop at checkpoint |
| `/flow --autonomous --quick` | Autonomous without planning |
| `/flow --team "Add X"` | ATDD with Agent Team: tester + implementer + reviewer |
| `/flow --team --no-merge "Add X"` | Team ATDD, stop at checkpoint |
| `/flow --team --autonomous` | Teams for each feature in autonomous batch |

**Flag combinations**: `--no-merge --plan-only` (plan before implementing), `--autonomous --no-merge --quick` (fast batch without merge), `--team --autonomous --no-merge` (team ATDD batch without merge)

---

## When to Use Each Mode

| Mode | Use Case |
|------|----------|
| Default (`/flow "desc"`) | Standard feature development |
| `--no-merge` | Review PR before merging |
| `--plan-only` | Complex features needing upfront design |
| `--quick` | Simple fixes — skips planning |
| `--autonomous` | Batch processing feature backlog unattended |
| `--team` | Complex features benefiting from parallel review + ATDD |
| `--team --autonomous` | High-quality batch processing with code review |
