---
description: Unified end-to-end workflow - creates, implements, checkpoints, and merges features automatically
argument-hint: "DESCRIPTION" | FEATURE-ID | --fix FEATURE-ID "bug description" | --autonomous | --tdd | --plan-only
---

The single command for all development workflows. Handles the entire feature lifecycle from creation to merge with enforced agent swarms for higher quality results.

Arguments: $ARGUMENTS

---

## Overview

`/claude-harness:flow` is the unified development command. All workflows (standard, TDD, batch, planning) run through this single entry point with flags:

```
/claude-harness:flow "Add dark mode support"           # Standard workflow
/claude-harness:flow --tdd "Add auth system"           # TDD: tests first
/claude-harness:flow --autonomous                      # Batch process all features
/claude-harness:flow --plan-only "Big refactor"        # Plan only, implement later
```

**Lifecycle Phases**:
1. **Context** - Auto-compile memory
2. **Creation** - GitHub issue, branch, feature entry
3. **Planning** - Architecture analysis, approach selection
4. **Agent Pipeline** - Auto-select specialized agents based on complexity
5. **Implementation** - Agent-driven: Research → Implement → Review
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

## Phase 0: Argument Parsing

1. **Parse arguments**:
   - If empty: Show interactive menu with `multiSelect: true` for parallel feature selection
   - If matches `feature-\d+`: Resume existing feature
   - If matches `fix-feature-\d+-\d+`: Resume existing fix
   - If `--fix <feature-id> "description"`: Create fix linked to feature
   - Otherwise: Create new feature from description

2. **Parse options**:
   - `--no-merge`: Skip automatic merge phase (stop at checkpoint)
   - `--quick`: Skip planning phase
   - `--inline`: Skip worktree creation
   - `--tdd`: Enforce TDD (RED-GREEN-REFACTOR). Tests must exist before implementation code.
   - `--plan-only`: Stop after Phase 3 (planning). Resume later with feature ID.
   - `--autonomous`: Outer loop mode - iterate through all active features with TDD, checkpoint, merge, repeat

3. **Mode validation**:
   - If `--autonomous`: Force `--inline`, compatible with `--no-merge` and `--quick`. **Proceed to Autonomous Wrapper.**
   - If `--plan-only`: Compatible with `--tdd`. Proceeds through Phases 0-3 then STOPS.
   - If `--tdd` (without `--autonomous`): Enables TDD phases in Phase 4 (see Phase 4.1).

---

## Phase 0.5: Multi-Select Parallel Spawning

**When user selects 2+ features from interactive menu** (empty args with multiSelect):

3.5. **Create worktrees and spawn parallel agents**:
   - For each selected feature:
     - Create git worktree: `git worktree add ../repo-{feature-id} feature/{feature-id}`
     - Spawn background subagent via Task tool:
       ```
       subagent_type: "general-purpose"
       run_in_background: true
       prompt: |
         You are implementing a feature in a parallel development session.
         Feature ID: {feature-id}
         Worktree Path: {absolute-path}
         Branch: feature/{feature-id}

         1. cd {worktree-path}
         2. Read feature from .claude-harness/features/active.json
         3. Run the full flow pipeline including agent stages:
            - Explore agent for research
            - Domain-specific implementation agent(s)
            - Code-reviewer agent for review
         4. Run all verification commands
         5. Commit + push + create PR

         You MUST use specialized agents for implementation.
         Do NOT skip the research or review steps.
       ```
   - Display spawning status:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  PARALLEL AGENTS SPAWNED                                       │
     │  Feature         Worktree                      Task ID         │
     │  ─────────────────────────────────────────────────────────────  │
     │  feature-001     ../repo-feature-001/          {task-id-1}     │
     │  feature-002     ../repo-feature-002/          {task-id-2}     │
     │                                                                │
     │  Agents running in background.                                 │
     │  Check progress: /tasks or TaskOutput tool                     │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - **Return control to user** - agents continue working independently
   - **EXIT flow** (each subagent handles its own full lifecycle)

---

## Autonomous Wrapper (if --autonomous)

When `--autonomous` is set, the entire flow operates as an outer agentic loop that iterates through all active features. Each feature goes through the full lifecycle (context → planning → TDD implementation → checkpoint → merge) before moving to the next.

**IMPORTANT**: This wrapper replaces the normal Phase 1-7 flow. Each iteration runs the standard phases internally with TDD enforcement.

### Autonomous Effort Controls

| Phase | Effort | Why |
|-------|--------|-----|
| Feature Selection / Conflict Detection | low | Mechanical git operations and list filtering |
| Context Compilation | low | Mechanical data loading |
| TDD Test Planning | high | Requires understanding feature behavior to design tests |
| RED (write failing tests) | high | Must define expected behavior precisely |
| GREEN (implement to pass tests) | high | Core coding work, escalate to max on retry |
| REFACTOR | max | Deep structural analysis benefits most from max reasoning |
| Verification / Debug | max | Root-cause analysis needs deepest reasoning |
| Checkpoint / Merge | low | Mechanical commit/push/merge operations |

Progressive escalation on retries (per feature): Attempts 1-5: high. Attempts 6-10: max. Attempts 11-15: max + full procedural memory.

---

### Phase A.1: Initialize Autonomous State

4. **Read feature backlog**:
   - Detect worktree mode and set paths (same as Phase 1 step 3)
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
     - Resume from where it left off (skip already completed features)
   - If file does not exist: create fresh state (step 6)

6. **Create autonomous state file**:
   - Write to `.claude-harness/sessions/{session-id}/autonomous-state.json`:
     ```json
     {
       "version": 1,
       "mode": "autonomous",
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

10. **Re-read feature backlog**:
    - Read `${FEATURES_FILE}` (may have changed after merges from prior iterations)
    - Filter features where:
      - `status` is NOT `"passing"`
      - `id` is NOT in `skippedFeatures` list
      - `id` is NOT in `failedFeatures` list
    - If no eligible features remain: **proceed to Phase A.7** (completion report)

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

### Phase A.4: Execute Feature Flow with TDD

This phase runs the standard flow Phases 1-7 with TDD enforcement and autonomous overrides.

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

#### A.4.3: TDD Planning

18. **Run Phase 3** (Planning) unless `--quick`:
    - Standard planning steps (query procedural memory, analyze requirements, generate plan)

19. **Inject TDD test planning** (MANDATORY in autonomous mode):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  TDD: Generating Test Specifications for {feature-id}         │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Analyze feature requirements
    - Auto-detect test patterns for project language:
      - TypeScript: `**/*.test.ts`, `**/*.spec.ts`, `**/__tests__/**`
      - JavaScript: `**/*.test.js`, `**/*.spec.js`, `**/__tests__/**`
      - Python: `**/test_*.py`, `**/*_test.py`, `**/tests/**`
      - Go: `**/*_test.go`
      - Shell/Bash: `**/test_*.sh`, `**/*_test.sh`
    - Generate test specifications with tests as FIRST steps:
      ```json
      {
        "steps": [
          {"step": 1, "type": "test", "phase": "red", "description": "Write failing test for X"},
          {"step": 2, "type": "test", "phase": "red", "description": "Write failing test for Y"},
          {"step": 3, "type": "implementation", "phase": "green", "description": "Implement X"},
          {"step": 4, "type": "implementation", "phase": "green", "description": "Implement Y"},
          {"step": 5, "type": "refactor", "phase": "refactor", "description": "Refactor if needed"}
        ]
      }
      ```
    - Store test plan in feature entry or session context

20. **Create task chain** (Phase 3.5) with TDD-specific tasks:
    - Task 1: "Research {feature}" - activeForm: "Researching {feature}"
    - Task 2: "Plan {feature} (TDD)" - activeForm: "Planning TDD for {feature}"
    - Task 3: "Write tests for {feature} (RED)" - activeForm: "Writing failing tests"
    - Task 4: "Implement {feature} (GREEN)" - activeForm: "Implementing to pass tests"
    - Task 5: "Refactor {feature}" - activeForm: "Refactoring {feature}"
    - Task 6: "Verify {feature}" - activeForm: "Verifying {feature}"
    - Task 7: "Checkpoint {feature}" - activeForm: "Creating checkpoint"
    - **REQUIRED**: If TaskCreate fails, retry once. If still failing, log error and continue with manual tracking in loop-state.

#### A.4.4: TDD Implementation (RED-GREEN-REFACTOR)

**Branch verification** (MANDATORY):
```bash
CURRENT_BRANCH=$(git branch --show-current)
```
- **STOP if on main/master** - fetch and checkout feature branch

21. **Initialize loop state** (v5 with TDD + agent tracking):
    - Write to `.claude-harness/sessions/{session-id}/loop-state.json`:
      ```json
      {
        "version": 5,
        "feature": "{feature-id}",
        "featureName": "{description}",
        "type": "feature",
        "status": "in_progress",
        "attempt": 1,
        "maxAttempts": 15,
        "startedAt": "{ISO timestamp}",
        "history": [],
        "tdd": {
          "enabled": true,
          "phase": null,
          "testsWritten": [],
          "testStatus": null
        },
        "agents": {
          "enabled": true,
          "complexity": "{auto-detected}",
          "pipeline": ["{from agent assessment}"],
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

22. **TDD Phase: RED (Write Failing Tests)** (effort: high):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  RED PHASE: Write Failing Tests for {feature-id}              │
    ├─────────────────────────────────────────────────────────────────┤
    │  Write tests that define the expected behavior.                │
    │  Tests MUST fail initially (no implementation yet).            │
    └─────────────────────────────────────────────────────────────────┘
    ```

    **Step 22a: Write test files** (agent-assisted):
    - Spawn Explore agent to research test patterns in the project
    - Spawn qa-expert agent to write test files based on TDD test plan (step 19)
    - Tests should cover: unit tests, integration tests, edge cases

    **Step 22b: Verify tests FAIL (correct RED state)**
    - Run test command
    - If tests **FAIL**: Correct! Proceed to GREEN phase
    - If tests **PASS** without implementation:
      - Log warning: "Tests pass without implementation - may be too trivial or over-mocking"
      - In autonomous mode: continue anyway (don't prompt)
    - Update TDD state: `tdd.phase = "red"`, `tdd.testStatus = "failing"`
    - Update `tddStats.totalTestsWritten` in autonomous state

23. **TDD Phase: GREEN (Minimal Implementation)** (effort: high, escalate to max):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  GREEN PHASE: Make Tests Pass for {feature-id}                │
    ├─────────────────────────────────────────────────────────────────┤
    │  Write the MINIMAL code needed to make tests pass.             │
    │  Don't over-engineer. Don't optimize yet.                      │
    └─────────────────────────────────────────────────────────────────┘
    ```

    - **Agent pipeline applies**: Use the 3-stage pipeline (Research → Implement → Review) from Phase 4.2
    - Explore agent researches, domain agent(s) implement minimal code, code-reviewer validates
    - Run ALL verification commands (build, tests, lint, typecheck)
    - **If tests PASS**:
      - Update TDD state: `tdd.phase = "green"`, `tdd.testStatus = "passing"`
      - Proceed to REFACTOR phase
    - **If tests FAIL**:
      - Record approach to history and to `${MEMORY_DIR}/procedural/failures.json`
      - Increment attempt counter
      - Retry with different approach (up to maxAttempts)
      - **Effort escalation**: If attempt > 5, use max effort. If attempt > 10, also load full procedural memory.

24. **TDD Phase: REFACTOR (Improve Code Quality)** (effort: max):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  REFACTOR PHASE: Improve Code Quality for {feature-id}        │
    ├─────────────────────────────────────────────────────────────────┤
    │  Tests pass. Improve code while keeping tests green.           │
    └─────────────────────────────────────────────────────────────────┘
    ```

    - In autonomous mode: always attempt refactoring (don't prompt)
    - Spawn code-reviewer agent: "Analyze implementation for refactoring opportunities"
    - Apply suggested improvements: remove duplication, improve naming, simplify logic
    - Run tests after EACH refactoring change
    - **If tests break during refactoring**: Revert that specific change and stop refactoring
    - Update TDD state: `tdd.phase = "refactor"`

25. **Final Verification Gate** (MANDATORY):
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

26. **On escalation** (maxAttempts reached in autonomous mode):
    - Do NOT prompt user - autonomous mode handles this automatically
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

27. **Run Phase 5** (Auto-Checkpoint) normally:
    - Update progress file
    - Persist to memory layers (episodic, semantic, procedural, learned)
    - Commit with TDD suffix: `feat({feature-id}): {description} [TDD]`
    - Push to remote
    - Create/update PR with TDD note in body

#### A.4.6: Auto-Merge (unless --no-merge)

28. **Run Phase 6** (Auto-Merge) unless `--no-merge`:
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
    - Reset loop-state.json to idle (v5 schema)
    - Clear TDD state, agent pipeline state
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

3. **Detect worktree mode and set paths**:
   ```bash
   GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
   GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)

   if [ "$GIT_COMMON_DIR" != ".git" ] && [ "$GIT_COMMON_DIR" != "$GIT_DIR" ]; then
       IS_WORKTREE=true
       MAIN_REPO_PATH=$(dirname "$GIT_COMMON_DIR")
       FEATURES_FILE="${MAIN_REPO_PATH}/.claude-harness/features/active.json"
       MEMORY_DIR="${MAIN_REPO_PATH}/.claude-harness/memory/"
   else
       IS_WORKTREE=false
       FEATURES_FILE=".claude-harness/features/active.json"
       MEMORY_DIR=".claude-harness/memory/"
   fi
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

12. **Handle worktree** (unless --inline):
    - If NOT --inline: Create worktree and display instructions to continue in worktree
    - If --inline: Continue in current directory
    - **Note**: For /flow, prefer --inline for seamless automation

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

## Phase 3.7: Agent Pipeline Planning (MANDATORY)

**Every feature uses specialized agents for implementation.** This phase auto-detects complexity and builds the agent pipeline.

15.8. **Assess feature complexity** (auto-detect from Phase 3 plan):
   - Count estimated files to modify
   - Identify file types and domains (frontend, backend, database, etc.)
   - Check for security-sensitive operations (auth, tokens, encryption)
   - Calculate complexity:
     - **Simple** (1-2 files, single domain, no security concerns)
     - **Standard** (3-5 files, or 2+ domains, or any security concern)
     - **Complex** (6+ files, or 3+ domains, or database migrations)

15.9. **Build agent pipeline** based on complexity:

   **Simple (agent-lite) - 2 agents minimum:**
   - Stage 1: Explore agent (`subagent_type: Explore`) - research codebase patterns
   - Stage 2: Implement + code-reviewer for post-implementation review

   **Standard (agent-standard) - 3+ agents:**
   - Stage 1: Explore agent - research codebase patterns and dependencies
   - Stage 2: Domain-specific implementation agent(s) (parallel if independent files)
   - Stage 3: code-reviewer, plus security-auditor if security-sensitive

   **Complex (agent-full) - 4+ agents:**
   - Stage 1: Explore agent - deep research
   - Stage 2: Plan agent (`subagent_type: Plan`) - architecture design from research
   - Stage 3: Domain-specific implementation agent(s) (parallel where possible)
   - Stage 4: code-reviewer + qa-expert + security-auditor (if applicable)

   **Domain agent selection matrix:**
   | Domain | subagent_type | Triggers |
   |--------|---------------|----------|
   | React/Frontend | react-specialist | .tsx, .jsx, component, UI |
   | Backend/API | backend-developer | route.ts, api/, endpoint, REST |
   | Next.js | nextjs-developer | app/, pages/, Next.js specific |
   | Database | database-administrator | prisma, schema, migration, SQL |
   | Python | python-pro | .py files |
   | TypeScript | typescript-pro | complex type work, generics |
   | Go | golang-pro | .go files |
   | Rust | rust-engineer | .rs files |
   | Shell/Bash | general-purpose | .sh files |

   **Quality agents:**
   | Type | subagent_type | When to include |
   |------|---------------|-----------------|
   | Review | code-reviewer | Always for standard/complex |
   | Security | security-auditor | Auth, tokens, encryption, API keys |
   | Testing | qa-expert | When `--tdd` flag is set |
   | Performance | performance-engineer | Performance-critical code |

   **Effort levels per agent role** (Opus 4.6+):
   | Agent Role | Effort | Why |
   |------------|--------|-----|
   | Explore (research) | high | Exploration needs careful analysis |
   | Plan (architecture) | max | Architecture decisions are critical |
   | Implementation agents | high | Core coding work |
   | code-reviewer | max | Review requires deepest reasoning to catch issues |
   | security-auditor | max | Security analysis must be thorough |
   | qa-expert | high | Test design needs good reasoning |

15.10. **Store agent pipeline in loop state**:
    - Add to loop-state (v5 schema, see step 17):
      ```json
      {
        "agents": {
          "enabled": true,
          "complexity": "simple|standard|complex",
          "pipeline": [
            {"stage": 1, "role": "explore", "subagent_type": "Explore", "status": "pending"},
            {"stage": 2, "role": "implement", "subagent_type": "{detected}", "status": "pending"},
            {"stage": 3, "role": "review", "subagent_type": "code-reviewer", "status": "pending"}
          ],
          "results": [],
          "reviewCycles": 0
        }
      }
      ```

15.11. **Display agent pipeline**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  AGENT PIPELINE: {complexity}                                   │
    │  Stage 1: Explore → Stage 2: Implement → Stage 3: Review       │
    │  Agents: {N} specialized agents selected                        │
    │  Domains: {detected domains}                                    │
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
    │  Agent Pipeline: {complexity} ({N} agents)                      │
    │  TDD: {enabled/disabled}                                        │
    ├─────────────────────────────────────────────────────────────────┤
    │  Resume: /claude-harness:flow feature-XXX                       │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - **EXIT** - do not proceed to Phase 4

---

## Phase 4: Implementation (Agent-Driven)

**IMPORTANT**: Implementation MUST use the agent pipeline from Phase 3.7. Direct inline implementation without agents is NOT permitted.

16. **Branch verification** (MANDATORY):
    ```bash
    CURRENT_BRANCH=$(git branch --show-current)
    ```
    - **STOP if on main/master**
    - Fetch and checkout correct branch if needed

17. **Initialize loop state** (v5 with agent + TDD + task integration):
    - Write to `.claude-harness/sessions/{session-id}/loop-state.json`:
      ```json
      {
        "version": 5,
        "feature": "feature-XXX",
        "featureName": "{description}",
        "type": "feature",
        "status": "in_progress",
        "attempt": 1,
        "maxAttempts": 15,
        "startedAt": "{ISO timestamp}",
        "history": [],
        "tdd": {
          "enabled": false,
          "phase": null,
          "testsWritten": [],
          "testStatus": null
        },
        "agents": {
          "enabled": true,
          "complexity": "{from Phase 3.7}",
          "pipeline": ["{from Phase 3.7}"],
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
    - Set `tdd.enabled = true` if `--tdd` flag is set
    - **Backward compatible**: If tasks.enabled is false or missing, ignore task integration

17.5. **Update task status** (if tasks enabled):
    - Call `TaskUpdate` to mark "Implement" task (Task 3) as "in_progress"
    - Display task progress:
      ```
      Tasks: [✓] Research [✓] Plan [→] Implement [ ] Verify [ ] Checkpoint
      ```

---

### Phase 4.1: TDD Phases (if --tdd)

**Only executes when `--tdd` flag is set.** Inserts RED-GREEN-REFACTOR before standard agent implementation.

17.6. **TDD Phase: RED (Write Failing Tests)** (effort: high):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  RED PHASE: Write Failing Tests for {feature-id}               │
    ├─────────────────────────────────────────────────────────────────┤
    │  Write tests that define the expected behavior.                 │
    │  Tests MUST fail initially (no implementation yet).             │
    └─────────────────────────────────────────────────────────────────┘
    ```

    **Step 17.6a: Research test patterns** (agent-assisted):
    - Spawn Explore agent: "Research test patterns, conventions, and fixtures used in this project"
    - Auto-detect test patterns for project language:
      - TypeScript: `**/*.test.ts`, `**/*.spec.ts`, `**/__tests__/**`
      - JavaScript: `**/*.test.js`, `**/*.spec.js`, `**/__tests__/**`
      - Python: `**/test_*.py`, `**/*_test.py`, `**/tests/**`
      - Go: `**/*_test.go`
      - Shell/Bash: `**/test_*.sh`, `**/*_test.sh`

    **Step 17.6b: Write test files** (agent-assisted):
    - Spawn qa-expert agent: "Write failing tests for {feature-name} based on acceptance criteria and project test patterns"
    - Tests should cover: unit tests, integration tests, edge cases

    **Step 17.6c: Verify tests FAIL (correct RED state)**:
    - Run test command
    - If tests **FAIL**: Correct! Update `tdd.phase = "red"`, `tdd.testStatus = "failing"`
    - If tests **PASS** without implementation: Log warning, continue
    - **Existence gate**: Test files MUST exist before proceeding to GREEN phase

17.7. **TDD Phase: GREEN** - Proceeds to standard agent implementation (step 18) with constraint: write MINIMAL code to make tests pass. Do not over-engineer.

17.8. **TDD Phase: REFACTOR** (after step 18 verification passes):
    - Spawn code-reviewer agent: "Analyze implementation for refactoring opportunities: duplication, naming, unnecessary complexity"
    - Apply suggested improvements
    - Run tests after EACH refactoring change
    - **If tests break during refactoring**: Revert that specific change and stop refactoring
    - Update `tdd.phase = "refactor"`
    - Commit suffix: `feat(feature-XXX): {description} [TDD]`

---

### Phase 4.2: Agent-Driven Implementation Loop

18. **Execute agent-driven implementation** (effort: high, escalate to max on failure):

    **REQUIRED**: Implementation MUST use the agent pipeline from Phase 3.7.

    **Stage 1: Research Agent** (REQUIRED for all complexity levels):
    - Spawn Explore agent via Task tool:
      - `subagent_type`: "Explore"
      - Prompt: "Research the codebase for {feature-name}. Find existing patterns, conventions, related files, and dependencies. Report: (1) files to modify, (2) patterns to follow, (3) potential pitfalls, (4) test patterns."
    - Wait for result
    - **Validation gate**: Result MUST contain files list AND patterns. If empty: retry once with more specific prompt.
    - Store research output in loop state `agents.results[]`
    - Update pipeline stage 1 status to "completed"

    **Stage 2: Implementation Agent(s)** (REQUIRED):
    - For each implementation agent in the pipeline:
      - Spawn via Task tool with appropriate `subagent_type`
      - Include in prompt:
        - Research results from Stage 1
        - Plan from Phase 3
        - Past failures to avoid (from procedural memory)
        - If `--tdd`: "Write MINIMAL code to make tests pass. Do NOT over-engineer."
      - Prompt template:
        ```
        You are the {role} specialist implementing {feature-name}.

        ## Research Context (from exploration agent)
        {Stage 1 results}

        ## Implementation Plan
        {Phase 3 plan steps}

        ## Past Failures to Avoid
        {from procedural memory}

        ## Your Task
        {specific implementation instructions}

        ## Files to Modify
        {from research + plan}

        ## REQUIRED Output Format
        Report: files_modified (list), files_created (list), approach_taken (string), tests_added (boolean), issues_encountered (list)
        ```
    - If multiple implementation agents (different domains): spawn in PARALLEL (single message, multiple Task calls)
    - Wait for all results
    - **Validation gate**: Each agent MUST report files_modified. Log warning for empty results.
    - Store outputs in loop state `agents.results[]`
    - Update pipeline stage 2 status to "completed"

    **Stage 3: Review Agent** (REQUIRED for standard/complex, recommended for simple):
    - Spawn code-reviewer agent via Task tool:
      - Include: all files modified by Stage 2, feature requirements, acceptance criteria
      - Prompt: "Review the following changes for {feature-name}. Check for: correctness, edge cases, error handling, consistency with codebase patterns, security issues. Report: issues_found (list with severity), suggestions (list), approved (boolean)."
    - If security-sensitive: ALSO spawn security-auditor in parallel
    - Wait for review results
    - **Validation gate**: Review agent MUST return approved: true/false
    - If review finds critical issues (severity: high):
      - Feed issues back to implementation agent for a fix pass
      - Re-run review (max 2 review cycles, tracked in `agents.reviewCycles`)
    - Store review output in loop state `agents.results[]`
    - Update pipeline stage 3 status to "completed"

    **Agent handoff management:**
    - Pass previous agent's results as context to next agent
    - Track agent results in `.claude-harness/agents/context.json`
    - On agent failure: retry once, then try secondary agent from same category, then STOP and report

    **Post-agent verification**: Run ALL verification commands (build, test, lint, typecheck)
    - **Effort escalation**: If attempt > 5, use max effort. If attempt > 10, also load full procedural memory.

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
      - Try different approach (up to maxAttempts)

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
      - **Proceed to Phase 5 (Checkpoint)**

20. **On escalation** (max attempts reached):
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
| `/claude-harness:flow "Add X"` | Full lifecycle: agents → implement → checkpoint → merge |
| `/claude-harness:flow feature-XXX` | Resume existing feature from current phase |
| `/claude-harness:flow --tdd "Add X"` | TDD: RED-GREEN-REFACTOR with agent assistance |
| `/claude-harness:flow --no-merge "Add X"` | Stop at checkpoint (don't auto-merge) |
| `/claude-harness:flow --quick "Simple fix"` | Skip planning phase |
| `/claude-harness:flow --inline "Tiny change"` | Skip worktree (work in current dir) |
| `/claude-harness:flow --plan-only "Big feature"` | Plan only, implement later with feature ID |
| `/claude-harness:flow --fix feature-001 "Bug"` | Create and complete a bug fix |
| `/claude-harness:flow --autonomous` | Batch process all active features with TDD |
| `/claude-harness:flow --autonomous --no-merge` | Batch process, stop each at checkpoint |
| `/claude-harness:flow --autonomous --quick` | Autonomous without planning (TDD still enforced) |

**Flag combinations:**
- `--tdd --no-merge`: TDD workflow, stop at PR creation
- `--tdd --plan-only`: Plan TDD approach, implement later
- `--quick --inline`: Fastest path for trivial changes
- `--autonomous --no-merge --quick`: Fast batch processing without merge

---

## When to Use Each Mode

| Mode | Use Case |
|------|----------|
| Default (`/flow "desc"`) | Standard feature with auto agent pipeline |
| `--tdd` | Features where test coverage is critical |
| `--no-merge` | When you want to review PR before merging |
| `--plan-only` | Complex features that need upfront design review |
| `--quick` | Simple fixes where planning is overhead |
| `--inline` | Quick changes that don't need worktree isolation |
| `--autonomous` | Batch processing an entire feature backlog unattended |
| Empty args (menu) | Select multiple features for parallel agent spawning |
