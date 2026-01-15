---
description: Unified workflow - create, plan, and implement features or fixes
argument-hint: "DESCRIPTION" | FEATURE-ID | --fix FEATURE-ID "BUG" [--quick] [--auto] [--plan-only]
---

Unified command that orchestrates the complete development workflow:

Arguments: $ARGUMENTS

## Argument Parsing

1. Detect argument type:
   - If starts with `--fix <feature-id>`: Create bug fix linked to feature
   - If matches `feature-\d+`: Resume existing feature
   - If matches `fix-feature-\d+-\d+`: Resume existing fix
   - If "resume": Resume last active workflow
   - Otherwise: Create new feature from description

2. Parse options:
   - `--fix <feature-id>`: Create bug fix linked to specified feature
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

4. Interactive checkpoint (unless --auto):
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  ✅ Feature Created: feature-012                                │
   │     Branch: feature/feature-012                                 │
   │     Issue: #42                                                  │
   ├─────────────────────────────────────────────────────────────────┤
   │  Continue to planning? [Y/n/skip]                               │
   └─────────────────────────────────────────────────────────────────┘
   ```
   - Y (default): Continue to planning
   - n: Stop here, return control to user
   - skip: Skip planning, go directly to implementation

5. Update workflow state in `.claude-harness/loops/state.json`:
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
   - Read compiled context from `.claude-harness/memory/working/context.json`
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
    - If resuming: Load state from `.claude-harness/loops/state.json`
    - If new: Initialize loop state with version 3 schema

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

24. Clear workflow state:
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
    - Read `.claude-harness/loops/state.json`
    - If workflow.active is true: Resume from workflow.phase
    - If no active workflow: Show error "No active workflow to resume"

27. `/claude-harness:do feature-012` (existing feature):
    - Check if feature exists in active.json
    - If exists with active workflow: Resume from current phase
    - If exists without workflow: Start from planning phase
    - If not exists: Error "Feature not found"

## Error Handling

28. If interrupted at any phase:
    - State is preserved in loops/state.json
    - SessionStart hook will show: "🔄 Workflow paused at {phase}"
    - User can resume with `/claude-harness:do resume` or `/claude-harness:do feature-XXX`

29. If any phase fails:
    - Preserve state for debugging
    - Show clear error message
    - Offer recovery options

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/claude-harness:do "Add X"` | Full workflow with prompts |
| `/claude-harness:do --fix feature-001 "Bug Y"` | Create bug fix linked to feature |
| `/claude-harness:do feature-001` | Resume existing feature |
| `/claude-harness:do fix-feature-001-001` | Resume existing fix |
| `/claude-harness:do resume` | Resume last active workflow |
| `/claude-harness:do --quick "Simple change"` | Skip planning phase |
| `/claude-harness:do --auto "Add Z"` | No prompts, full automation |
| `/claude-harness:do --plan-only "Big feature"` | Plan only, implement later |
