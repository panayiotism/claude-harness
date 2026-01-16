---
description: TDD workflow - write tests first, then implement (test-driven development)
argument-hint: ["DESCRIPTION" | FEATURE-ID | (empty for interactive menu)] [--quick] [--auto] [--plan-only]
---

TDD-enforced development workflow. Requires writing failing tests BEFORE implementation code.

Arguments: $ARGUMENTS

```
┌─────────────────────────────────────────────────────────────────┐
│  🧪 TDD MODE: Red-Green-Refactor                                │
├─────────────────────────────────────────────────────────────────┤
│  1. RED:      Write failing tests first                         │
│  2. GREEN:    Write minimal code to pass tests                  │
│  3. REFACTOR: Improve code while keeping tests green            │
└─────────────────────────────────────────────────────────────────┘
```

## Phase 0: Interactive Selection (if no arguments)

If `/do-tdd` is called without arguments, show an interactive menu of incomplete features:

1. **Check for empty arguments**:
   - If `$ARGUMENTS` is empty or whitespace-only, proceed with interactive selection
   - Otherwise, skip to Phase 1 (Argument Parsing)

2. **Detect worktree mode and set paths**:
   ```bash
   GIT_COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null)
   GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)

   if [ "$GIT_COMMON_DIR" != ".git" ] && [ "$GIT_COMMON_DIR" != "$GIT_DIR" ]; then
       MAIN_REPO_PATH=$(dirname "$GIT_COMMON_DIR")
       FEATURES_FILE="${MAIN_REPO_PATH}/.claude-harness/features/active.json"
   else
       FEATURES_FILE=".claude-harness/features/active.json"
   fi
   ```

3. **Read incomplete features and fixes**:
   - Read `${FEATURES_FILE}`
   - Filter `features` array where `status` is NOT "passing"
   - Filter `fixes` array where `status` is NOT "passing"
   - Combine into options list

4. **Build options list for menu**:
   - For each incomplete feature:
     - Label: `{id}`
     - Description: `{name} [{status}]` + " [TDD]" if `tdd: true`
   - For each incomplete fix:
     - Label: `{id}`
     - Description: `{name} (fix for {linkedTo.featureId}) [{status}]`

5. **Handle empty state**:
   - If no incomplete features/fixes exist:
     - Use **AskUserQuestion** with single-select:
       - Question: "No pending features. What would you like to create? (TDD mode)"
       - Options:
         - Label: "New feature", Description: "Create a new TDD feature from description"
         - Label: "New bug fix", Description: "Create a TDD bug fix linked to an existing feature"
     - If "New feature": Use **AskUserQuestion** to prompt for description
     - If "New bug fix": Use **AskUserQuestion** to prompt for feature ID, then description
     - Set `$ARGUMENTS` to the entered description or `--fix` command
     - Continue to Phase 1

6. **Show interactive selection menu**:

   **CRITICAL: You MUST use `multiSelect: true` to allow parallel feature selection.**

   - Use **AskUserQuestion** with these EXACT parameters:
     - `multiSelect`: **MUST be `true`** (enables selecting multiple features for parallel worktrees)
     - `question`: "Which feature(s) do you want to work on with TDD? Select multiple for parallel development."
     - `header`: "TDD Features"

   Example:
     ```json
     {
       "questions": [{
         "question": "Which feature(s) do you want to work on with TDD? Select multiple for parallel development.",
         "header": "TDD Features",
         "multiSelect": true,
         "options": [
           {"label": "feature-001", "description": "Add authentication [in_progress] [TDD]"},
           {"label": "feature-002", "description": "Dark mode support [pending]"},
           {"label": "fix-feature-001-001", "description": "Token bug (fix for feature-001) [pending]"}
         ]
       }]
     }
     ```

   **DO NOT use `multiSelect: false`** - this defeats the purpose of parallel development.

   - Note: User can always select "Other" to create a new TDD feature

7. **Handle selection**:

   **If user selects 1 feature/fix**:
   - Set `$ARGUMENTS` to the selected ID
   - Continue to Phase 1 (Argument Parsing)

   **If user selects multiple features/fixes**:
   - For each selected item, create worktree (if doesn't already exist):
     a. Calculate worktree path: `../{repo-name}-{feature-id}/`
     b. Check if worktree already exists (skip if so)
     c. Run: `git worktree add <path> <branch>`
     d. Initialize harness in worktree
     e. Run environment setup (npm install, copy .env, etc.)
     f. Register in `worktrees/registry.json`
   - Display summary table:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  ✅ WORKTREES READY FOR SELECTED FEATURES (TDD MODE)            │
     ├─────────────────────────────────────────────────────────────────┤
     │  Feature         Path                           Status          │
     │  ─────────────────────────────────────────────────────────────  │
     │  feature-001     ../myproject-feature-001/      ✅ Ready        │
     │  feature-002     ../myproject-feature-002/      ✅ Created      │
     │  fix-feature-001 ../myproject-fix-feature-001/  ✅ Ready        │
     ├─────────────────────────────────────────────────────────────────┤
     │  🎯 NEXT STEPS (TDD workflow in each worktree):                 │
     │                                                                 │
     │  Open separate terminals for each feature:                      │
     │                                                                 │
     │  Terminal 1:                                                    │
     │    cd ../myproject-feature-001 && claude                        │
     │    /claude-harness:do-tdd feature-001                           │
     │                                                                 │
     │  Terminal 2:                                                    │
     │    cd ../myproject-feature-002 && claude                        │
     │    /claude-harness:do-tdd feature-002                           │
     │                                                                 │
     │  ... (one per selected feature)                                 │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - **STOP HERE** - User needs to open separate terminals
   - Do NOT continue to Phase 1

   **If user selects "Other"**:
   - Use **AskUserQuestion** to prompt for new TDD feature description
   - Set `$ARGUMENTS` to the entered description
   - Continue to Phase 1 (will create new TDD feature)

---

## Argument Parsing

1. Detect argument type:
   - If starts with `--fix <feature-id>`: Create bug fix linked to feature (TDD mode)
   - If matches `feature-\d+`: Resume existing feature
   - If matches `fix-feature-\d+-\d+`: Resume existing fix
   - If "resume": Resume last active workflow
   - Otherwise: Create new feature from description

2. Parse options:
   - `--fix <feature-id>`: Create bug fix linked to specified feature
   - `--quick`: Skip planning phase (for simple tasks) - **tests still required**
   - `--auto`: No interactive prompts (full automation)
   - `--plan-only`: Stop after planning (review before implementation)

## Phase 1: Feature Creation (if new feature)

**CRITICAL: GitHub issue and branch MUST be created BEFORE any code work begins.**

3. If creating new feature (no --fix flag):

   **Step 3a: Generate feature ID**
   - Read `.claude-harness/features/active.json` to find highest existing ID
   - Generate next sequential ID: `feature-XXX` (zero-padded, e.g., feature-013)

   **Step 3b: Create GitHub Issue (MANDATORY if GitHub MCP available)**
   - **First, parse owner/repo from git remote** (MANDATORY):
     ```bash
     REMOTE_URL=$(git remote get-url origin 2>/dev/null)
     # SSH: git@github.com:owner/repo.git → owner, repo
     # HTTPS: https://github.com/owner/repo.git → owner, repo
     ```
     CRITICAL: Always run this command fresh. NEVER guess or cache owner/repo.
   - Create GitHub issue using `mcp__github__create_issue`:
     - owner: Parsed from REMOTE_URL (the username/org before the repo name)
     - repo: Parsed from REMOTE_URL (the repository name, without .git suffix)
     - title: Feature description
     - body: Include acceptance criteria, verification steps, **TDD requirement note**
     - labels: `["feature", "claude-harness", "tdd"]`
   - Store the returned issue number
   - **DO NOT PROCEED** without issue creation (if MCP available)

   **Step 3c: Create and Checkout Feature Branch (MANDATORY)**
   - Create branch using `mcp__github__create_branch`:
     - branch: `feature/feature-XXX`
     - from_branch: `main` (or default branch)
   - **IMMEDIATELY checkout the branch locally**:
     ```bash
     git fetch origin
     git checkout feature/feature-XXX
     ```
   - **VERIFY you are on the feature branch before ANY code work**:
     ```bash
     git branch --show-current  # Must show feature/feature-XXX
     ```
   - **STOP AND ERROR** if not on feature branch

   **Step 3d: Create Feature Entry**
   - Add to `.claude-harness/features/active.json` with:
     - id, name, description, priority
     - status: "pending"
     - **tdd: true** (mark as TDD feature)
     - verification: Generate reasonable verification steps
     - verificationCommands: Auto-detect from project (build, test, lint, typecheck)
     - maxAttempts: 10
     - github: { issueNumber: {from 3b}, prNumber: null, branch: "feature/feature-XXX" }

## Phase 1a: Fix Creation (if --fix flag)

Same as `/do` command - see `commands/do.md` for full details.

4. Interactive checkpoint (unless --auto):
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  ✅ Feature Created: feature-012 (TDD Mode)                     │
   │     Branch: feature/feature-012                                 │
   │     Issue: #42                                                  │
   ├─────────────────────────────────────────────────────────────────┤
   │  🧪 TDD: Tests will be required before implementation          │
   │  Continue to planning? [Y/n/skip]                               │
   └─────────────────────────────────────────────────────────────────┘
   ```

5. Update workflow state in `.claude-harness/loops/state.json`:
   ```json
   {
     "workflow": {
       "active": true,
       "command": "do-tdd",
       "phase": "creating",
       "options": { "quick": false, "auto": false, "planOnly": false },
       "startedAt": "{ISO timestamp}"
     },
     "tdd": {
       "enabled": true,
       "phase": null,
       "testsWritten": [],
       "testStatus": null
     }
   }
   ```

## Phase 2: Planning (unless --quick)

6. Load context:
   - Read compiled context from `.claude-harness/memory/working/context.json`
   - Read semantic memory for project architecture
   - Query procedural memory for past failures/successes on similar work

7. Analyze requirements:
   - Break down feature into sub-tasks
   - Identify files to create/modify
   - Identify dependencies on other features/modules

8. **TDD Test Planning (MANDATORY)**:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  🧪 TDD: Generating Test Specifications                         │
   └─────────────────────────────────────────────────────────────────┘
   ```
   - Analyze feature requirements
   - Generate test specifications:
     - Unit tests for new functions/modules
     - Integration tests for feature behavior
     - Edge cases and error scenarios
   - Identify test files to create based on project patterns:
     ```
     Detected test patterns:
     - TypeScript: **/*.test.ts, **/*.spec.ts, **/__tests__/**
     - JavaScript: **/*.test.js, **/*.spec.js, **/__tests__/**
     - Python: **/test_*.py, **/*_test.py, **/tests/**
     - Go: **/*_test.go
     ```
   - Add to plan.steps with tests as FIRST steps:
     ```json
     {
       "steps": [
         {"step": 1, "type": "test", "phase": "red", "description": "Write failing test for X", "files": ["src/__tests__/x.test.ts"]},
         {"step": 2, "type": "test", "phase": "red", "description": "Write failing test for Y", "files": ["src/__tests__/y.test.ts"]},
         {"step": 3, "type": "implementation", "phase": "green", "description": "Implement X to pass tests", "files": ["src/x.ts"]},
         {"step": 4, "type": "implementation", "phase": "green", "description": "Implement Y to pass tests", "files": ["src/y.ts"]},
         {"step": 5, "type": "refactor", "phase": "refactor", "description": "Refactor if needed", "files": []}
       ]
     }
     ```

9. Display TDD test plan:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  🧪 TDD Test Plan                                               │
   ├─────────────────────────────────────────────────────────────────┤
   │  Tests to write FIRST (RED phase):                              │
   │  1. src/__tests__/auth.test.ts - Authentication tests          │
   │  2. src/__tests__/session.test.ts - Session management tests   │
   │                                                                 │
   │  Implementation files (GREEN phase):                            │
   │  3. src/auth.ts - Core authentication logic                    │
   │  4. src/session.ts - Session handling                          │
   └─────────────────────────────────────────────────────────────────┘
   ```

10. Impact analysis:
    - Read `.claude-harness/impact/dependency-graph.json` (if exists)
    - For each file to modify: identify dependent files
    - Calculate impact score (low/medium/high)

11. Check past approaches:
    - Read `.claude-harness/memory/procedural/failures.json`
    - If planned approach matches past failure:
      - Warn about similar past failure
      - Show root cause and prevention tips
      - Suggest alternative from successes.json

12. Generate implementation plan and update feature:
    ```json
    {
      "plan": {
        "steps": [...],
        "testFiles": ["src/__tests__/x.test.ts"],
        "implementationFiles": ["src/x.ts"],
        "impactScore": "low|medium|high",
        "risks": ["..."],
        "mitigations": ["..."]
      }
    }
    ```

13. Interactive checkpoint (unless --auto):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  📋 TDD Implementation Plan Ready                               │
    │     Test files: 2 | Implementation files: 3 | Impact: medium   │
    ├─────────────────────────────────────────────────────────────────┤
    │  Start TDD workflow? [Y/n/show]                                 │
    └─────────────────────────────────────────────────────────────────┘
    ```

14. Update workflow phase to "planning" then "planned"

15. If --plan-only: Stop here with message:
    ```
    Plan complete. Run `/claude-harness:do-tdd feature-012` to implement.
    ```

## Phase 3: Implementation (TDD-Enforced)

**CRITICAL SAFETY CHECK: Verify branch before ANY code changes.**

16. **Branch Verification (MANDATORY - NEVER SKIP)**
    ```bash
    CURRENT_BRANCH=$(git branch --show-current)
    EXPECTED_BRANCH=$(cat .claude-harness/features/active.json | grep -o '"branch": "[^"]*"' | head -1 | cut -d'"' -f4)
    ```
    - If on `main` or `master`: **STOP IMMEDIATELY**
    - If branch doesn't exist locally, fetch and checkout
    - **DO NOT PROCEED** until on correct feature/fix branch

17. Update workflow phase to "implementing"

18. Initialize or resume agentic loop:
    - If resuming: Load state from `.claude-harness/loops/state.json`
    - If new: Initialize loop state with TDD tracking

19. **TDD Phase: RED (Write Failing Tests)**

    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  🔴 RED PHASE: Write Failing Tests                              │
    ├─────────────────────────────────────────────────────────────────┤
    │  Write tests that define the expected behavior.                 │
    │  Tests MUST fail initially (no implementation yet).             │
    └─────────────────────────────────────────────────────────────────┘
    ```

    **Step 19a: Check Test File Existence**
    - Read planned test files from `plan.testFiles`
    - Check if test files exist on disk:
      ```bash
      for file in "${TEST_FILES[@]}"; do
        if [ ! -f "$file" ]; then
          MISSING_TESTS+=("$file")
        fi
      done
      ```
    - If ANY test files missing:
      ```
      ┌─────────────────────────────────────────────────────────────────┐
      │  🔴 TDD GATE: Tests Required Before Implementation             │
      ├─────────────────────────────────────────────────────────────────┤
      │  Missing test files:                                            │
      │  • src/__tests__/auth.test.ts                                   │
      │  • src/__tests__/session.test.ts                                │
      │                                                                  │
      │  ⚠️  BLOCKED: Write these tests BEFORE any implementation.      │
      │                                                                  │
      │  Tests should define expected behavior and FAIL initially.     │
      └─────────────────────────────────────────────────────────────────┘
      ```
      - **DO NOT PROCEED** to implementation
      - Write the test files first
      - Re-check after writing

    **Step 19b: Verify Tests Fail (RED state)**
    - Run test command
    - If tests PASS without implementation:
      ```
      ┌─────────────────────────────────────────────────────────────────┐
      │  ⚠️  WARNING: Tests Pass Without Implementation                 │
      ├─────────────────────────────────────────────────────────────────┤
      │  Your tests pass, but no implementation exists yet.            │
      │  This usually means tests are:                                  │
      │  • Too trivial (not testing real behavior)                     │
      │  • Mocking everything (not testing integration)                │
      │  • Missing assertions                                          │
      │                                                                  │
      │  Consider strengthening your tests before proceeding.          │
      │  Continue anyway? [y/N]                                        │
      └─────────────────────────────────────────────────────────────────┘
      ```
    - If tests FAIL: Proceed to GREEN phase (this is correct)
    - Update TDD state: `tdd.phase = "red"`, `tdd.testStatus = "failing"`

20. **TDD Phase: GREEN (Minimal Implementation)**

    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  🟢 GREEN PHASE: Make Tests Pass                                │
    ├─────────────────────────────────────────────────────────────────┤
    │  Write the MINIMAL code needed to make tests pass.              │
    │  Don't over-engineer. Don't optimize yet.                       │
    └─────────────────────────────────────────────────────────────────┘
    ```

    - Query procedural memory for past failures to avoid
    - Query procedural memory for successful approaches
    - Write minimal implementation code
    - Run ALL verification commands (build, tests, lint, typecheck)
    - If tests PASS:
      - Update TDD state: `tdd.phase = "green"`, `tdd.testStatus = "passing"`
      - Proceed to REFACTOR phase
    - If tests FAIL:
      - Record approach to history
      - Retry (up to maxAttempts)

21. **TDD Phase: REFACTOR (Optional Improvement)**

    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  🔄 REFACTOR PHASE: Improve Code Quality                        │
    ├─────────────────────────────────────────────────────────────────┤
    │  Tests pass. Now improve code while keeping tests green.        │
    │  • Remove duplication                                           │
    │  • Improve naming                                               │
    │  • Simplify logic                                               │
    └─────────────────────────────────────────────────────────────────┘
    ```

    - Interactive prompt (unless --auto):
      ```
      Refactoring opportunity? [y/N/show suggestions]
      ```
    - If refactoring:
      - Make improvements
      - Run tests after EACH change
      - If tests fail: revert and try different approach
    - Update TDD state: `tdd.phase = "refactor"`

22. **Verification Gate (MANDATORY)**
    - Run ALL verification commands:
      - Build
      - Tests
      - Lint
      - Typecheck
    - ALL must pass to proceed
    - Update loop state with results

23. On verification success:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ TDD Complete: feature-012                                   │
    │     🔴 RED → 🟢 GREEN → 🔄 REFACTOR                              │
    │     Tests: 15/15 passing                                        │
    │     Attempts: 2                                                 │
    ├─────────────────────────────────────────────────────────────────┤
    │  Create checkpoint (commit + PR)? [Y/n]                         │
    └─────────────────────────────────────────────────────────────────┘
    ```

24. On escalation (max attempts reached):
    - Show attempt summary with TDD phase info
    - Offer options: increase attempts, get human help, abort

## Phase 4: Checkpoint (if confirmed or --auto)

25. Update workflow phase to "checkpoint"

26. If user confirms (or --auto):
    - Update `.claude-harness/claude-progress.json`
    - Persist to memory layers (episodic, semantic, procedural)
    - **Auto-reflect**: Scan conversation for user corrections
    - Commit all changes with appropriate prefix:
      - Feature: `feat(feature-XXX): description [TDD]`
      - Fix: `fix({linkedTo.featureId}): description [TDD]`
    - Push to remote
    - Create/update PR (if GitHub MCP available)
      - Include TDD badge/note in PR description
    - Archive completed feature/fix

27. Clear workflow state and TDD state:
    ```json
    {
      "workflow": {
        "active": false,
        "command": null,
        "phase": null
      },
      "tdd": {
        "enabled": false,
        "phase": null,
        "testsWritten": [],
        "testStatus": null
      }
    }
    ```

28. Report completion:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ TDD Workflow Complete                                       │
    │     Feature: feature-012                                        │
    │     Tests: 15 written, 15 passing                               │
    │     PR: #43                                                     │
    │     TDD Phases: RED → GREEN → REFACTOR ✓                        │
    └─────────────────────────────────────────────────────────────────┘
    ```

## Resume Behavior

29. `/claude-harness:do-tdd resume`:
    - Read `.claude-harness/loops/state.json`
    - Check `tdd.phase` to determine where to resume:
      - `red`: Resume writing tests
      - `green`: Resume implementation
      - `refactor`: Resume refactoring
    - If no active workflow: Show error "No active TDD workflow to resume"

30. `/claude-harness:do-tdd feature-012` (existing feature):
    - Check if feature exists and has TDD enabled
    - Resume from current TDD phase
    - If feature was started with `/do` (not TDD): Warn and offer to enable TDD

## Error Handling

31. If interrupted at any TDD phase:
    - TDD state is preserved in loops/state.json
    - SessionStart hook will show: "🧪 TDD paused at {phase} phase"
    - User can resume with `/claude-harness:do-tdd resume`

32. If tests cannot be written:
    - Offer to switch to non-TDD mode (`/claude-harness:do`)
    - Record reason in history

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/claude-harness:do-tdd` | **Interactive menu** - select from pending features (multi-select) |
| `/claude-harness:do-tdd "Add X"` | Full TDD workflow (tests first) |
| `/claude-harness:do-tdd --fix feature-001 "Bug Y"` | TDD bug fix |
| `/claude-harness:do-tdd feature-001` | Resume TDD feature |
| `/claude-harness:do-tdd resume` | Resume last TDD workflow |
| `/claude-harness:do-tdd --quick "Simple"` | Skip planning, tests still required |
| `/claude-harness:do-tdd --auto "Add Z"` | No prompts, TDD enforced |
| `/claude-harness:do-tdd --plan-only "Big"` | Plan with test specs only |

## Key Differences from `/do`

| Aspect | `/do` | `/do-tdd` |
|--------|-------|-----------|
| Test timing | After implementation | BEFORE implementation |
| Test check | Verification only | Existence gate + verification |
| Phase order | Plan → Implement → Verify | Plan → Tests → Implement → Verify |
| Commit message | `feat(X): desc` | `feat(X): desc [TDD]` |
| Failure mode | Fails on test failure | Fails if no tests exist |
