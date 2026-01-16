---
description: Unified workflow - create, plan, and implement features or fixes
argument-hint: ["DESCRIPTION" | FEATURE-ID | (empty for interactive menu)] [--inline] [--quick] [--auto]
---

Unified command that orchestrates the complete development workflow:

Arguments: $ARGUMENTS

## Phase 0: Interactive Selection (if no arguments)

If `/do` is called without arguments, show an interactive menu of incomplete features:

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
     - Description: `{name} [{status}]`
   - For each incomplete fix:
     - Label: `{id}`
     - Description: `{name} (fix for {linkedTo.featureId}) [{status}]`

5. **Handle empty state**:
   - If no incomplete features/fixes exist:
     - Use **AskUserQuestion** with single-select:
       - Question: "No pending features. What would you like to create?"
       - Options:
         - Label: "New feature", Description: "Create a new feature from description"
         - Label: "New bug fix", Description: "Create a bug fix linked to an existing feature"
     - If "New feature": Use **AskUserQuestion** to prompt for description
     - If "New bug fix": Use **AskUserQuestion** to prompt for feature ID, then description
     - Set `$ARGUMENTS` to the entered description or `--fix` command
     - Continue to Phase 1

6. **Show interactive selection menu**:

   **CRITICAL: You MUST use `multiSelect: true` to allow parallel feature selection.**

   - Use **AskUserQuestion** with these EXACT parameters:
     - `multiSelect`: **MUST be `true`** (enables selecting multiple features for parallel worktrees)
     - `question`: "Which feature(s) do you want to work on? Select multiple for parallel development."
     - `header`: "Features"

   Example:
     ```json
     {
       "questions": [{
         "question": "Which feature(s) do you want to work on? Select multiple for parallel development.",
         "header": "Features",
         "multiSelect": true,
         "options": [
           {"label": "feature-001", "description": "Add authentication [in_progress]"},
           {"label": "feature-002", "description": "Dark mode support [pending]"},
           {"label": "fix-feature-001-001", "description": "Token bug (fix for feature-001) [pending]"}
         ]
       }]
     }
     ```

   **DO NOT use `multiSelect: false`** - this defeats the purpose of parallel development.

   - Note: User can always select "Other" to create a new feature

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
     │  ✅ WORKTREES READY FOR SELECTED FEATURES                       │
     ├─────────────────────────────────────────────────────────────────┤
     │  Feature         Path                           Status          │
     │  ─────────────────────────────────────────────────────────────  │
     │  feature-001     ../myproject-feature-001/      ✅ Ready        │
     │  feature-002     ../myproject-feature-002/      ✅ Created      │
     │  fix-feature-001 ../myproject-fix-feature-001/  ✅ Ready        │
     ├─────────────────────────────────────────────────────────────────┤
     │  🎯 NEXT STEPS:                                                 │
     │                                                                 │
     │  Open separate terminals for each feature:                      │
     │                                                                 │
     │  Terminal 1:                                                    │
     │    cd ../myproject-feature-001 && claude                        │
     │    /claude-harness:do feature-001                               │
     │                                                                 │
     │  Terminal 2:                                                    │
     │    cd ../myproject-feature-002 && claude                        │
     │    /claude-harness:do feature-002                               │
     │                                                                 │
     │  ... (one per selected feature)                                 │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - **STOP HERE** - User needs to open separate terminals
   - Do NOT continue to Phase 1

   **If user selects "Other"**:
   - Use **AskUserQuestion** to prompt for new feature description
   - Set `$ARGUMENTS` to the entered description
   - Continue to Phase 1 (will create new feature)

---

## Argument Parsing

1. Detect argument type:
   - If starts with `--fix <feature-id>`: Create bug fix linked to feature
   - If matches `feature-\d+`: Resume existing feature
   - If matches `fix-feature-\d+-\d+`: Resume existing fix
   - If "resume": Resume last active workflow
   - Otherwise: Create new feature from description

2. Parse options:
   - `--fix <feature-id>`: Create bug fix linked to specified feature
   - `--inline`: Skip worktree creation, work in current directory (for quick fixes)
   - `--quick`: Skip planning phase (for simple tasks)
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
     - body: Include acceptance criteria, verification steps
     - labels: `["feature", "claude-harness"]`
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
     - verification: Generate reasonable verification steps
     - verificationCommands: Auto-detect from project (build, test, lint, typecheck)
     - maxAttempts: 10
     - github: { issueNumber: {from 3b}, prNumber: null, branch: "feature/feature-XXX" }

## Phase 1a: Fix Creation (if --fix flag)

**CRITICAL: GitHub issue and branch MUST be created BEFORE any code work begins.**

3a. If creating bug fix (`--fix <feature-id> "description"`):

   **Step 3a.1: Validate Original Feature**
   - Search in `.claude-harness/features/active.json` features array
   - Search in `.claude-harness/features/archive.json` archived array
   - Extract feature details (name, issueNumber, verification commands)
   - **STOP AND ERROR** if feature not found

   **Step 3a.2: Generate Fix ID and Branch Name**
   - Generate fix ID: `fix-{feature-id}-{NNN}` (zero-padded sequential)
   - Generate branch name: `fix/{feature-id}-{slug}` (slug from description, max 30 chars)

   **Step 3a.3: Create GitHub Issue (MANDATORY if GitHub MCP available)**
   - **First, parse owner/repo from git remote** (MANDATORY):
     ```bash
     REMOTE_URL=$(git remote get-url origin 2>/dev/null)
     # SSH: git@github.com:owner/repo.git → owner, repo
     # HTTPS: https://github.com/owner/repo.git → owner, repo
     ```
     CRITICAL: Always run this command fresh. NEVER guess or cache owner/repo.
   - Create issue using `mcp__github__create_issue`:
     - owner: Parsed from REMOTE_URL
     - repo: Parsed from REMOTE_URL
     - title: `fix: {description}`
     - body: Link to original issue, bug description
     - labels: `["bugfix", "claude-harness", "linked-to:{feature-id}"]`
   - Add comment to original feature issue: "Bug fix created: #{new-issue}"
   - **DO NOT PROCEED** without issue creation (if MCP available)

   **Step 3a.4: Create and Checkout Fix Branch (MANDATORY)**
   - Create branch using `mcp__github__create_branch`:
     - branch: `fix/{feature-id}-{slug}`
     - from_branch: `main` (or default branch)
   - **IMMEDIATELY checkout the branch locally**:
     ```bash
     git fetch origin
     git checkout fix/{feature-id}-{slug}
     ```
   - **VERIFY you are on the fix branch before ANY code work**:
     ```bash
     git branch --show-current  # Must show fix/{feature-id}-{slug}
     ```
   - **STOP AND ERROR** if not on fix branch

   **Step 3a.5: Create Fix Entry**
   - Inherit verification commands from original feature
   - Add to `.claude-harness/features/active.json` fixes array:
     ```json
     {
       "id": "fix-{feature-id}-{NNN}",
       "name": "{bug description}",
       "linkedTo": {
         "featureId": "{original-feature-id}",
         "featureName": "{original-feature-name}",
         "issueNumber": {original-issue-number}
       },
       "type": "bugfix",
       "status": "pending",
       "verification": { ...inherited, "inherited": true },
       "github": { "issueNumber": {from 3a.3}, "branch": "fix/{feature-id}-{slug}" }
     }
     ```

   **Step 3a.6: Load Context**
   - Query procedural memory for original feature's learnings
   - Display fix context (past successes/failures for this feature)

## Phase 1b: Worktree Creation (unless --inline)

**By default, every new feature gets its own worktree for parallel work isolation.**

4. If NOT --inline flag (default behavior):

   **Step 4a: Calculate Worktree Path**
   - Get repo name: `basename $(pwd)`
   - Get feature slug from ID or branch name
   - Calculate path: `../{repo-name}-{feature-id}/`

   **Step 4b: Create Worktree**
   - Run: `git worktree add <path> <branch>`
   - If branch exists remotely, use: `git worktree add <path> <branch>`
   - If branch was just created, use: `git worktree add <path> -b <branch>`

   **Step 4c: Initialize Harness in Worktree**
   - Create `.claude-harness/` directory in worktree
   - Create `sessions/` subdirectory for session-scoped state
   - DO NOT copy `features/` or `memory/` - read from main repo

   **Step 4d: Environment Setup**
   - Copy environment files from main repo:
     - `.env`, `.env.local`, `.env.development.local` (if exist)
     - `.claude/settings.local.json` (if exists)
   - Detect and run package manager:
     - `package.json` → `npm install`
     - `requirements.txt` → `pip install -r requirements.txt`
     - `Cargo.toml` → `cargo build`
     - `go.mod` → `go mod download`

   **Step 4e: Register Worktree**
   - Read `.claude-harness/worktrees/registry.json` (create if missing)
   - Add entry with featureId, branch, path, createdAt, status: "active"
   - Write updated registry

   **Step 4f: Display Instructions and STOP**
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  ✅ FEATURE CREATED WITH WORKTREE                               │
   ├─────────────────────────────────────────────────────────────────┤
   │  Feature: {feature-id}                                          │
   │  Name: {feature description}                                    │
   │  Branch: {branch-name}                                          │
   │  Issue: #{issue-number}                                         │
   │  Worktree: {worktree-path}                                      │
   ├─────────────────────────────────────────────────────────────────┤
   │  Environment Setup: ✅ Complete                                 │
   │  • Copied .env files                                            │
   │  • Ran npm install (if applicable)                              │
   ├─────────────────────────────────────────────────────────────────┤
   │  🎯 NEXT STEPS (to continue implementation):                    │
   │                                                                 │
   │  1. Open new terminal                                           │
   │  2. cd {worktree-path}                                          │
   │  3. claude                                                      │
   │  4. /claude-harness:do {feature-id}                             │
   └─────────────────────────────────────────────────────────────────┘
   ```
   - **IMPORTANT**: STOP HERE when worktree is created
   - Implementation must continue in the worktree directory
   - User needs to start new Claude session in worktree

5. If --inline flag (skip worktree):
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  ✅ Feature Created: feature-012                                │
   │     Branch: feature/feature-012                                 │
   │     Issue: #42                                                  │
   │     Mode: Inline (no worktree)                                  │
   ├─────────────────────────────────────────────────────────────────┤
   │  Continue to planning? [Y/n/skip]                               │
   └─────────────────────────────────────────────────────────────────┘
   ```
   - Y (default): Continue to planning
   - n: Stop here, return control to user
   - skip: Skip planning, go directly to implementation

6. Update workflow state in session-scoped loop file `.claude-harness/sessions/{session-id}/loop-state.json`:
   **Note**: The session ID is provided by the SessionStart hook. All workflow state for this session should use the session directory.
   ```json
   {
     "workflow": {
       "active": true,
       "command": "do",
       "phase": "creating",
       "options": { "quick": false, "auto": false, "planOnly": false },
       "startedAt": "{ISO timestamp}"
     }
   }
   ```

## Phase 2: Planning (unless --quick)

6. Load context:
   - Read compiled context from session-scoped path: `.claude-harness/sessions/{session-id}/context.json`
   - Read semantic memory for project architecture
   - Query procedural memory for past failures/successes on similar work

7. Analyze requirements:
   - Break down feature into sub-tasks
   - Identify files to create/modify
   - Identify dependencies on other features/modules

8. Impact analysis:
   - Read `.claude-harness/impact/dependency-graph.json` (if exists)
   - For each file to modify: identify dependent files
   - Calculate impact score (low/medium/high)

9. Check past approaches:
   - Read `.claude-harness/memory/procedural/failures.json`
   - If planned approach matches past failure:
     - Warn about similar past failure
     - Show root cause and prevention tips
     - Suggest alternative from successes.json

10. Generate implementation plan and update feature:
    ```json
    {
      "plan": {
        "steps": [
          {"step": 1, "description": "...", "files": [...]},
          ...
        ],
        "estimatedFiles": ["file1.ts", "file2.ts"],
        "impactScore": "low|medium|high",
        "risks": ["..."],
        "mitigations": ["..."]
      }
    }
    ```

11. Interactive checkpoint (unless --auto):
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  📋 Implementation Plan Ready                                   │
    │     Steps: 4 | Files: 3 | Impact: medium                        │
    │     ⚠️  1 past failure on similar approach                      │
    ├─────────────────────────────────────────────────────────────────┤
    │  Start implementation? [Y/n/show]                               │
    └─────────────────────────────────────────────────────────────────┘
    ```
    - Y (default): Start implementation
    - n: Stop here
    - show: Display full plan details

12. Update workflow phase to "planning" then "planned"

13. If --plan-only: Stop here with message:
    ```
    Plan complete. Run `/claude-harness:do feature-012` to implement.
    ```

## Phase 3: Implementation

**CRITICAL SAFETY CHECK: Verify branch before ANY code changes.**

14. **Branch Verification (MANDATORY - NEVER SKIP)**
    ```bash
    CURRENT_BRANCH=$(git branch --show-current)
    EXPECTED_BRANCH=$(cat .claude-harness/features/active.json | grep -o '"branch": "[^"]*"' | head -1 | cut -d'"' -f4)
    ```
    - If on `main` or `master`: **STOP IMMEDIATELY**
      ```
      ┌─────────────────────────────────────────────────────────────────┐
      │  ❌ SAFETY ERROR: Cannot implement on main branch!              │
      │     Current branch: main                                        │
      │     Expected branch: {feature-branch}                           │
      ├─────────────────────────────────────────────────────────────────┤
      │  Run: git checkout {feature-branch}                             │
      │  Then resume with: /claude-harness:do {feature-id}               │
      └─────────────────────────────────────────────────────────────────┘
      ```
    - If branch doesn't exist locally, fetch and checkout:
      ```bash
      git fetch origin
      git checkout {expected-branch}
      ```
    - **DO NOT PROCEED** until on correct feature/fix branch

15. Update workflow phase to "implementing"

16. Initialize or resume agentic loop:
    - If resuming: Load state from session-scoped path: `.claude-harness/sessions/{session-id}/loop-state.json`
    - If session file doesn't exist, check legacy path: `.claude-harness/loops/state.json`
    - If new: Initialize loop state in session directory with version 3 schema

17. Query procedural memory:
    - Show past failures to avoid
    - Show successful approaches to consider

18. Health check:
    - Run build command to ensure baseline isn't broken
    - If fails: attempt git stash or inform user

19. Execute implementation loop:
    - Plan current attempt (avoiding past failures)
    - Execute implementation
    - Document approach in loop state
    - Run ALL verification commands (MANDATORY - NEVER SKIP)
    - If ALL pass: Record success, commit, continue to checkpoint
    - If ANY fail: Record failure to procedural memory, retry (up to maxAttempts)

20. On verification success:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ Feature Complete: feature-012                               │
    │     Attempts: 2 | Verification: ✅ All Passed                   │
    ├─────────────────────────────────────────────────────────────────┤
    │  Create checkpoint (commit + PR)? [Y/n]                         │
    └─────────────────────────────────────────────────────────────────┘
    ```

21. On escalation (max attempts reached):
    - Show attempt summary
    - Offer options: increase attempts, get human help, abort

## Phase 4: Checkpoint (if confirmed or --auto)

22. Update workflow phase to "checkpoint"

23. If user confirms (or --auto):
    - Update `.claude-harness/claude-progress.json`
    - Persist to memory layers (episodic, semantic, procedural)
    - **Auto-reflect**: Scan conversation for user corrections
      - Extract learned rules from corrections
      - Save to `.claude-harness/memory/learned/rules.json`
      - Report: "Learned {N} rules from this session"
    - Commit all changes with appropriate prefix:
      - Feature: `feat(feature-XXX): description`
      - Fix: `fix({linkedTo.featureId}): description`
    - Push to remote
    - Create/update PR (if GitHub MCP available)
    - Archive completed feature/fix to `.claude-harness/features/archive.json`

24. Clear workflow state (in session-scoped file):
    ```json
    {
      "workflow": {
        "active": false,
        "command": null,
        "phase": null
      }
    }
    ```

25. Report completion:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ Workflow Complete                                           │
    │     Feature: feature-012                                        │
    │     PR: #43                                                     │
    │     Archived: Yes                                               │
    └─────────────────────────────────────────────────────────────────┘
    ```

## Resume Behavior

26. `/claude-harness:do resume`:
    - Read session-scoped loop state: `.claude-harness/sessions/{session-id}/loop-state.json`
    - If session file doesn't exist, check legacy: `.claude-harness/loops/state.json`
    - If workflow.active is true: Resume from workflow.phase
    - If no active workflow: Show error "No active workflow to resume"

27. `/claude-harness:do feature-012` (existing feature):
    - Check if feature exists in active.json
    - If exists with active workflow: Resume from current phase
    - If exists without workflow: Start from planning phase
    - If not exists: Error "Feature not found"

## Error Handling

28. If interrupted at any phase:
    - State is preserved in session-scoped file: `.claude-harness/sessions/{session-id}/loop-state.json`
    - SessionStart hook will show: "🔄 Workflow paused at {phase}"
    - User can resume with `/claude-harness:do resume` or `/claude-harness:do feature-XXX`
    - **Note**: Each session has its own state, so parallel sessions don't conflict

29. If any phase fails:
    - Preserve state for debugging
    - Show clear error message
    - Offer recovery options

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/claude-harness:do` | **Interactive menu** - select from pending features (multi-select) |
| `/claude-harness:do "Add X"` | Creates feature + worktree, pauses for user to enter worktree |
| `/claude-harness:do --inline "Quick fix"` | Skip worktree, work in current directory |
| `/claude-harness:do --fix feature-001 "Bug Y"` | Create bug fix linked to feature (also creates worktree) |
| `/claude-harness:do feature-001` | Resume existing feature (in current directory or worktree) |
| `/claude-harness:do fix-feature-001-001` | Resume existing fix |
| `/claude-harness:do resume` | Resume last active workflow |
| `/claude-harness:do --quick "Simple change"` | Skip planning phase (still creates worktree) |
| `/claude-harness:do --inline --quick "Tiny fix"` | No worktree + no planning (fastest) |
| `/claude-harness:do --auto "Add Z"` | No prompts, full automation |
| `/claude-harness:do --plan-only "Big feature"` | Plan only, implement later |
