---
description: Unified end-to-end workflow - creates, implements, checkpoints, and merges features automatically
argument-hint: "DESCRIPTION" | FEATURE-ID | --fix FEATURE-ID "bug description" | --autonomous | --plan-only
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
```

**Lifecycle**: Context → Creation → Planning → Implementation → Verification → Checkpoint → Merge

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

3. **Mode validation**:
   - `--autonomous`: Compatible with `--no-merge` and `--quick`. Proceed to Autonomous Wrapper.
   - `--plan-only`: Proceeds through Phases 0-3 then STOPS.

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
26. Run Phase 5: update progress, persist memory, commit `feat({feature-id}): {description}`, push, create/update PR.

#### A.4.6: Auto-Merge (unless --no-merge)
27. Run Phase 6: check PR status, merge if ready (squash), close issue, delete branch, archive feature. If needs review: mark checkpointed, continue.

---

### Phase A.5: Post-Feature Cleanup

28. **Archive completed feature**: If status "passing", archive to archive.json and remove from active.json. Otherwise skip.

29. **Update autonomous state**: Add to `completedFeatures`, reset `consecutiveFailures`.

30. Switch to main: `git checkout main && git pull origin main`

31. **Reset session state**: Clear loop-state, task references.

32. **Brief per-feature report**: feature ID, test counts, PR status, attempts, duration, progress.

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

9. **Create GitHub Issue**: `mcp__github__create_issue` with labels `["feature", "claude-harness", "flow"]`, body with Problem/Solution/Acceptance/Verification. STOP if fails.

10. **Create and checkout branch**: `mcp__github__create_branch`, then `git fetch origin && git checkout feature/feature-XXX`. Verify branch.

11. **Create feature entry** in active.json: id, name, status "in_progress", github refs, verificationCommands, maxAttempts 15.

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

## Phase 3.8: Plan-Only Gate (if --plan-only)

If `--plan-only`: display plan summary (feature ID, issue, branch) with resume command and **EXIT**.

---

## Phase 4: Implementation

16. **Branch verification**: `git branch --show-current` — STOP if on main/master.

17. **Initialize loop state** (canonical Loop-State Schema v8):
    ```json
    {
      "version": 8,
      "feature": "feature-XXX", "featureName": "{description}",
      "type": "feature", "status": "in_progress",
      "attempt": 1, "maxAttempts": 15,
      "startedAt": "{ISO}", "history": [],
      "tasks": { "enabled": true, "chain": ["{task-ids}"], "current": null, "completed": [] }
    }
    ```

17.5. Update task status: mark Implement task as in_progress.

18. **Implement the feature** directly based on the plan from Phase 3:
    - Follow test-driven practices where applicable (write/update tests, then implement)
    - Run verification commands after implementation
    - On failure: record to failures.json, increment attempts, retry with escalation

---

### Phase 4.1: Verification and Memory Updates

19. **Streaming memory updates** after each verification attempt:
    - Fail: append to failures.json (id, feature, approach, errors, rootCause), increment attempts, retry
    - Pass: append to successes.json (id, feature, approach, files, patterns), mark loop "completed", update tasks (mark Implement/Verify/Accept completed, Checkpoint in_progress)

20. **On escalation** (max attempts): show summary, offer options (increase attempts, get help, abort). Do NOT checkpoint.

---

## Phase 5: Auto-Checkpoint

Triggers when verification passes.

21. Update `.claude-harness/claude-progress.json`
22. Persist to memory layers in parallel (episodic, semantic, learned)
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

**Flag combinations**: `--no-merge --plan-only` (plan before implementing), `--autonomous --no-merge --quick` (fast batch without merge)

---

## When to Use Each Mode

| Mode | Use Case |
|------|----------|
| Default (`/flow "desc"`) | Standard feature development |
| `--no-merge` | Review PR before merging |
| `--plan-only` | Complex features needing upfront design |
| `--quick` | Simple fixes — skips planning |
| `--autonomous` | Batch processing feature backlog unattended |
