---
name: flow
description: Unified end-to-end development workflow - creates a feature (GitHub issue, branch, Gherkin acceptance criteria), implements it in an isolated subagent via ATDD, verifies, checkpoints (commit/push/PR), and merges. Use for implementing features, fixing bugs, batch-processing a feature backlog, or planning implementations.
argument-hint: "[description | feature-id] [--no-merge --plan-only --autonomous --quick --fix --team]"
allowed-tools: "Bash(git *), Bash(gh *)"
---

# Flow - Unified Development Workflow

The single command for all development workflows. Handles the entire feature lifecycle from creation to merge.

Arguments: $ARGUMENTS

Session ID: ${CLAUDE_SESSION_ID} — session state lives in `.claude-harness/sessions/${CLAUDE_SESSION_ID}/`.

## Overview

All workflows run through this single entry point with flags:

```
/claude-harness:flow "Add dark mode support"           # Standard workflow
/claude-harness:flow --autonomous                      # Batch process all features
/claude-harness:flow --plan-only "Big refactor"        # Plan only, implement later
/claude-harness:flow --team "Add user login"           # ATDD with Agent Team (3 teammates)
```

**Lifecycle**: Context -> Creation -> **[Subagent Delegation]** -> Planning -> Implementation -> Verification -> Checkpoint -> Merge -> **[Result Processing]**

**Context Isolation**: In standard mode, Phases 3-6 run inside an isolated subagent (via the Agent tool, subagent type `claude-harness:harness-implementer`). The main context stays clean after feature completion -- no `/clear` needed between features.

**ATDD Team Lifecycle** (with `--team`): Context -> Creation (with Gherkin criteria) -> **[Subagent Delegation]** -> Planning -> **Team Spawn** -> Acceptance Tests (RED) -> Implementation (GREEN) -> Review -> Verify -> Checkpoint -> Merge

---

## Retry Policy

Each delegated subagent gets **at most 4 implementation attempts**. If it escalates, the orchestrator spawns a **fresh subagent** (clean context) seeded with the failure summary from the previous delegation -- up to **3 delegations per feature** (12 attempts total). A fresh context with distilled failure knowledge outperforms a degraded context grinding through attempt 15.

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
   - `--autonomous`: Outer loop -- iterate all active features
   - `--team`: Use Agent Teams for ATDD implementation (requires `agentTeams.enabled` in config.json)

3. **Mode validation**:
   - `--autonomous`: Compatible with `--no-merge`, `--quick`, and `--team`. Proceed to Autonomous Wrapper.
   - `--plan-only`: Proceeds through Phases 0-3 then STOPS. Incompatible with `--team`.
   - `--team`: Compatible with `--autonomous`, `--no-merge`. Incompatible with `--quick` and `--plan-only`.

---

## Phase 0.2: Team Preflight (if --team)

Read `${CLAUDE_SKILL_DIR}/references/team-atdd.md` for full Agent Teams ATDD details.

- Read `.claude-harness/config.json` `agentTeams` section: verify `enabled` is `true`. If not: display "Enable agentTeams in config.json" and STOP.
- Cache team config: `defaultTeamSize`, `roles`, `requirePlanApproval`, `teammateModel`

---

## Autonomous Wrapper (if --autonomous)

When `--autonomous` is set, the flow operates as a **lean orchestrator loop** that iterates all active features. Each feature is executed in an **isolated subagent context** via the Agent tool.

Read `${CLAUDE_SKILL_DIR}/references/autonomous-wrapper.md` for the full autonomous orchestration phases (A.1 through A.7).

**Tip**: for fully unattended batches, run the session as `claude --permission-mode acceptEdits` -- the PermissionRequest hook then only has to arbitrate the rare dangerous operations.

### Context Isolation (All Modes)

Both standard and autonomous modes delegate feature implementation to the `claude-harness:harness-implementer` subagent via the Agent tool (fall back to `general-purpose` if the type is unavailable). This provides:

- **Fresh context window**: Each feature starts with zero accumulated context
- **Clean token budget**: No context waste from previous features
- **Contained failures**: A failing feature's debugging context does not pollute the next feature
- **Memory continuity**: Orchestrator persists memory updates between features
- **Team containment**: When `--team` is used, the Agent Team lifecycle is fully contained within the subagent
- **No manual /clear needed**: After feature completion, the main context is clean

**Standard mode** (Phase 2.5): Single feature delegated after creation.
**Autonomous mode** (Phase A.4): Multiple features delegated in a loop.

---

## Phase 1: Context Compilation (Auto-Start)

1. **Set paths**:
   - `FEATURES_FILE=".claude-harness/features/active.json"`
   - `MEMORY_DIR=".claude-harness/memory/"`
   - `ARCHIVE_FILE=".claude-harness/features/archive.json"`

2. **GitHub repo**: use the cached owner/repo from the session context (injected at SessionStart). Only if absent, parse once from `git remote get-url origin`.

3. **Read IN PARALLEL** (single message, multiple Read calls): failures.json, successes.json, decisions.json, rules.json, active.json

4. **Compile working context** to `.claude-harness/sessions/${CLAUDE_SESSION_ID}/context.json`:
   ```json
   {
     "version": 3, "computedAt": "{ISO}", "sessionId": "${CLAUDE_SESSION_ID}",
     "github": { "owner": "{owner}", "repo": "{repo}" },
     "activeFeature": null,
     "relevantMemory": { "recentDecisions": [], "projectPatterns": [], "avoidApproaches": [], "learnedRules": [] }
   }
   ```

5. **Display context summary**: memory stats, GitHub info.

---

## Phase 2: Feature Creation

Use cached GitHub owner/repo from Phase 1.

1. **Generate feature ID**: Read active.json, find highest ID, generate next `feature-XXX`.

2. **Define acceptance criteria** (ATDD -- always on):
   - If feature has existing `acceptanceCriteria` (from PRD breakdown): use those
   - Otherwise: generate Gherkin acceptance criteria from feature description
   - Format as structured Gherkin: `{ "scenario", "given", "when", "then" }`
   - Aim for 2-5 scenarios covering: happy path, error cases, edge cases

3. **Create GitHub Issue** via `gh issue create --title "{name}" --label "feature,claude-harness,flow" --body "{Problem/Solution/Acceptance Criteria (Gherkin)/Verification}"`. STOP if it fails (check `gh auth status`).

4. **Create and checkout branch locally**: `git checkout -b feature/feature-XXX` (no API round-trip; the branch reaches the remote on first `git push -u origin feature/feature-XXX`).

5. **Create feature entry** in active.json: id, name, status "in_progress", acceptanceCriteria, github refs, verificationCommands, maxAttempts 12.

---

## Phase 2.5: Context Isolation (Standard Mode)

**Skip this phase** if `--plan-only` or `--autonomous`.

After feature creation, delegate the remaining lifecycle to an isolated subagent for clean context. Read `${CLAUDE_SKILL_DIR}/references/implementation.md` for the delegation prompt format and result processing logic.

### Summary:
1. Compile subagent prompt (feature entry, verification commands, memory, GitHub info, flags, result file path)
2. Delegate via Agent tool with `subagent_type="claude-harness:harness-implementer"`
3. Subagent runs Phases 3-6 autonomously in fresh context and writes its result file
4. Read the result file (fallback: parse `RESULT:` from the subagent's reply)
5. Process result: archive on success, persist memory, clean up branches; on `escalated`, re-delegate a fresh subagent (max 3 delegations)
6. Skip to Phase 7

---

## Phase 3: Planning (unless --quick)

**Note**: In standard mode, this phase runs inside the delegated subagent. It only runs inline when `--plan-only` is set.

1. **Query procedural memory**: Check past failures/successes. Warn if planned approach matches past failure.
2. **Analyze requirements**: Break down, identify files, calculate impact.
3. **Generate plan**: Store in feature entry or session context.

---

## Phase 3.5: Create Task Breakdown

Uses Claude Code's native task tracking (TaskCreate/TaskUpdate) for visual progress.

- Create task chain (6 tasks): Research -> Plan -> Implement -> Verify -> Accept -> Checkpoint
- Each blocked by previous. Store IDs in loop-state.
- Mark Task 1 as in_progress.

---

## Phase 3.7: Team Roster (if --team)

Read `${CLAUDE_SKILL_DIR}/references/team-atdd.md` for full team roster and ATDD spawn prompts.

Summary: Prepare team structure with tester, implementer, reviewer roles. Prepare ATDD spawn prompts for each role.

---

## Phase 3.8: Plan-Only Gate (if --plan-only)

If `--plan-only`: display plan summary (feature ID, issue, branch) with resume command and **EXIT**.

---

## Phase 4: Implementation

Read `${CLAUDE_SKILL_DIR}/references/implementation.md` for full implementation details including loop state schema, standard vs team implementation, and verification.

### Standard (no --team):
1. Branch verification: STOP if on main/master
2. Initialize loop state (canonical Loop-State Schema v9)
3. Implement feature following ATDD: acceptance tests first (RED), implement to pass (GREEN), refactor
4. Run verification commands after implementation
5. On failure: record to failures.json, increment attempts, retry with a different approach (max 4 per delegation)

### Team (--team):
Read `${CLAUDE_SKILL_DIR}/references/team-atdd.md` for full ATDD team implementation including team creation, monitoring, shutdown gate, and cleanup.

### Phase 4.1: Verification and Memory Updates

- **Fail**: append to failures.json, increment attempts, retry
- **Pass**: append to successes.json, mark loop "completed", update tasks
- **Escalation** (max attempts): show summary, offer options. Do NOT checkpoint.

---

## Phase 5: Auto-Checkpoint

Triggers when verification passes. Read `${CLAUDE_SKILL_DIR}/references/checkpoint.md` for detailed checkpoint phases.

Summary:
1. Update `.claude-harness/claude-progress.json` with session summary
2. Compile session briefing to `.claude-harness/session-briefing.md`
3. Persist to all memory layers (episodic, semantic, procedural)
4. Auto-reflect on user corrections
5. Persist orchestration memory
6. Commit, push (`git push -u origin {branch}`), create/update PR via `gh pr create` / `gh pr edit`

---

## Phase 6: Auto-Merge (unless --no-merge)

Only proceeds if PR approved and CI passes.

1. Check PR status: `gh pr view {number} --json state,mergeable,reviewDecision,statusCheckRollup`
2. If ready: `gh pr merge {number} --squash --delete-branch`, close issue if not auto-closed (`gh issue close {issueNumber}`), update status to "passing", archive feature
3. If needs review: display PR URL with resume/merge commands
4. **Final cleanup**: switch to main, pull, delete local feature branch (`git branch -d`), prune refs, clear loop state

---

## Phase 7: Completion Report

1. Clean up tasks (all 6 should be completed).
2. Display final status: feature ID, description, issue (closed), PR (merged), tasks 6/6, attempts, duration, memory updates.

---

## Resume Behavior

- `/claude-harness:flow feature-XXX`:
  - **Check interrupt recovery** (priority): Read `.claude-harness/sessions/.recovery/interrupted.json`
  - If marker matches: display recovery banner, present options (FRESH APPROACH / RETRY SAME / RESET)
  - **In autonomous**: always FRESH APPROACH
  - **If no marker**: resume from feature status: `pending` -> Phase 3, `in_progress` -> Phase 4, `needs_review` -> Phase 6, `passing` -> already complete

---

## Error Handling

- **GitHub/`gh` failures**: Retry with exponential backoff. If persistent (auth, network): pause and inform user (`gh auth status`).
- **Verification failures**: Record to procedural memory, try alternative, escalate after max attempts.
- **Merge conflicts**: Inform user, offer rebase or manual resolution.

---

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/flow "Add X"` | Full lifecycle with context isolation: implement -> verify -> checkpoint -> merge |
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
| Default (`/flow "desc"`) | Standard feature development (context-isolated via subagent) |
| `--no-merge` | Review PR before merging |
| `--plan-only` | Complex features needing upfront design |
| `--quick` | Simple fixes -- skips planning |
| `--autonomous` | Batch processing feature backlog unattended |
| `--team` | Complex features benefiting from parallel review + ATDD |
| `--team --autonomous` | High-quality batch processing with code review |
