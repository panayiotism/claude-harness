---
name: flow
description: Unified development workflow for implementing features, fixing bugs, running autonomous batch processing, planning implementations, and orchestrating ATDD agent teams. Triggers on feature creation, bug fixes, batch processing, implementation planning, team-based development, and any end-to-end coding workflow.
---

# Flow - Unified Development Workflow

The single command for all development workflows. Handles the entire feature lifecycle from creation to merge.

Arguments: $ARGUMENTS

## Overview

All workflows run through this single entry point with flags:

```
/claude-harness:flow "Add dark mode support"           # Standard workflow
/claude-harness:flow --autonomous                      # Batch process all features
/claude-harness:flow --plan-only "Big refactor"        # Plan only, implement later
/claude-harness:flow --team "Add user login"           # ATDD with Agent Team (3 teammates)
```

**Lifecycle**: Context -> Creation -> **[Subagent Delegation]** -> Planning -> Implementation -> Verification -> Checkpoint -> Merge -> **[Result Processing]**

**Context Isolation**: In standard mode, Phases 3-6 run inside an isolated subagent (via Task tool). The main context stays clean after feature completion -- no `/clear` needed between features.

**ATDD Team Lifecycle** (with `--team`): Context -> Creation (with Gherkin criteria) -> **[Subagent Delegation]** -> Planning -> **Team Spawn** -> Acceptance Tests (RED) -> Implementation (GREEN) -> Review -> Verify -> Checkpoint -> Merge

---

## Effort Controls (Opus 4.6+)

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
   - `--autonomous`: Outer loop -- iterate all active features
   - `--team`: Use Agent Teams for ATDD implementation (requires `agentTeams.enabled` in config.json)

3. **Mode validation**:
   - `--autonomous`: Compatible with `--no-merge`, `--quick`, and `--team`. Proceed to Autonomous Wrapper.
   - `--plan-only`: Proceeds through Phases 0-3 then STOPS. Incompatible with `--team`.
   - `--team`: Compatible with `--autonomous`, `--no-merge`. Incompatible with `--quick` and `--plan-only`.

---

## Phase 0.2: Team Preflight (if --team)

Read `${CLAUDE_SKILL_DIR}/references/team-atdd.md` for full Agent Teams ATDD details.

- Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var is set to `1`
- If not set: display error with instructions to enable, then STOP
- Read `.claude-harness/config.json` `agentTeams` section: verify `enabled` is `true`
- Cache team config: `defaultTeamSize`, `roles`, `requirePlanApproval`, `teammateModel`

---

## Autonomous Wrapper (if --autonomous)

When `--autonomous` is set, the flow operates as a **lean orchestrator loop** that iterates all active features. Each feature is executed in an **isolated subagent context** via the Task tool.

Read `${CLAUDE_SKILL_DIR}/references/autonomous-wrapper.md` for the full autonomous orchestration phases (A.1 through A.7).

### Context Isolation (All Modes)

Both standard and autonomous modes delegate feature implementation to a `general-purpose` subagent via the Task tool. This provides:

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

Read all memory layers IN PARALLEL for speed.

1. **Set paths**:
   - `FEATURES_FILE=".claude-harness/features/active.json"`
   - `MEMORY_DIR=".claude-harness/memory/"`
   - `ARCHIVE_FILE=".claude-harness/features/archive.json"`

2. **Parse and cache GitHub repo** (do this ONCE):
   ```bash
   REMOTE_URL=$(git remote get-url origin 2>/dev/null)
   ```
   Parse owner/repo from SSH or HTTPS URL. Store for reuse.

3. **Read IN PARALLEL**: failures.json, successes.json, decisions.json, rules.json, active.json

4. **Compile working context** to `.claude-harness/sessions/{session-id}/context.json`:
   ```json
   {
     "version": 3, "computedAt": "{ISO}", "sessionId": "{session-id}",
     "github": { "owner": "{parsed}", "repo": "{parsed}" },
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

3. **Create GitHub Issue**: `mcp__github__create_issue` with labels `["feature", "claude-harness", "flow"]`, body with Problem/Solution/Acceptance Criteria (Gherkin)/Verification. STOP if fails.

4. **Create and checkout branch**: `mcp__github__create_branch`, then `git fetch origin && git checkout feature/feature-XXX`.

5. **Create feature entry** in active.json: id, name, status "in_progress", acceptanceCriteria, github refs, verificationCommands, maxAttempts 15.

---

## Phase 2.5: Context Isolation (Standard Mode)

**Skip this phase** if `--plan-only` or `--autonomous`.

After feature creation, delegate the remaining lifecycle to an isolated subagent for clean context. Read `${CLAUDE_SKILL_DIR}/references/implementation.md` for the full subagent prompt format and result processing logic.

### Summary:
1. Compile subagent prompt (feature entry, verification commands, memory, GitHub info, flags)
2. Delegate to Task tool with `subagent_type="general-purpose"`
3. Subagent runs Phases 3-6 autonomously in fresh context
4. Parse RESULT block from subagent response
5. Process result: archive on success, persist memory, clean up branches
6. Skip to Phase 7

---

## Phase 3: Planning (unless --quick)

**Note**: In standard mode, this phase runs inside the delegated subagent. It only runs inline when `--plan-only` is set.

1. **Query procedural memory** (effort: max): Check past failures/successes. Warn if planned approach matches past failure.
2. **Analyze requirements**: Break down, identify files, calculate impact.
3. **Generate plan**: Store in feature entry or session context.

---

## Phase 3.5: Create Task Breakdown

Uses Claude Code's native Tasks for visual progress tracking.

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
5. On failure: record to failures.json, increment attempts, retry with escalation

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
2. Capture working context to session-scoped file
3. Compile session briefing to `.claude-harness/session-briefing.md`
4. Persist to all memory layers (episodic, semantic, procedural)
5. Auto-reflect on user corrections
6. Persist orchestration memory
7. Commit, push, create/update PR

---

## Phase 6: Auto-Merge (unless --no-merge)

Only proceeds if PR approved and CI passes.

1. Check PR status via `mcp__github__get_pull_request_status`
2. If ready: merge (squash), close issue, delete remote branch, update status to "passing", archive feature
3. If needs review: display PR URL with resume/merge commands
4. **Final cleanup**: switch to main, delete local feature branch (`git branch -d`), prune refs, clear loop state

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

- **GitHub API failures**: Retry with exponential backoff. If persistent: pause and inform user.
- **Verification failures**: Record to procedural memory, try alternative, escalate after maxAttempts.
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
