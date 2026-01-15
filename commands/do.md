---
description: Unified workflow - create, plan, and implement features or fixes in one command
argumentsPrompt: Feature description, feature ID, or --fix flag (e.g., "Add dark mode", "feature-001", "--fix feature-001 Bug description")
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

3. If creating new feature (no --fix flag):
   - Generate unique feature ID (feature-XXX based on existing IDs)
   - If GitHub MCP is available:
     - Create GitHub issue with title, description, labels
     - Create feature branch: `feature/feature-XXX`
     - Checkout the feature branch
   - Add to `.claude-harness/features/active.json` with:
     - id, name, description, priority
     - passes: false
     - verification: Generate reasonable verification steps
     - verificationCommands: Auto-detect from project (build, test, lint, typecheck)
     - maxAttempts: 10
     - github: { issueNumber, prNumber: null, branch }

## Phase 1a: Fix Creation (if --fix flag)

3a. If creating bug fix (`--fix <feature-id> "description"`):
    - Validate original feature exists in active.json or archive.json
    - Generate fix ID: `fix-{feature-id}-{NNN}` (zero-padded sequential)
    - Generate branch name: `fix/{feature-id}-{slug}`
    - Inherit verification commands from original feature
    - If GitHub MCP available:
      - Create issue: `fix: {description}` with link to original
      - Add comment to original issue: "Bug fix created: #{new-issue}"
      - Create and checkout fix branch
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
        "github": { "issueNumber": X, "branch": "fix/..." }
      }
      ```
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
    Plan complete. Run `/do feature-012` to implement.
    ```

## Phase 3: Implementation

14. Update workflow phase to "implementing"

15. Initialize or resume agentic loop:
    - If resuming: Load state from `.claude-harness/loops/state.json`
    - If new: Initialize loop state with version 3 schema

16. Query procedural memory (same as /implement Phase 0.5):
    - Show past failures to avoid
    - Show successful approaches to consider

17. Health check:
    - Run build command to ensure baseline isn't broken
    - If fails: attempt git stash or inform user

18. Execute implementation loop:
    - Plan current attempt (avoiding past failures)
    - Execute implementation
    - Document approach in loop state
    - Run ALL verification commands (MANDATORY - NEVER SKIP)
    - If ALL pass: Record success, commit, continue to checkpoint
    - If ANY fail: Record failure to procedural memory, retry (up to maxAttempts)

19. On verification success:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ Feature Complete: feature-012                               │
    │     Attempts: 2 | Verification: ✅ All Passed                   │
    ├─────────────────────────────────────────────────────────────────┤
    │  Create checkpoint (commit + PR)? [Y/n]                         │
    └─────────────────────────────────────────────────────────────────┘
    ```

20. On escalation (max attempts reached):
    - Show attempt summary
    - Offer options: increase attempts, get human help, abort

## Phase 4: Checkpoint (if confirmed or --auto)

21. Update workflow phase to "checkpoint"

22. If user confirms (or --auto):
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

23. Clear workflow state:
    ```json
    {
      "workflow": {
        "active": false,
        "command": null,
        "phase": null
      }
    }
    ```

24. Report completion:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ Workflow Complete                                           │
    │     Feature: feature-012                                        │
    │     PR: #43                                                     │
    │     Archived: Yes                                               │
    └─────────────────────────────────────────────────────────────────┘
    ```

## Resume Behavior

25. `/do resume`:
    - Read `.claude-harness/loops/state.json`
    - If workflow.active is true: Resume from workflow.phase
    - If no active workflow: Show error "No active workflow to resume"

26. `/do feature-012` (existing feature):
    - Check if feature exists in active.json
    - If exists with active workflow: Resume from current phase
    - If exists without workflow: Start from planning phase
    - If not exists: Error "Feature not found"

## Error Handling

27. If interrupted at any phase:
    - State is preserved in loops/state.json
    - SessionStart hook will show: "🔄 Workflow paused at {phase}"
    - User can resume with `/do resume` or `/do feature-XXX`

28. If any phase fails:
    - Preserve state for debugging
    - Show clear error message
    - Offer recovery options

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/do "Add X"` | Full workflow with prompts |
| `/do --fix feature-001 "Bug Y"` | Create bug fix linked to feature |
| `/do feature-001` | Resume existing feature |
| `/do fix-feature-001-001` | Resume existing fix |
| `/do resume` | Resume last active workflow |
| `/do --quick "Simple change"` | Skip planning phase |
| `/do --auto "Add Z"` | No prompts, full automation |
| `/do --plan-only "Big feature"` | Plan only, implement later |
