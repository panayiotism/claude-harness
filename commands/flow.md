---
description: Unified end-to-end workflow - creates, implements, checkpoints, and merges features automatically
argument-hint: "DESCRIPTION" | FEATURE-ID | --fix FEATURE-ID "bug description"
---

Single-command workflow that handles the entire feature lifecycle from creation to merge.

Arguments: $ARGUMENTS

---

## Overview

`/claude-harness:flow` combines start + do + checkpoint + merge into one automated workflow:

```
/claude-harness:flow "Add dark mode support"
```

**Lifecycle Phases**:
1. **Context** - Auto-compile memory (replaces /start)
2. **Creation** - GitHub issue, branch, feature entry
3. **Planning** - Architecture analysis, approach selection
4. **Implementation** - Agentic loop with verification
5. **Checkpoint** - Auto-commit when tests pass
6. **Merge** - Auto-merge when PR approved (optional)

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
   - If empty: Show interactive menu (same as /do)
   - If matches `feature-\d+`: Resume existing feature
   - If matches `fix-feature-\d+-\d+`: Resume existing fix
   - If `--fix <feature-id> "description"`: Create fix linked to feature
   - Otherwise: Create new feature from description

2. **Parse options**:
   - `--no-merge`: Skip automatic merge phase (stop at checkpoint)
   - `--quick`: Skip planning phase
   - `--inline`: Skip worktree creation

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
    - **Graceful fallback**: If TaskCreate fails, continue without tasks

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

## Phase 4: Implementation (Agentic Loop)

16. **Branch verification** (MANDATORY):
    ```bash
    CURRENT_BRANCH=$(git branch --show-current)
    ```
    - **STOP if on main/master**
    - Fetch and checkout correct branch if needed

17. **Initialize loop state** (v4 with task integration):
    - Write to `.claude-harness/sessions/{session-id}/loop-state.json`:
      ```json
      {
        "version": 4,
        "feature": "feature-XXX",
        "featureName": "{description}",
        "type": "feature",
        "status": "in_progress",
        "attempt": 1,
        "maxAttempts": 15,
        "startedAt": "{ISO timestamp}",
        "history": [],
        "tasks": {
          "enabled": true,
          "chain": ["{task1-id}", "{task2-id}", "{task3-id}", "{task4-id}", "{task5-id}"],
          "current": "{task3-id}",
          "completed": ["{task1-id}", "{task2-id}"]
        }
      }
      ```
    - **Backward compatible**: If tasks.enabled is false or missing, ignore task integration

17.5. **Update task status** (if tasks enabled):
    - Call `TaskUpdate` to mark "Implement" task (Task 3) as "in_progress"
    - Display task progress:
      ```
      Tasks: [✓] Research [✓] Plan [→] Implement [ ] Verify [ ] Checkpoint
      ```

18. **Execute implementation loop** (effort: high, escalate to max on failure):
    - Plan approach (avoiding past failures)
    - Implement code changes
    - Document approach in loop state
    - Run ALL verification commands
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
| `/claude-harness:flow "Add X"` | Full lifecycle: create → implement → checkpoint → merge |
| `/claude-harness:flow feature-XXX` | Resume existing feature from current phase |
| `/claude-harness:flow --no-merge "Add X"` | Stop at checkpoint (don't auto-merge) |
| `/claude-harness:flow --quick "Simple fix"` | Skip planning phase |
| `/claude-harness:flow --inline "Tiny change"` | Skip worktree (work in current dir) |
| `/claude-harness:flow --fix feature-001 "Bug"` | Create and complete a bug fix |

---

## Comparison with Individual Commands

| Aspect | Individual Commands | /flow |
|--------|---------------------|-------|
| Commands to run | 4 (start, do, checkpoint, merge) | 1 |
| Manual transitions | Required | Automatic |
| Memory compilation | Each /start | Once at beginning |
| GitHub parsing | 5x (each command) | 1x (cached) |
| Completion detection | Manual | Auto (hook-based) |
| Merge timing | Manual /merge | Auto when PR approved |

**When to use /flow**:
- New features you want to complete end-to-end
- Bug fixes that need quick turnaround
- Automated/unattended development

**When to use individual commands**:
- Need to pause between phases
- Complex features requiring manual review
- Debugging specific phases
