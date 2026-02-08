---
description: Unified end-to-end workflow - creates, implements, checkpoints, and merges features automatically
argument-hint: "DESCRIPTION" | FEATURE-ID | --fix FEATURE-ID "bug description" | --autonomous | --plan-only
---

The single command for all development workflows. Handles the entire feature lifecycle from creation to merge with Agent Teams orchestration (test-writer, implementer, reviewer specialists).

Arguments: $ARGUMENTS

---

## Overview

`/claude-harness:flow` is the unified development command. All workflows (standard, TDD, batch, planning) run through this single entry point with flags:

```
/claude-harness:flow "Add dark mode support"           # Standard workflow
/claude-harness:flow --autonomous                      # Batch process all features
/claude-harness:flow --plan-only "Big refactor"        # Plan only, implement later
```

**Lifecycle Phases**:
1. **Context** - Auto-compile memory
2. **Creation** - GitHub issue, branch, feature entry
3. **Planning** - Architecture analysis, approach selection
4. **Team Setup** - Create specialist team (test-writer, implementer, reviewer)
5. **Implementation** - Team-driven TDD: RED → GREEN → REFACTOR
6. **Checkpoint** - Auto-commit when tests pass
7. **Merge** - Auto-merge when PR approved (optional)

---

## Effort Controls (Opus 4.6+)

Opus 4.6 supports effort levels (low/medium/high/max) that balance reasoning depth, speed, and cost.
Apply these effort levels per phase to optimize workflow efficiency:

| Phase | Effort | Why |
|-------|--------|-----|
| Context Compilation | low | Mechanical data loading, no complex reasoning needed |
| Feature Creation | low | Template-based, deterministic steps |
| Planning | max | Critical phase -- determines approach quality and avoids past failures |
| Implementation | high | Core coding work benefits from careful reasoning |
| Verification/Debug | max | Root-cause analysis and debugging need deepest reasoning |
| Checkpoint | low | Mechanical commit/push operations |
| Merge | low | Mechanical merge operations |

**Adaptive Loop Strategy** (progressive escalation on retries):
- Attempts 1-5: high effort (let natural reasoning work)
- Attempts 6-10: max effort (engage deepest analysis for stubborn issues)
- Attempts 11-15: max effort + load full procedural memory for cross-feature pattern analysis

On models without effort controls, all phases run at default effort (no change in behavior).

---

## Phase 0: Preflight Check

**BLOCKER — Agent Teams required:**
Before anything else, verify that `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set to `1`. If it is NOT:
- Display: "BLOCKER: Agent Teams is not enabled. Run /claude-harness:setup, then restart Claude Code (env vars from settings.local.json take effect on next launch)."
- **STOP. Do NOT proceed to any subsequent phase.**

---

## Phase 0.1: Argument Parsing

1. **Parse arguments**:
   - If empty: Show interactive menu with `multiSelect: true` for parallel feature selection
   - If matches `feature-\d+`: Resume existing feature
   - If matches `fix-feature-\d+-\d+`: Resume existing fix
   - If `--fix <feature-id> "description"`: Create fix linked to feature
   - Otherwise: Create new feature from description

2. **Parse options**:
   - `--no-merge`: Skip automatic merge phase (stop at checkpoint)
   - `--quick`: Skip planning phase
   - `--plan-only`: Stop after Phase 3 (planning). Resume later with feature ID.
   - `--autonomous`: Outer loop mode - iterate through all active features, checkpoint, merge, repeat

3. **Mode validation**:
   - If `--autonomous`: Compatible with `--no-merge` and `--quick`. **Proceed to Autonomous Wrapper.**
   - If `--plan-only`: Proceeds through Phases 0-3 then STOPS.

**Note**: TDD (RED-GREEN-REFACTOR) is always-on. The specialist team structure (test-writer → implementer → reviewer) enforces TDD by design. No `--tdd` flag needed.

---

## Phase 0.5: Multi-Select Parallel Team

**When user selects 2+ features from interactive menu** (empty args with multiSelect):

3.5. **Create Agent Team for parallel features**:
   - Create agent team: `"{project}-parallel-{timestamp}"`
   - Lead enters **delegate mode** (coordinates only, doesn't implement)
   - For each selected feature, spawn a teammate:
     ```
     Spawn teammate "{feature-id}" with prompt:
       You are implementing feature {feature-id}: {feature-name}.
       Branch: feature/{feature-id}

       1. Checkout branch: git checkout feature/{feature-id}
       2. Read feature from .claude-harness/features/active.json
       3. Execute full TDD lifecycle:
          - Write failing tests (RED)
          - Implement minimal code to pass tests (GREEN)
          - Refactor for quality (REFACTOR)
       4. Run all verification commands
       5. Commit + push + create PR

       ## Coordination Rules
       - If you create shared utilities, message all teammates about the new file
       - If you discover a file another teammate needs, message them
       - Do NOT modify files outside your feature scope
       - Mark your task as complete when PR is created

       ## Verification Commands
       {auto-detected from config.json}
     ```
   - Create shared tasks for each feature in the team task list
   - Display team status:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  AGENT TEAM: Parallel Feature Development                      │
     ├─────────────────────────────────────────────────────────────────┤
     │  Team: {team-name}                                             │
     │  Mode: Delegate (lead coordinates only)                        │
     │                                                                │
     │  Teammate         Feature              Status                  │
     │  ─────────────────────────────────────────────────────────────  │
     │  {feature-001}    {feature-name-1}      Spawned                │
     │  {feature-002}    {feature-name-2}      Spawned                │
     │                                                                │
     │  Navigate: Shift+Up/Down to select teammate                    │
     │  Tasks: Ctrl+T to view shared task list                        │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - Lead monitors teammates via `TeammateIdle` notifications
   - When all teammates complete: shut down teammates, clean up team
   - **Lead stays active as coordinator** until all features are done

---

## Autonomous Wrapper (if --autonomous)

When `--autonomous` is set, the entire flow operates as an outer agentic loop that iterates through all active features. Each feature goes through the full lifecycle (context → planning → team-driven TDD → checkpoint → merge) before moving to the next.

**IMPORTANT**: This wrapper replaces the normal Phase 1-7 flow. Each iteration creates a specialist team (test-writer, implementer, reviewer) for the feature, runs TDD, then cleans up the team before moving to the next feature.

### Autonomous Effort Controls

| Phase | Effort | Why |
|-------|--------|-----|
| Feature Selection / Conflict Detection | low | Mechanical git operations and list filtering |
| Context Compilation | low | Mechanical data loading |
| Team Setup / Test Planning | high | Requires understanding feature behavior to design tests |
| RED (test-writer writes tests) | high | Must define expected behavior precisely |
| GREEN (implementer passes tests) | high | Core coding work, escalate to max on retry |
| REFACTOR (reviewer validates) | max | Deep structural analysis benefits most from max reasoning |
| Verification / Debug | max | Root-cause analysis needs deepest reasoning |
| Checkpoint / Merge | low | Mechanical commit/push/merge operations |

Progressive escalation on retries (per feature): Attempts 1-5: high. Attempts 6-10: max. Attempts 11-15: max + full procedural memory.

---

### Phase A.1: Initialize Autonomous State

4. **Read feature backlog**:
   - Set paths: `FEATURES_FILE=".claude-harness/features/active.json"`, `MEMORY_DIR=".claude-harness/memory/"`
   - Read `${FEATURES_FILE}` to get all features
   - Filter features where `status` is NOT `"passing"`
   - If no eligible features exist:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  AUTONOMOUS: No pending features                               │
     │  All features in active.json are already passing.              │
     │  Add features with /claude-harness:flow "description"          │
     └─────────────────────────────────────────────────────────────────┘
     ```
     **EXIT** - nothing to process

5. **Check for resume** (if `autonomous-state.json` already exists):
   - Read `.claude-harness/sessions/{session-id}/autonomous-state.json`
   - If file exists and `mode` is `"autonomous"`:
     - Display resume summary: completed/skipped/failed counts
     - **Check `leadMode` field** (backward compatibility):
       - If present: Use as-is
       - If missing (v1 schema): Add `"leadMode": "delegate"` and `"leadModeRule"` to the file (migrate to v2), then write back
     - **Re-assert delegation rule from `leadModeRule`** (compaction defense)
     - Resume from where it left off (skip already completed features)
   - If file does not exist: create fresh state (step 6)

6. **Create autonomous state file**:
   - Write to `.claude-harness/sessions/{session-id}/autonomous-state.json`:
     ```json
     {
       "version": 2,
       "mode": "autonomous",
       "leadMode": "delegate",
       "leadModeRule": "Lead coordinates ONLY. Do NOT write code, do NOT modify source files, do NOT implement features directly. ALWAYS create an Agent Team with 3 specialists (test-writer, implementer, reviewer) and delegate all implementation work to them.",
       "startedAt": "{ISO timestamp}",
       "iteration": 0,
       "maxIterations": 20,
       "consecutiveFailures": 0,
       "maxConsecutiveFailures": 3,
       "completedFeatures": [],
       "skippedFeatures": [],
       "failedFeatures": [],
       "currentFeature": null,
       "tddStats": {
         "totalTestsWritten": 0,
         "totalTestsPassing": 0,
         "featuresWithTDD": 0
       }
     }
     ```

7. **Parse and cache GitHub repo** (MANDATORY - same as Phase 1 step 4):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   ```
   Parse owner and repo. Store in session context for reuse across all iterations.

8. **Read all memory layers IN PARALLEL** (single message, multiple Read tool calls):
   - `${MEMORY_DIR}/procedural/failures.json`
   - `${MEMORY_DIR}/procedural/successes.json`
   - `${MEMORY_DIR}/episodic/decisions.json`
   - `${MEMORY_DIR}/learned/rules.json`

9. **Display autonomous banner**:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  AUTONOMOUS MODE                                               │
   ├─────────────────────────────────────────────────────────────────┤
   │  Features to process: {N}                                      │
   │  Lead: DELEGATE (coordinates only, does not code)              │
   │  Mode: TDD (Red-Green-Refactor) enforced                      │
   │  Max iterations: 20                                            │
   │  Merge: {auto / --no-merge}                                   │
   │  Planning: {full / --quick}                                    │
   │  GitHub: {owner}/{repo}                                        │
   │  Memory: {N} decisions, {N} patterns, {N} to avoid            │
   ├─────────────────────────────────────────────────────────────────┤
   │  Starting feature processing loop...                           │
   └─────────────────────────────────────────────────────────────────┘
   ```

---

### Phase A.2: Feature Selection (LOOP START)

10. **Re-read feature backlog AND delegation mode**:
    - Read `${FEATURES_FILE}` (may have changed after merges from prior iterations)
    - Filter features where:
      - `status` is NOT `"passing"`
      - `id` is NOT in `skippedFeatures` list
      - `id` is NOT in `failedFeatures` list
    - If no eligible features remain: **proceed to Phase A.7** (completion report)
    - **Re-read delegation mode** (MANDATORY — survives context compaction):
      - Read `.claude-harness/sessions/{session-id}/autonomous-state.json`
      - Extract `leadMode` and `leadModeRule` fields
      - If `leadMode` is `"delegate"` (or missing — default to delegate):
        ```
        ┌─────────────────────────────────────────────────────────────────┐
        │  DELEGATION MODE ACTIVE                                        │
        │  You are the LEAD COORDINATOR. Do NOT write code directly.     │
        │  You MUST create an Agent Team for this feature.               │
        │  Specialists: test-writer, implementer, reviewer               │
        └─────────────────────────────────────────────────────────────────┘
        ```

11. **Select next feature**:
    - Choose the feature with the **lowest ID** (deterministic ordering)
    - This ensures natural dependency resolution (earlier features are processed first)
    - Update autonomous state:
      - Set `currentFeature` to selected feature ID
      - Increment `iteration` counter

12. **Display iteration header**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  AUTONOMOUS: Iteration {N}/{maxIterations}                     │
    │  Feature: {feature-id} - {feature-name}                       │
    │  Progress: {completed}/{total} completed, {skipped} skipped   │
    └─────────────────────────────────────────────────────────────────┘
    ```

---

### Phase A.3: Conflict Detection

13. **Switch to main and update**:
    ```bash
    git checkout main
    git pull origin main
    ```

14. **Checkout feature branch and rebase**:
    - Read feature's `github.branch` from `active.json`
    ```bash
    git checkout {feature-branch}
    git rebase origin/main
    ```

15. **Handle rebase result**:
    - **If rebase succeeds** (clean): Proceed to Phase A.4
    - **If rebase fails** (conflict):
      ```bash
      git rebase --abort
      ```
      - Add to `skippedFeatures` in autonomous state:
        ```json
        {
          "id": "{feature-id}",
          "reason": "merge-conflict",
          "skippedAt": "{ISO timestamp}",
          "details": "Conflict during rebase onto main"
        }
        ```
      - Display:
        ```
        ┌─────────────────────────────────────────────────────────────────┐
        │  AUTONOMOUS: Skipping {feature-id} (merge conflict)           │
        │  Feature requires manual conflict resolution.                  │
        │  Moving to next feature...                                    │
        └─────────────────────────────────────────────────────────────────┘
        ```
      - **Go back to Phase A.2** (select next feature)

---

### Phase A.4: Execute Feature Flow with Team

This phase runs the standard flow Phases 1-7 with a specialist team per feature and autonomous overrides.

#### A.4.1: Context Compilation

16. **Run Phase 1** (Context Compilation) normally:
    - Worktree detection, GitHub caching (reuse from A.1), memory reads (reuse from A.1)
    - Compile working context for this feature
    - Write to `.claude-harness/sessions/{session-id}/context.json`

#### A.4.2: Feature Creation (conditional)

17. **Check if feature already exists** in `active.json`:
    - If feature has `status: "pending"` or `status: "in_progress"`: **SKIP creation** (already exists with issue and branch)
    - If feature needs a GitHub issue or branch: Run Phase 2 (Feature Creation) normally
    - Most features in autonomous mode will already exist in `active.json`, so this phase is typically skipped

#### A.4.3: Planning

18. **Run Phase 3** (Planning) unless `--quick`:
    - Standard planning steps (query procedural memory, analyze requirements, generate plan)

19. **Create task chain** (Phase 3.5) with TDD tasks:
    - Task 1: "Research {feature}" - activeForm: "Researching {feature}"
    - Task 2: "Plan {feature}" - activeForm: "Planning {feature}"
    - Task 3: "Write tests for {feature} (RED)" - activeForm: "Writing failing tests"
    - Task 4: "Implement {feature} (GREEN)" - activeForm: "Implementing to pass tests"
    - Task 5: "Review {feature} (REFACTOR)" - activeForm: "Reviewing {feature}"
    - Task 6: "Verify {feature}" - activeForm: "Verifying {feature}"
    - Task 7: "Checkpoint {feature}" - activeForm: "Creating checkpoint"
    - **REQUIRED**: If TaskCreate fails, retry once. If still failing, log error and continue with manual tracking in loop-state.

#### A.4.4: Team-Driven Implementation (RED-GREEN-REFACTOR)

**Branch verification** (MANDATORY):
```bash
CURRENT_BRANCH=$(git branch --show-current)
```
- **STOP if on main/master** - fetch and checkout feature branch

**Delegation mode gate** (MANDATORY — prevents direct implementation):
- Read `leadMode` from `.claude-harness/sessions/{session-id}/autonomous-state.json`
- **ASSERT**: `leadMode` MUST be `"delegate"`
- Display:
  ```
  ┌─────────────────────────────────────────────────────────────────┐
  │  DELEGATION CHECK: Lead is in DELEGATE mode                    │
  │  Action: Create Agent Team, do NOT implement directly          │
  └─────────────────────────────────────────────────────────────────┘
  ```
- If `leadMode` is missing: Set it to `"delegate"` in autonomous-state.json (self-heal)
- **CRITICAL**: If you find yourself about to write code, modify source files, or implement features directly — STOP. Re-read this gate. You are the coordinator. Spawn the team.

21. **Initialize loop state** (v6 with team tracking):
    - Write to `.claude-harness/sessions/{session-id}/loop-state.json`:
      ```json
      {
        "version": 6,
        "feature": "{feature-id}",
        "featureName": "{description}",
        "type": "feature",
        "status": "in_progress",
        "attempt": 1,
        "maxAttempts": 15,
        "startedAt": "{ISO timestamp}",
        "history": [],
        "tdd": {
          "phase": null,
          "testsWritten": [],
          "testStatus": null
        },
        "team": {
          "teamName": "{project}-{feature-id}",
          "leadMode": "delegate",
          "roster": ["test-writer", "implementer", "reviewer"],
          "results": [],
          "reviewCycles": 0
        },
        "tasks": {
          "enabled": true,
          "chain": ["{task-ids}"],
          "current": null,
          "completed": []
        }
      }
      ```

22. **Create team and spawn specialists**:
    - Create agent team: `"{project}-{feature-id}"`
    - Lead enters **delegate mode** (coordinates only, doesn't write code)
    - Spawn 3 teammates with context:
      - **test-writer**: feature requirements, test patterns from project, acceptance criteria, past failures to avoid
      - **implementer**: feature requirements, plan from Phase 3, codebase patterns, past failures to avoid
      - **reviewer**: feature requirements, codebase conventions, security concerns if applicable
    - Require plan approval for all teammates (lead reviews their approach before they write code)

23. **RED — test-writer writes failing tests** (effort: high):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  RED PHASE: test-writer writes failing tests for {feature-id} │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Lead assigns task to test-writer: "Write failing tests for {feature-name}"
    - test-writer explores test patterns, writes tests covering: unit tests, integration tests, edge cases
    - Lead waits for task completion (`TeammateIdle` notification)
    - **Verification gate**: tests must exist and FAIL (no implementation yet)
    - If tests **PASS** without implementation: log warning, continue anyway (don't prompt in autonomous)
    - Update TDD state: `tdd.phase = "red"`, `tdd.testStatus = "failing"`
    - Update `tddStats.totalTestsWritten` in autonomous state

24. **GREEN — implementer makes tests pass** (effort: high, escalate to max):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  GREEN PHASE: implementer makes tests pass for {feature-id}   │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Lead messages implementer: "Tests written at {paths}. Make them pass with minimal code."
    - Implementer reads tests, implements feature
    - Implementer can message test-writer directly: "Test X expects Y but the API returns Z — intentional?" — direct collaboration
    - Run ALL verification commands (build, tests, lint, typecheck)
    - **If tests PASS**:
      - Update TDD state: `tdd.phase = "green"`, `tdd.testStatus = "passing"`
      - Proceed to REFACTOR phase
    - **If tests FAIL**:
      - Record approach to history and to `${MEMORY_DIR}/procedural/failures.json`
      - Increment attempt counter
      - Lead messages implementer with failure context and suggests alternative approach
      - Retry (up to maxAttempts)
      - **Effort escalation**: If attempt > 5, use max effort. If attempt > 10, also load full procedural memory.

25. **REFACTOR — reviewer validates and improves** (effort: max):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  REFACTOR PHASE: reviewer validates {feature-id}              │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Lead messages reviewer: "Implementation complete, tests passing. Review for quality."
    - Reviewer reviews, messages implementer directly with issues
    - Implementer fixes, notifies reviewer — **direct dialogue, no lead intermediation**
    - Max 2 review rounds — lead intervenes if exceeded
    - Run tests after EACH refactoring change
    - **If tests break during refactoring**: Revert that specific change and stop refactoring
    - Update TDD state: `tdd.phase = "refactor"`

26. **Final Verification Gate** (MANDATORY):
    - Run ALL verification commands one final time
    - ALL must pass to proceed to checkpoint
    - Record success to `${MEMORY_DIR}/procedural/successes.json`:
      ```json
      {
        "id": "suc-{timestamp}",
        "timestamp": "{ISO}",
        "feature": "{feature-id}",
        "approach": "{what worked}",
        "tdd": true,
        "files": ["{modified files}"],
        "patterns": ["{learned patterns}"]
      }
      ```
    - Update loop status to `"completed"`

27. **Team cleanup**:
    - Shut down all teammates: "Ask all teammates to shut down"
    - Clean up team: "Clean up the team"

28. **On escalation** (maxAttempts reached in autonomous mode):
    - Do NOT prompt user - autonomous mode handles this automatically
    - Shut down team before moving on
    - Add to `failedFeatures` in autonomous state:
      ```json
      {
        "id": "{feature-id}",
        "reason": "max-attempts-reached",
        "failedAt": "{ISO timestamp}",
        "attempts": 15,
        "lastError": "{last error message}"
      }
      ```
    - Increment `consecutiveFailures` in autonomous state
    - Record all failure approaches to procedural memory
    - Display:
      ```
      ┌─────────────────────────────────────────────────────────────────┐
      │  AUTONOMOUS: Feature {feature-id} FAILED (max attempts)       │
      │  Attempts: 15/15 exhausted                                    │
      │  Consecutive failures: {N}/{maxConsecutiveFailures}            │
      │  Moving to next feature...                                    │
      └─────────────────────────────────────────────────────────────────┘
      ```
    - **Go to Phase A.5** (cleanup) then Phase A.6 (continuation check)

#### A.4.5: Auto-Checkpoint

29. **Run Phase 5** (Auto-Checkpoint) normally:
    - Update progress file
    - Persist to memory layers (episodic, semantic, procedural, learned)
    - Commit: `feat({feature-id}): {description}`
    - Push to remote
    - Create/update PR

#### A.4.6: Auto-Merge (unless --no-merge)

30. **Run Phase 6** (Auto-Merge) unless `--no-merge`:
    - Check PR status (CI, reviews)
    - If ready: merge (squash), close issue, delete branch, update status to "passing", **archive feature to `${ARCHIVE_FILE}`**
    - If needs review: mark feature as checkpointed but not merged, continue to next feature

---

### Phase A.5: Post-Feature Cleanup

29. **Archive completed feature** (MANDATORY):
    - Read `${FEATURES_FILE}` (active.json)
    - Find the current feature entry (by ID)
    - If status is "passing":
      - Add `archivedAt: "{ISO timestamp}"` to the feature object
      - Read `${ARCHIVE_FILE}` (archive.json), append the feature to `archived[]`
      - Write updated `${ARCHIVE_FILE}`
      - Remove the feature from `features[]` in `${FEATURES_FILE}`
      - Write updated `${FEATURES_FILE}`
      - Report: `"Archived feature {feature-id} to archive.json"`
    - If status is NOT "passing" (e.g., checkpointed but not merged):
      - Skip archiving, feature remains in active.json for next session

30. **Update autonomous state**:
    - Add to `completedFeatures`:
      ```json
      {
        "id": "{feature-id}",
        "completedAt": "{ISO timestamp}",
        "attempts": {N},
        "prNumber": {N},
        "merged": true|false
      }
      ```
    - Update `tddStats`:
      - Increment `featuresWithTDD`
      - Update `totalTestsWritten` and `totalTestsPassing`
    - Reset `consecutiveFailures` to 0 (feature succeeded)

31. **Switch to main and update**:
    ```bash
    git checkout main
    git pull origin main
    ```

32. **Reset session state**:
    - Reset loop-state.json to idle (v6 schema)
    - Clear TDD state, team state
    - Clear task references (if tasks were enabled)

33. **Brief per-feature report**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  AUTONOMOUS: Feature {feature-id} COMPLETE                    │
    │  RED -> GREEN -> REFACTOR                                     │
    │  Tests: {N} written, {N} passing                              │
    │  PR: #{number} {merged/awaiting review}                       │
    │  Attempts: {N} | Duration: {time}                             │
    │  Progress: {completed}/{total} features done                  │
    └─────────────────────────────────────────────────────────────────┘
    ```

---

### Phase A.6: Loop Continuation Check

34. **Check termination conditions** (in order):

    1. **Re-read `${FEATURES_FILE}`** - are there any eligible features left?
       - Filter: status != "passing", not in skipped/failed lists
       - If none remaining: **proceed to Phase A.7**

    2. **Iteration limit**: Has `iteration` reached `maxIterations` (default 20)?
       - If yes: **proceed to Phase A.7** with "max iterations reached" note

    3. **Consecutive failures**: Has `consecutiveFailures` reached `maxConsecutiveFailures` (default 3)?
       - If yes: **proceed to Phase A.7** with "too many consecutive failures" note

    4. **All skipped/failed**: Are ALL remaining features either skipped or failed?
       - If yes: **proceed to Phase A.7** with "all remaining features need manual attention" note

35. **If continuing**:
    - Write updated autonomous state to disk
    - **Re-read `leadModeRule` from autonomous-state.json** (compaction defense):
      - Display: `"Delegation mode: {leadMode} — proceeding to next feature"`
    - **Go back to Phase A.2** (feature selection)

---

### Phase A.7: Autonomous Completion Report

36. **Generate final report**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  AUTONOMOUS MODE COMPLETE                                      │
    ├─────────────────────────────────────────────────────────────────┤
    │  Duration: {total time from startedAt to now}                  │
    │  Iterations: {count}                                           │
    │                                                                │
    │  Completed: {N} features                                       │
    │  • {feature-id}: "{name}" (PR #{N}, merged)                   │
    │  • {feature-id}: "{name}" (PR #{N}, merged)                   │
    │                                                                │
    │  Skipped (conflicts): {N} features                             │
    │  • {feature-id}: "{name}" - conflict during rebase            │
    │                                                                │
    │  Failed (max attempts): {N} features                           │
    │  • {feature-id}: "{name}" - {N} attempts exhausted            │
    │                                                                │
    │  TDD Stats:                                                    │
    │  • Tests written: {N}                                          │
    │  • Tests passing: {N}                                          │
    │  • Features with TDD: {N}/{total}                              │
    │                                                                │
    │  Memory Updated:                                               │
    │  • {N} decisions recorded                                      │
    │  • {N} patterns learned                                        │
    │  • {N} rules extracted                                         │
    ├─────────────────────────────────────────────────────────────────┤
    │  Remaining features need manual attention:                     │
    │  • Conflicts: Rebase onto main and retry manually             │
    │  • Failures: Review procedural/failures.json for root causes  │
    └─────────────────────────────────────────────────────────────────┘
    ```

37. **Final cleanup**:
    - Ensure on main branch: `git checkout main && git pull origin main`
    - Clear autonomous state file (or keep for history)
    - Clean up any remaining task references

---

## Phase 1: Context Compilation (Auto-Start)

**IMPORTANT**: Read all memory layers IN PARALLEL for speed optimization.

3. **Set paths**:
   ```bash
   FEATURES_FILE=".claude-harness/features/active.json"
   MEMORY_DIR=".claude-harness/memory/"
   ARCHIVE_FILE=".claude-harness/features/archive.json"
   ```

4. **Parse and cache GitHub repo** (MANDATORY - do this ONCE for entire flow):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   # SSH: git@github.com:owner/repo.git
   # HTTPS: https://github.com/owner/repo.git
   ```
   Parse owner and repo from URL. Store in session context for reuse.

5. **Read all memory layers IN PARALLEL** (single message, multiple Read tool calls):
   - `${MEMORY_DIR}/procedural/failures.json`
   - `${MEMORY_DIR}/procedural/successes.json`
   - `${MEMORY_DIR}/episodic/decisions.json`
   - `${MEMORY_DIR}/learned/rules.json`
   - `${FEATURES_FILE}`

6. **Compile working context**:
   - Get session directory from SessionStart hook output
   - Write compiled context to `.claude-harness/sessions/{session-id}/context.json`:
     ```json
     {
       "version": 3,
       "computedAt": "{ISO timestamp}",
       "sessionId": "{session-id}",
       "github": {
         "owner": "{parsed owner}",
         "repo": "{parsed repo}"
       },
       "activeFeature": null,
       "relevantMemory": {
         "recentDecisions": [...],
         "projectPatterns": [...],
         "avoidApproaches": [...],
         "learnedRules": [...]
       }
     }
     ```

7. **Display context summary** (brief):
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  FLOW: Context compiled                                        │
   │  Memory: {N} decisions, {N} patterns, {N} to avoid            │
   │  GitHub: {owner}/{repo}                                        │
   └─────────────────────────────────────────────────────────────────┘
   ```

---

## Phase 2: Feature Creation

**Note**: Use cached GitHub owner/repo from Phase 1. DO NOT re-parse.

8. **Generate feature ID**:
   - Read `${FEATURES_FILE}` to find highest existing ID
   - Generate next sequential ID: `feature-XXX` (zero-padded)

9. **Create GitHub Issue** (MANDATORY):
   - Use `mcp__github__create_issue` with cached owner/repo
   - Title: Feature description
   - Labels: `["feature", "claude-harness", "flow"]`
   - Body: Problem, Solution, Acceptance Criteria, Verification (same as /do)
   - **STOP if issue creation fails**

10. **Create and checkout branch**:
    - Use `mcp__github__create_branch` with cached owner/repo
    - Branch: `feature/feature-XXX`
    - Immediately checkout locally:
      ```bash
      git fetch origin && git checkout feature/feature-XXX
      ```
    - **VERIFY branch before proceeding**

11. **Create feature entry**:
    - Add to `${FEATURES_FILE}`:
      ```json
      {
        "id": "feature-XXX",
        "name": "{description}",
        "status": "in_progress",
        "github": {
          "issueNumber": {from step 9},
          "prNumber": null,
          "branch": "feature/feature-XXX"
        },
        "verificationCommands": {auto-detected},
        "maxAttempts": 15
      }
      ```

---

## Phase 3: Planning (unless --quick)

13. **Query procedural memory** (effort: max):
    - Check past failures for similar features
    - Check successful approaches
    - **If planned approach matches past failure**: Warn and suggest alternative

14. **Analyze requirements**:
    - Break down feature into sub-tasks
    - Identify files to create/modify
    - Calculate impact score

15. **Generate plan**:
    - Store in feature entry or session context
    - Brief summary display (don't interrupt flow)

---

## Phase 3.5: Create Task Breakdown (Native Tasks Integration)

**IMPORTANT**: This phase uses Claude Code's native Tasks system for visual progress tracking.

15.5. **Create task chain for feature**:
    - Use `TaskCreate` for each workflow phase:
      ```
      Task 1: "Research {feature}"
        - description: "Explore codebase for existing patterns and dependencies"
        - activeForm: "Researching {feature}"

      Task 2: "Plan {feature}"
        - description: "Design implementation approach based on research"
        - activeForm: "Planning {feature}"
        - addBlockedBy: [Task 1 ID]

      Task 3: "Implement {feature}"
        - description: "Write code changes following the plan"
        - activeForm: "Implementing {feature}"
        - addBlockedBy: [Task 2 ID]

      Task 4: "Verify {feature}"
        - description: "Run all verification commands (build, test, lint)"
        - activeForm: "Verifying {feature}"
        - addBlockedBy: [Task 3 ID]

      Task 5: "Checkpoint {feature}"
        - description: "Commit, push, create PR"
        - activeForm: "Creating checkpoint for {feature}"
        - addBlockedBy: [Task 4 ID]
      ```
    - Store task IDs in loop-state for reference
    - **REQUIRED**: If TaskCreate fails, retry once. If still failing, log error and continue with manual tracking in loop-state.

15.6. **Display task chain**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  FLOW: Task chain created                                       │
    │  Tasks: [ ] Research → [ ] Plan → [ ] Implement → [ ] Verify   │
    │         → [ ] Checkpoint                                        │
    └─────────────────────────────────────────────────────────────────┘
    ```

15.7. **Mark first task in progress**:
    - Call `TaskUpdate` to set Task 1 status to "in_progress"
    - Research phase begins automatically in Phase 3 (Planning)

---

## Phase 3.7: Team Roster Setup (MANDATORY)

**Every feature uses an Agent Team with 3 specialists.** This phase prepares the team roster.

15.8. **Build team roster**:
   - Every feature gets the same 3-specialist team:
     - **test-writer**: Owns test files. Writes failing tests that define expected behavior (RED phase).
     - **implementer**: Owns source files. Writes minimal code to make tests pass (GREEN phase).
     - **reviewer**: Reviews implementation, messages implementer directly with issues (REFACTOR phase).

15.9. **Prepare specialist context** (from Phase 3 plan):
   - **test-writer context**: acceptance criteria, test patterns for project language, verification commands
     - Auto-detect test patterns:
       - TypeScript: `**/*.test.ts`, `**/*.spec.ts`, `**/__tests__/**`
       - JavaScript: `**/*.test.js`, `**/*.spec.js`, `**/__tests__/**`
       - Python: `**/test_*.py`, `**/*_test.py`, `**/tests/**`
       - Go: `**/*_test.go`
       - Shell/Bash: `**/test_*.sh`, `**/*_test.sh`
   - **implementer context**: files to modify, codebase patterns, implementation plan, past failures to avoid
   - **reviewer context**: codebase conventions, security concerns, quality standards

15.10. **Store team roster in loop state**:
    - Add to loop-state (v6 schema, see step 17):
      ```json
      {
        "team": {
          "teamName": "{project}-{feature-id}",
          "leadMode": "delegate",
          "roster": ["test-writer", "implementer", "reviewer"],
          "results": [],
          "reviewCycles": 0
        }
      }
      ```

15.11. **Display team roster**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  TEAM ROSTER: 3 specialists                                    │
    │  test-writer → implementer → reviewer                          │
    │  Mode: Delegate (lead coordinates, specialists implement)      │
    └─────────────────────────────────────────────────────────────────┘
    ```

---

## Phase 3.8: Plan-Only Gate (if --plan-only)

**If `--plan-only` flag is set, STOP here.**

15.12. **Display plan summary and exit**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  PLAN COMPLETE (--plan-only mode)                               │
    ├─────────────────────────────────────────────────────────────────┤
    │  Feature: feature-XXX                                           │
    │  Issue: #{issue}                                                │
    │  Branch: feature/feature-XXX                                    │
    │  Team: 3 specialists (test-writer, implementer, reviewer)       │
    ├─────────────────────────────────────────────────────────────────┤
    │  Resume: /claude-harness:flow feature-XXX                       │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - **EXIT** - do not proceed to Phase 4

---

## Phase 4: Implementation (Team-Driven)

**IMPORTANT**: Implementation MUST use an Agent Team with the roster from Phase 3.7. The lead coordinates in delegate mode while specialists do the work.

16. **Branch verification** (MANDATORY):
    ```bash
    CURRENT_BRANCH=$(git branch --show-current)
    ```
    - **STOP if on main/master**
    - Fetch and checkout correct branch if needed

17. **Initialize loop state** (v6 with team + task integration):
    - Write to `.claude-harness/sessions/{session-id}/loop-state.json`:
      ```json
      {
        "version": 6,
        "feature": "feature-XXX",
        "featureName": "{description}",
        "type": "feature",
        "status": "in_progress",
        "attempt": 1,
        "maxAttempts": 15,
        "startedAt": "{ISO timestamp}",
        "history": [],
        "tdd": {
          "phase": null,
          "testsWritten": [],
          "testStatus": null
        },
        "team": {
          "teamName": "{project}-{feature-id}",
          "leadMode": "delegate",
          "roster": ["test-writer", "implementer", "reviewer"],
          "results": [],
          "reviewCycles": 0
        },
        "tasks": {
          "enabled": true,
          "chain": ["{task-ids}"],
          "current": "{task3-id}",
          "completed": ["{task1-id}", "{task2-id}"]
        }
      }
      ```

17.5. **Update task status** (if tasks enabled):
    - Call `TaskUpdate` to mark "Implement" task (Task 3) as "in_progress"
    - Display task progress:
      ```
      Tasks: [✓] Research [✓] Plan [→] Implement [ ] Verify [ ] Checkpoint
      ```

---

### Phase 4.1: Create Team and Spawn Specialists

18. **Create agent team and enter delegate mode**:
    - Create team: `"{project}-{feature-id}"`
    - Lead enters **delegate mode** (Shift+Tab) — coordinates only, doesn't touch code
    - Spawn 3 teammates with context from Phase 3.7:
      - **test-writer**: feature requirements, test patterns from project, acceptance criteria, past failures to avoid
      - **implementer**: feature requirements, implementation plan from Phase 3, codebase patterns, past failures to avoid
      - **reviewer**: feature requirements, codebase conventions, security concerns if applicable, verification commands
    - Require plan approval for all teammates (lead reviews their approach before they write code)
    - Display:
      ```
      ┌─────────────────────────────────────────────────────────────────┐
      │  TEAM CREATED: {team-name}                                     │
      │  Mode: Delegate (lead coordinates only)                        │
      │  Teammates: test-writer, implementer, reviewer                 │
      │  Navigate: Shift+Up/Down | Tasks: Ctrl+T                      │
      └─────────────────────────────────────────────────────────────────┘
      ```

---

### Phase 4.2: Team-Driven TDD (RED → GREEN → REFACTOR)

**Step 1: RED — test-writer writes failing tests** (effort: high):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  RED PHASE: test-writer writes failing tests for {feature-id}  │
    ├─────────────────────────────────────────────────────────────────┤
    │  Tests define the expected behavior.                            │
    │  Tests MUST fail initially (no implementation yet).             │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Lead assigns task to test-writer: "Write failing tests for {feature-name} covering: unit tests, integration tests, edge cases"
    - test-writer explores test patterns, writes test files
    - Lead waits for task completion (`TeammateIdle` notification)
    - **Verification gate**: tests must exist and FAIL (no implementation yet)
    - If tests **PASS** without implementation: Log warning, continue
    - Update TDD state: `tdd.phase = "red"`, `tdd.testStatus = "failing"`

**Step 2: GREEN — implementer makes tests pass** (effort: high, escalate to max):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  GREEN PHASE: implementer makes tests pass for {feature-id}    │
    ├─────────────────────────────────────────────────────────────────┤
    │  Write MINIMAL code to make tests pass. Don't over-engineer.   │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Lead messages implementer: "Tests written at {paths}. Make them pass with minimal code."
    - Implementer reads test files, implements feature
    - Implementer can message test-writer directly: "Test X expects Y but the API returns Z — intentional?" — **direct collaboration without lead**
    - Lead waits for task completion (`TeammateIdle` notification)
    - **Post-implementation verification**: Run ALL verification commands (build, tests, lint, typecheck)
    - If tests **PASS**: Update `tdd.phase = "green"`, `tdd.testStatus = "passing"`. Proceed to REFACTOR.
    - If tests **FAIL**:
      - Lead messages implementer with failure context and suggests alternative approach
      - Increment attempt counter, retry (up to maxAttempts)
      - **Effort escalation**: If attempt > 5, use max effort. If attempt > 10, also load full procedural memory.

**Step 3: REFACTOR — reviewer validates and improves** (effort: max):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  REFACTOR PHASE: reviewer validates {feature-id}               │
    ├─────────────────────────────────────────────────────────────────┤
    │  Tests pass. Improve code while keeping tests green.            │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Lead messages reviewer: "Implementation complete, tests passing. Review for quality."
    - Reviewer reviews code, messages implementer directly with issues:
      - "Line 42 swallows the exception" → implementer: "Should I rethrow or log?" → reviewer: "Rethrow"
      - **Direct dialogue, no lead intermediation**
    - Implementer fixes issues, notifies reviewer
    - Max 2 review rounds (tracked in `team.reviewCycles`) — lead intervenes if exceeded
    - Run tests after EACH refactoring change
    - **If tests break during refactoring**: Revert that specific change and stop refactoring
    - Update TDD state: `tdd.phase = "refactor"`

---

### Phase 4.3: Verification and Team Cleanup

19. **STREAMING MEMORY UPDATES** (after EACH verification attempt):
    - **If verification failed**:
      - Immediately append to `${MEMORY_DIR}/procedural/failures.json`:
        ```json
        {
          "id": "fail-{timestamp}",
          "timestamp": "{ISO}",
          "feature": "feature-XXX",
          "approach": "{what was tried}",
          "errors": ["{error messages}"],
          "files": ["{modified files}"],
          "rootCause": "{analysis}"
        }
        ```
      - Increment attempt counter
      - Lead messages implementer with failure details and alternative approach
      - Retry (up to maxAttempts)

    - **If verification passed**:
      - Immediately append to `${MEMORY_DIR}/procedural/successes.json`:
        ```json
        {
          "id": "suc-{timestamp}",
          "timestamp": "{ISO}",
          "feature": "feature-XXX",
          "approach": "{what worked}",
          "files": ["{modified files}"],
          "patterns": ["{learned patterns}"]
        }
        ```
      - Update loop status to "completed"
      - **Update tasks** (if enabled):
        - Mark "Implement" task (Task 3) as "completed"
        - Mark "Verify" task (Task 4) as "completed"
        - Mark "Checkpoint" task (Task 5) as "in_progress"
        - Display: `Tasks: [✓] Research [✓] Plan [✓] Implement [✓] Verify [→] Checkpoint`

20. **Team cleanup**:
    - Shut down all teammates: "Ask all teammates to shut down"
    - Clean up team: "Clean up the team"
    - **Proceed to Phase 5 (Checkpoint)**

21. **On escalation** (max attempts reached):
    - Shut down team before escalating
    - Show attempt summary
    - Offer options: increase attempts, get help, abort
    - Do NOT proceed to checkpoint

---

## Phase 5: Auto-Checkpoint

**Triggers automatically when verification passes.**

21. **Update progress**:
    - Write to `${MAIN_REPO_PATH}/.claude-harness/claude-progress.json`

22. **Persist to memory layers** (in parallel where possible):
    - Episodic: Save key decisions
    - Semantic: Update architecture patterns
    - Learned: Extract rules from any corrections

23. **Commit and push**:
    - Stage all modified files (except .env, secrets)
    - Commit with message: `feat(feature-XXX): {description}`
    - Push to remote

24. **Create/update PR**:
    - Use `mcp__github__create_pull_request` with cached owner/repo
    - Title: `feat: {description}`
    - Body: Closes #{issue}, Summary, Test plan
    - Update feature entry with prNumber

24.5. **Complete checkpoint task** (if tasks enabled):
    - Mark "Checkpoint" task (Task 5) as "completed"
    - All tasks now complete: `[✓] Research [✓] Plan [✓] Implement [✓] Verify [✓] Checkpoint`

25. **Display checkpoint summary**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  FLOW: Checkpoint complete                                     │
    │  Commit: {hash}                                                 │
    │  PR: #{number} - awaiting review                               │
    │  Tasks: [✓] Research [✓] Plan [✓] Implement [✓] Verify [✓] PR │
    └─────────────────────────────────────────────────────────────────┘
    ```

---

## Phase 6: Auto-Merge (unless --no-merge)

**Only proceeds if PR is approved and CI passes.**

26. **Check PR status**:
    - Use `mcp__github__get_pull_request_status` with cached owner/repo
    - Check CI/CD status
    - Check review approvals

27. **If PR is ready to merge**:
    - Merge using `mcp__github__merge_pull_request` (squash merge)
    - Close linked issue
    - Delete source branch
    - Update feature status to "passing"
    - Archive feature to `${ARCHIVE_FILE}`

28. **If PR needs review**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  FLOW: Waiting for PR approval                                 │
    │  PR: #{number} - {url}                                         │
    │  Status: CI passing, awaiting review                           │
    ├─────────────────────────────────────────────────────────────────┤
    │  Run /claude-harness:flow {feature-id} to check again         │
    │  Or /claude-harness:merge to merge all approved PRs           │
    └─────────────────────────────────────────────────────────────────┘
    ```

29. **Final cleanup**:
    - Switch to main branch
    - Pull latest
    - Clear loop state

---

## Phase 7: Completion Report

29.5. **Clean up tasks** (if tasks enabled):
    - All 5 tasks should be "completed"
    - Tasks remain in `~/.claude/tasks/` for history
    - Clear task references from loop-state

30. **Display final status**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  FLOW COMPLETE                                                 │
    ├─────────────────────────────────────────────────────────────────┤
    │  Feature: feature-XXX                                          │
    │  Description: {name}                                           │
    │  Issue: #{issue} (closed)                                      │
    │  PR: #{pr} (merged)                                            │
    │  Tasks: 5/5 completed                                          │
    │  Attempts: {N}                                                 │
    │  Duration: {time}                                              │
    ├─────────────────────────────────────────────────────────────────┤
    │  Memory Updated:                                               │
    │  • {N} decisions recorded                                      │
    │  • {N} patterns learned                                        │
    │  • {N} rules extracted                                         │
    └─────────────────────────────────────────────────────────────────┘
    ```

---

## Resume Behavior

31. `/claude-harness:flow feature-XXX` (existing feature):
    - Check feature status in active.json
    - Resume from appropriate phase:
      - `pending`: Start at Phase 3 (Planning)
      - `in_progress`: Resume at Phase 4 (Implementation)
      - `needs_review`: Check at Phase 6 (Merge)
      - `passing`: Already complete

32. Interrupted flow:
    - State preserved in session-scoped files
    - Resume with `/claude-harness:flow feature-XXX`

---

## Error Handling

33. **GitHub API failures**:
    - Retry with exponential backoff
    - If persistent: Pause and inform user

34. **Verification failures**:
    - Record to procedural memory immediately
    - Try alternative approach
    - Escalate after maxAttempts

35. **Merge conflicts**:
    - Inform user
    - Offer: rebase, manual resolution

---

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/claude-harness:flow "Add X"` | Full lifecycle: team TDD (RED→GREEN→REFACTOR) → checkpoint → merge |
| `/claude-harness:flow feature-XXX` | Resume existing feature from current phase |
| `/claude-harness:flow --no-merge "Add X"` | Stop at checkpoint (don't auto-merge) |
| `/claude-harness:flow --quick "Simple fix"` | Skip planning phase |
| `/claude-harness:flow --plan-only "Big feature"` | Plan only, implement later with feature ID |
| `/claude-harness:flow --fix feature-001 "Bug"` | Create and complete a bug fix |
| `/claude-harness:flow --autonomous` | Batch process all active features with team per feature |
| `/claude-harness:flow --autonomous --no-merge` | Batch process, stop each at checkpoint |
| `/claude-harness:flow --autonomous --quick` | Autonomous without planning phase |

**Flag combinations:**
- `--no-merge --plan-only`: Plan and review approach before implementing
- `--autonomous --no-merge --quick`: Fast batch processing without merge

**Note**: TDD is always-on. Every feature gets a 3-specialist team (test-writer, implementer, reviewer) that enforces RED-GREEN-REFACTOR by design.

---

## When to Use Each Mode

| Mode | Use Case |
|------|----------|
| Default (`/flow "desc"`) | Standard feature with specialist team (TDD always-on) |
| `--no-merge` | When you want to review PR before merging |
| `--plan-only` | Complex features that need upfront design review |
| `--quick` | Simple fixes where planning is overhead |
| `--autonomous` | Batch processing an entire feature backlog unattended |
| Empty args (menu) | Select multiple features for parallel team processing |
