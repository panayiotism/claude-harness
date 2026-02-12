---
description: Unified end-to-end workflow - creates, implements, checkpoints, and merges features automatically
argument-hint: "DESCRIPTION" | FEATURE-ID | --fix FEATURE-ID "bug description" | --autonomous | --plan-only
---

The single command for all development workflows. Handles the entire feature lifecycle from creation to merge with Agent Teams orchestration (test-writer, implementer, reviewer specialists).

Arguments: $ARGUMENTS

---

## Overview

`/claude-harness:flow` is the unified development command. All workflows run through this single entry point with flags:

```
/claude-harness:flow "Add dark mode support"           # Standard workflow
/claude-harness:flow --autonomous                      # Batch process all features
/claude-harness:flow --plan-only "Big refactor"        # Plan only, implement later
```

**Lifecycle**: Context → Creation → Planning → Team Setup → TDD (RED→GREEN→REFACTOR→ACCEPT) → Checkpoint → Merge

---

## Effort Controls (Opus 4.6+)

Opus 4.6 supports effort levels (low/medium/high/max). Apply per phase:

| Phase | Effort | Why |
|-------|--------|-----|
| Context Compilation | low | Mechanical data loading |
| Feature Creation / Selection / Conflict Detection | low | Template-based, deterministic |
| Planning / Test Planning | max | Determines approach quality, avoids past failures |
| RED (test-writer writes tests) | high | Must define expected behavior precisely |
| GREEN (implementer passes tests) | high | Core coding, escalate to max on retry |
| REFACTOR (reviewer validates) | max | Deep structural analysis |
| ACCEPT (reviewer E2E verification) | max | Deterministic acceptance checks need deep reasoning |
| Verification / Debug | max | Root-cause analysis needs deepest reasoning |
| Checkpoint / Merge | low | Mechanical operations |

**Adaptive Escalation** (progressive on retries): Attempts 1-5: high. Attempts 6-10: max. Attempts 11-15: max + full procedural memory.

On models without effort controls, all phases run at default effort.

---

## Phase 0: Preflight Check

**BLOCKER**: Verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set to `1`. If NOT: display blocker message referencing `/claude-harness:setup` and **STOP**.

---

## Phase 0.1: Argument Parsing

1. **Parse arguments**:
   - Empty: Show interactive menu with `multiSelect: true` for parallel feature selection
   - Matches `feature-\d+`: Resume existing feature
   - Matches `fix-feature-\d+-\d+`: Resume existing fix
   - `--fix <feature-id> "description"`: Create fix linked to feature
   - Otherwise: Create new feature from description

2. **Parse options**:
   - `--no-merge`: Skip merge phase (stop at checkpoint)
   - `--quick`: Implements directly without team creation or TDD phases
   - `--plan-only`: Stop after Phase 3. Resume later with feature ID.
   - `--autonomous`: Outer loop — iterate all active features with team per feature

3. **Mode validation**:
   - `--autonomous`: Compatible with `--no-merge` and `--quick`. Proceed to Autonomous Wrapper.
   - `--plan-only`: Proceeds through Phases 0-3 then STOPS.

**Note**: TDD (RED-GREEN-REFACTOR-ACCEPT) is always-on. The 3-specialist team structure enforces TDD by design. No `--tdd` flag needed.

---

## Phase 0.5: Multi-Select Parallel Team

When user selects 2+ features from interactive menu (empty args with multiSelect):

- Create agent team: `"{project}-parallel-{timestamp}"`
- Lead enters **delegate mode** (coordinates only)
- For each selected feature, spawn a teammate with prompt:
  - Checkout branch, read feature from active.json
  - Execute full TDD lifecycle (RED→GREEN→REFACTOR)
  - Run verification, commit + push + create PR
  - Coordination rules: message teammates about shared utilities, don't modify files outside scope
- Create shared tasks, display team status
- Lead monitors via `TeammateIdle` notifications
- When all complete: shut down teammates, clean up team

---

## Autonomous Wrapper (if --autonomous)

When `--autonomous` is set, the flow operates as an outer loop iterating all active features. Each feature gets a specialist team (test-writer, implementer, reviewer), runs TDD, then cleans up before moving to the next.

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
   - If exists: display resume summary, migrate v1→v2 schema if needed (add `leadMode`/`leadModeRule`), re-assert delegation rule
   - If not exists: create fresh state (step 6)

6. **Create autonomous state file** at `.claude-harness/sessions/{session-id}/autonomous-state.json`:
   ```json
   {
     "version": 2,
     "mode": "autonomous",
     "leadMode": "delegate",
     "leadModeRule": "Lead coordinates ONLY. Do NOT write code, do NOT modify source files. ALWAYS create an Agent Team with 3 specialists and delegate all work.",
     "startedAt": "{ISO timestamp}",
     "iteration": 0, "maxIterations": 20,
     "consecutiveFailures": 0, "maxConsecutiveFailures": 3,
     "completedFeatures": [], "skippedFeatures": [], "failedFeatures": [],
     "currentFeature": null,
     "tddStats": { "totalTestsWritten": 0, "totalTestsPassing": 0, "featuresWithTDD": 0, "acceptanceTestsRun": 0, "acceptanceTestsPassing": 0 }
   }
   ```

7. **Parse and cache GitHub repo** (reuse across iterations):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   ```

8. **Read all memory layers IN PARALLEL**: failures.json, successes.json, decisions.json, rules.json

9. **Display autonomous banner** showing: feature count, delegate mode, TDD enforced, max iterations, merge/planning mode, GitHub info, memory stats.

---

### Phase A.2: Feature Selection (LOOP START)

10. **Re-read feature backlog AND delegation mode**:
    - Read `${FEATURES_FILE}`, filter eligible features (not passing/skipped/failed)
    - If none remain: proceed to Phase A.7
    - Re-read `leadMode` from autonomous-state.json (compaction defense). Assert delegate mode.

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

### Phase A.4: Execute Feature Flow with Team

Runs standard Phases 1-7 with specialist team per feature and autonomous overrides.

#### A.4.1: Context Compilation
16. Run Phase 1 normally (reuse GitHub/memory from A.1). Write context.json.

#### A.4.2: Feature Creation (conditional)
17. Skip if feature already exists with status `pending` or `in_progress`. Otherwise run Phase 2.

#### A.4.3: Planning
18. Run Phase 3 unless `--quick`. Create task chain (8 tasks for autonomous: Research, Plan, Write tests RED, Implement GREEN, Review REFACTOR, Accept E2E, Verify, Checkpoint). If TaskCreate fails, retry once then fall back to manual tracking.

#### A.4.4: Team-Driven Implementation (RED-GREEN-REFACTOR-ACCEPT)

**Branch verification**: `git branch --show-current` — STOP if on main/master.

**DELEGATION CHECK**: Read `leadMode` from autonomous-state.json. Must be `"delegate"`. Self-heal if missing. Do NOT implement directly — spawn the team.

21. **Initialize loop state** — see canonical Loop-State Schema (Phase 4, step 17).

22. **Create team and spawn specialists**: team `"{project}-{feature-id}"`, delegate mode, spawn test-writer/implementer/reviewer with context. Require plan approval.

23. **RED** (effort: high): Assign test-writer. Tests must exist and FAIL. Update `tdd.phase = "red"`.

24. **GREEN** (effort: high→max): Message implementer with test paths. Direct collaboration with test-writer allowed. Run all verification. On failure: record to failures.json, increment attempts, retry with escalation.

25. **REFACTOR** (effort: max): Reviewer reviews, messages implementer directly (no lead intermediation). Max 2 rounds. Run tests after each change; revert if broken. Update `tdd.phase = "refactor"`.

25.5. **ACCEPT** (effort: max): Reviewer writes/runs deterministic acceptance tests verifying feature end-to-end. Workflow: read acceptance criteria → design scenarios (HTTP→response, CLI→stdout, API→return value, etc.) → write test files → run via `verification.acceptance` or standard runner. On pass: update `tdd.acceptanceStatus = "passing"`, proceed. On fail: reviewer↔implementer direct dialogue (max 2 rounds), run unit tests after each fix. If exceeded in autonomous: log warning, mark partial, proceed. Record results to procedural memory.

26. **Final Verification Gate**: Run ALL verification commands. Record success to successes.json. Update loop status to `"completed"`.

27. **Team cleanup**: Shut down teammates, clean up team.

28. **On escalation** (maxAttempts reached): shut down team, add to `failedFeatures`, increment `consecutiveFailures`, record to procedural memory, proceed to A.5→A.6.

#### A.4.5: Auto-Checkpoint
29. Run Phase 5: update progress, persist memory, commit `feat({feature-id}): {description}`, push, create/update PR.

#### A.4.6: Auto-Merge (unless --no-merge)
30. Run Phase 6: check PR status, merge if ready (squash), close issue, delete branch, archive feature. If needs review: mark checkpointed, continue.

---

### Phase A.5: Post-Feature Cleanup

29. **Archive completed feature**: If status "passing", archive to archive.json and remove from active.json. Otherwise skip.

30. **Update autonomous state**: Add to `completedFeatures`, update `tddStats`, reset `consecutiveFailures`.

31. Switch to main: `git checkout main && git pull origin main`

32. **Reset session state**: Clear loop-state, TDD state, team state, task references.

33. **Brief per-feature report**: feature ID, TDD phases, test counts, PR status, attempts, duration, progress.

---

### Phase A.6: Loop Continuation Check

34. **Check termination conditions** (in order):
    1. No eligible features remaining → Phase A.7
    2. `iteration` reached `maxIterations` (20) → Phase A.7
    3. `consecutiveFailures` reached `maxConsecutiveFailures` (3) → Phase A.7
    4. All remaining features skipped/failed → Phase A.7

35. **If continuing**: write state, re-read `leadModeRule` (compaction defense), go back to A.2.

---

### Phase A.7: Autonomous Completion Report

36. **Generate final report**: duration, iterations, completed/skipped/failed features with details, TDD stats (tests written/passing, acceptance tests), memory updates (decisions/patterns/rules).

37. **Final cleanup**: ensure on main, clear autonomous state, clean up task references.

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

## Phase 3.7: Team Roster Setup

Every feature uses a 3-specialist Agent Team:
- **test-writer**: Owns test files. Writes failing tests defining expected behavior (RED).
- **implementer**: Owns source files. Writes minimal code to pass tests (GREEN).
- **reviewer**: Reviews quality (REFACTOR), then writes/runs deterministic acceptance tests (ACCEPT). Messages implementer directly with issues.

15.9. **Prepare specialist context**:
   - **test-writer**: acceptance criteria, test patterns (auto-detect: `*.test.ts`, `test_*.py`, `*_test.go`, etc.), verification commands
   - **implementer**: files to modify, codebase patterns, plan, past failures
   - **reviewer**: conventions, security, acceptance test command (`verification.acceptance`), acceptance criteria from issue

15.10. Store roster in loop state (`team` field in v7 schema).

---

## Phase 3.8: Plan-Only Gate (if --plan-only)

If `--plan-only`: display plan summary (feature ID, issue, branch, team roster) with resume command and **EXIT**.

---

## Phase 4: Implementation (Team-Driven)

Implementation MUST use an Agent Team with the roster from Phase 3.7. Lead coordinates in delegate mode.

16. **Branch verification**: `git branch --show-current` — STOP if on main/master.

17. **Initialize loop state** (canonical Loop-State Schema v7):
    ```json
    {
      "version": 7,
      "feature": "feature-XXX", "featureName": "{description}",
      "type": "feature", "status": "in_progress",
      "attempt": 1, "maxAttempts": 15,
      "startedAt": "{ISO}", "history": [],
      "tdd": { "phase": null, "testsWritten": [], "testStatus": null, "acceptanceStatus": null },
      "team": {
        "teamName": "{project}-{feature-id}", "leadMode": "delegate",
        "roster": ["test-writer", "implementer", "reviewer"],
        "results": [], "reviewCycles": 0, "acceptCycles": 0
      },
      "tasks": { "enabled": true, "chain": ["{task-ids}"], "current": null, "completed": [] }
    }
    ```

17.5. Update task status: mark Implement task as in_progress.

---

### Phase 4.1: Create Team and Spawn Specialists

18. **Stale team guard** (v6.3.0): If `team.teamName` references a dead team from previous session (resume/interrupt), clear team state and create fresh.

- Create team: `"{project}-{feature-id}"`, delegate mode
- Spawn test-writer, implementer, reviewer with context from Phase 3.7
- Require plan approval for all teammates

---

### Phase 4.2: Team-Driven TDD (RED → GREEN → REFACTOR → ACCEPT)

**Step 1: RED** (effort: high):
- Assign test-writer: "Write failing tests covering unit, integration, edge cases"
- Wait for completion. Tests must exist and FAIL.
- If tests pass without implementation: log warning, continue
- Update `tdd.phase = "red"`, `tdd.testStatus = "failing"`

**Step 2: GREEN** (effort: high→max):
- Message implementer: "Tests at {paths}. Make them pass with minimal code."
- Implementer can message test-writer directly for clarification
- Run ALL verification commands after implementation
- Pass: update `tdd.phase = "green"`, proceed to REFACTOR
- Fail: record to failures.json, increment attempts, retry with escalation (>5: max effort, >10: max + procedural memory)

**Step 3: REFACTOR** (effort: max):
- Message reviewer: "Tests passing. Review for quality."
- Reviewer↔implementer direct dialogue (no lead intermediation). Max 2 rounds.
- Run tests after each change. Revert if broken.
- Update `tdd.phase = "refactor"`

**Step 4: ACCEPT** (effort: max):
- Message reviewer: "Write and run deterministic acceptance tests verifying feature end-to-end."
- Reviewer workflow:
  1. Read acceptance criteria from issue/feature entry
  2. Design deterministic scenarios (HTTP→response, CLI→stdout, API→return, data→output, config→structure)
  3. Write acceptance test files
  4. Run via `verification.acceptance` config or standard test runner
  5. Report pass/fail with evidence
- Pass: update `tdd.acceptanceStatus = "passing"`, proceed to 4.3
- Fail: reviewer↔implementer direct dialogue, max 2 rounds (`team.acceptCycles`). Run unit tests after each fix; revert if broken. If exceeded: lead can allow one more round or mark partial.
- Record results to procedural memory regardless of outcome.

---

### Phase 4.3: Verification and Team Cleanup

19. **Streaming memory updates** after each verification attempt:
    - Fail: append to failures.json (id, feature, approach, errors, rootCause), increment attempts, retry
    - Pass: append to successes.json (id, feature, approach, files, patterns), mark loop "completed", update tasks (mark Implement/Verify/Accept completed, Checkpoint in_progress)

20. **Team cleanup**: shut down teammates, clean up team. Proceed to Phase 5.

21. **On escalation** (max attempts): shut down team, show summary, offer options (increase attempts, get help, abort). Do NOT checkpoint.

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
      - Display recovery banner with feature info, interrupt time, TDD phase, attempt count
      - **In autonomous**: always FRESH APPROACH (option 1)
      - **In standard**: present 3 options via AskUserQuestion:
        1. FRESH APPROACH (recommended) — new team, increment attempt, record interrupted attempt in history, load procedural memory
        2. RETRY SAME — new team, same counter, don't add to history
        3. RESET — start from Phase 3 with fresh state
      - All options: clear stale team, copy preserved state, delete recovery markers
    - **If no marker**: resume from feature status:
      - `pending` → Phase 3, `in_progress` → Phase 4 (with stale team guard), `needs_review` → Phase 6, `passing` → already complete

32. Interrupted flow: state preserved in `.recovery/`, dead teams auto-detected and replaced.

---

## Error Handling

33. **GitHub API failures**: Retry with exponential backoff. If persistent: pause and inform user.
34. **Verification failures**: Record to procedural memory, try alternative, escalate after maxAttempts.
35. **Merge conflicts**: Inform user, offer rebase or manual resolution.

---

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/flow "Add X"` | Full lifecycle: team TDD (RED→GREEN→REFACTOR→ACCEPT) → checkpoint → merge |
| `/flow feature-XXX` | Resume existing feature from current phase |
| `/flow --no-merge "Add X"` | Stop at checkpoint |
| `/flow --quick "Simple fix"` | Skip planning, implement directly without team |
| `/flow --plan-only "Big feature"` | Plan only, implement later |
| `/flow --fix feature-001 "Bug"` | Create and complete a bug fix |
| `/flow --autonomous` | Batch process all features with team per feature |
| `/flow --autonomous --no-merge` | Batch, stop at checkpoint |
| `/flow --autonomous --quick` | Autonomous without planning |

**Flag combinations**: `--no-merge --plan-only` (plan before implementing), `--autonomous --no-merge --quick` (fast batch without merge)

**Note**: TDD always-on. Every feature gets 3 specialists enforcing RED-GREEN-REFACTOR-ACCEPT. Reviewer writes deterministic acceptance tests after code review.

---

## When to Use Each Mode

| Mode | Use Case |
|------|----------|
| Default (`/flow "desc"`) | Standard feature with specialist team |
| `--no-merge` | Review PR before merging |
| `--plan-only` | Complex features needing upfront design |
| `--quick` | Simple fixes — skips planning, implements directly without team |
| `--autonomous` | Batch processing feature backlog unattended |
| Empty args (menu) | Select multiple features for parallel team processing |
