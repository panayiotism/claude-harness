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

When `--autonomous` is set, the flow operates as an outer loop iterating all active features. Each feature is implemented directly, then cleaned up before moving to the next.

See **Effort Controls** table above for per-phase effort levels. Progressive escalation on retries per feature applies.

---

### Phase A.1: Initialize Autonomous State

4. **Read feature backlog**:
   - Set paths: `FEATURES_FILE=".claude-harness/features/active.json"`, `MEMORY_DIR=".claude-harness/memory/"`
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
     "version": 3,
     "mode": "autonomous",
     "startedAt": "{ISO timestamp}",
     "iteration": 0, "maxIterations": 20,
     "consecutiveFailures": 0, "maxConsecutiveFailures": 3,
     "completedFeatures": [], "skippedFeatures": [], "failedFeatures": [],
     "currentFeature": null
   }
   ```

7. **Parse and cache GitHub repo** (reuse across iterations):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   ```

8. **Read all memory layers IN PARALLEL**: failures.json, successes.json, decisions.json, rules.json

9. **Display autonomous banner** showing: feature count, max iterations, merge/planning mode, GitHub info, memory stats.

---

### Phase A.2: Feature Selection (LOOP START)

10. **Re-read feature backlog**:
    - Read `${FEATURES_FILE}`, filter eligible features (not passing/skipped/failed)
    - If none remain: proceed to Phase A.7

11. **Select next feature**: lowest ID (deterministic ordering). Update `currentFeature` and increment `iteration`.

12. **Display iteration header**: iteration count, feature info, progress.

---

### Phase A.3: Conflict Detection

13. Switch to main and pull: `git checkout main && git pull origin main`

14. Checkout feature branch and rebase onto main.

15. **Handle rebase result**:
    - Success: proceed to A.4
    - Conflict: `git rebase --abort`, add to `skippedFeatures` with reason, go back to A.2

---

### Phase A.4: Execute Feature Flow

Runs standard Phases 1-7 with autonomous overrides.

#### A.4.1: Context Compilation
16. Run Phase 1 normally (reuse GitHub/memory from A.1). Write context.json.

#### A.4.2: Feature Creation (conditional)
17. Skip if feature already exists with status `pending` or `in_progress`. Otherwise run Phase 2.

#### A.4.3: Planning
18. Run Phase 3 unless `--quick`. Create task chain (6 tasks for autonomous: Research, Plan, Implement, Verify, Accept, Checkpoint). If TaskCreate fails, retry once then fall back to manual tracking.

#### A.4.4: Implementation

**Branch verification**: `git branch --show-current` — STOP if on main/master.

21. **Initialize loop state** — see canonical Loop-State Schema (Phase 4, step 17).

22. **Implement the feature** directly based on the plan from Phase 3. Follow test-driven practices where applicable: write/update tests, then implement, then verify.

23. **Run ALL verification commands** after implementation. On failure: record to failures.json, increment attempts, retry with escalation (>5: max effort, >10: max + procedural memory).

24. **Final Verification Gate**: Run ALL verification commands. Record success to successes.json. Update loop status to `"completed"`.

25. **On escalation** (maxAttempts reached): add to `failedFeatures`, increment `consecutiveFailures`, record to procedural memory, proceed to A.5→A.6.

#### A.4.5: Auto-Checkpoint
26. Run Phase 5 (all sub-phases 5.1–5.6): update progress, capture working context, persist all memory layers (episodic, semantic, procedural, learned rules), auto-reflect on user corrections, persist orchestration memory, commit `feat({feature-id}): {description}`, push, create/update PR.

#### A.4.6: Auto-Merge (unless --no-merge)
27. Run Phase 6: check PR status, merge if ready (squash), close issue, delete branch, archive feature. If needs review: mark checkpointed, continue.

---

### Phase A.5: Post-Feature Cleanup

27.5. **Mandatory Team Teardown (if --team)** — MUST run before anything else in A.5:
   - Execute the full Mandatory Team Shutdown Gate (Step 22T, Steps A through E)
   - If team cleanup fails: mark feature as "needs_review" with reason "team-cleanup-failed", add to `skippedFeatures`, **do NOT proceed to A.5 step 28** — jump directly to A.6
   - Verify: `agents/context.json` `teamState` is null, no orphaned tmux sessions
   - This prevents zombie agents from accumulating across autonomous iterations

28. **Archive completed feature**: If status "passing", archive to archive.json and remove from active.json. Otherwise skip.

29. **Update autonomous state**: Add to `completedFeatures`, reset `consecutiveFailures`.

30. Switch to main: `git checkout main && git pull origin main`

31. **Reset session state**: Clear loop-state, task references.

32. **Brief per-feature report**: feature ID, test counts, PR status, attempts, duration, progress. If team mode: include teammate stats and any shutdown warnings.

---

### Phase A.6: Loop Continuation Check

33. **Check termination conditions** (in order):
    1. No eligible features remaining → Phase A.7
    2. `iteration` reached `maxIterations` (20) → Phase A.7
    3. `consecutiveFailures` reached `maxConsecutiveFailures` (3) → Phase A.7
    4. All remaining features skipped/failed → Phase A.7

34. **If continuing**: write state, go back to A.2.

---

### Phase A.7: Autonomous Completion Report

35. **Generate final report**: duration, iterations, completed/skipped/failed features with details, memory updates (decisions/patterns/rules).

36. **Final cleanup**: ensure on main, clear autonomous state, clean up task references.

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

8.5. **Define acceptance criteria** (ATDD — if `atdd.requireAcceptanceCriteria` is true in config.json):
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
    - If `atdd.acceptanceTestFirst` is true: write acceptance tests first (RED), then implement to pass (GREEN)
    - Otherwise: follow test-driven practices where applicable (write/update tests, then implement)
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
27. If ready: merge (squash), close issue, delete branch, update status to "passing", archive feature
28. If needs review: display PR URL with resume/merge commands
29. Final cleanup: switch to main, pull latest, clear loop state

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
