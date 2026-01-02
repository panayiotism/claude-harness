---
description: Save session progress - commits, pushes, creates/updates PR, archives completed features
---

Create a checkpoint of the current session:

## Phase 1: Update Progress

1. Update `.claude-harness/claude-progress.json` with:
   - Summary of what was accomplished this session
   - Any blockers encountered
   - Recommended next steps
   - Update lastUpdated timestamp

## Phase 1.5: Capture Working Context

1.5. Update `.claude-harness/working-context.json` with current working state:
   - Read `.claude-harness/feature-list.json` to identify active feature (first with passes=false)
   - Set `activeFeature` to the feature ID and `summary` to feature name
   - Populate `workingFiles` from:
     - Feature's `relatedFiles` array
     - Files shown in `git status` (modified/new)
     - For each file, add brief role description (one line)
   - Populate `decisions` with key architectural/implementation decisions made
   - Populate `codebaseUnderstanding` with insights about relevant code areas
   - Set `nextSteps` to immediate actionable items
   - Update `lastUpdated` timestamp

   **Keep concise**: ~25-40 lines total. This will be loaded on session resume.

   Example output:
   ```json
   {
     "version": 1,
     "lastUpdated": "2025-12-29T16:00:00.000Z",
     "activeFeature": "feature-003",
     "summary": "Add Google OAuth login",
     "workingFiles": {
       "src/auth/google.ts": "new - OAuth provider implementation",
       "src/auth/index.ts": "modified - added Google to provider registry",
       "prisma/schema.prisma": "modified - added Account model"
     },
     "decisions": [
       "Store tokens in DB, not cookies",
       "Separate Account model linked to User"
     ],
     "codebaseUnderstanding": {
       "authSystem": "Uses provider registry pattern, withAuth() middleware"
     },
     "nextSteps": [
       "Add error handling for token revocation",
       "Test OAuth callback flow"
     ]
   }
   ```

## Phase 2: Build & Test

2. Run build/test commands appropriate for the project
   - Check for errors and fix if possible
   - Report any failures

## Phase 3: Commit & Push

3. ALWAYS commit changes:
   - Stage all modified files (except secrets/env files)
   - Check loop state to determine commit prefix:
     - Read `.claude-harness/loops/state.json` (or legacy `loop-state.json`)
     - If `type` is "fix": Use `fix({linkedTo.featureId}): <description>` prefix
     - If `type` is "feature" or undefined: Use `feat({feature-id}): <description>` prefix
   - Write descriptive commit message summarizing the work
   - For fixes, include: `Fixes #{fix-issue-number}` and `Related to #{original-issue-number}`
   - Push to remote

## Phase 4: PR Management (if GitHub MCP available)

4. If on a feature/fix branch and GitHub MCP is available:
   - Check loop state type to determine if this is a feature or fix
   - Check if PR exists for this branch
   - If no PR exists:
     - Create PR with descriptive title following conventional commits:
       - For features: `feat: <description>`
       - For fixes: `fix: <description>`
       - `refactor: <description>` for refactoring
       - `docs: <description>` for documentation
     - Body should include:
       - Link to issue: "Closes #XX" or "Fixes #XX"
       - For fixes: Also reference original feature issue: "Related to #{original-issue}"
       - Summary of changes (bullet points)
       - Testing instructions
       - Breaking changes (if any)
     - Labels:
       - For features: Copy from linked issue + add `status:ready-for-review`
       - For fixes: Add `bugfix` + `linked-to:{feature-id}` + `status:ready-for-review`
   - If PR exists:
     - Update PR description with latest progress
     - Add comment summarizing checkpoint changes
     - Update labels based on current status
   - Check PR status:
     - CI/CD status
     - Review status
     - Merge conflicts
   - Update tracking:
     - For features: Update `.claude-harness/features/active.json` features array with prNumber
     - For fixes: Update `.claude-harness/features/active.json` fixes array with prNumber
   - Report PR URL and status

   **PR Title Convention (Conventional Commits):**
   - `feat:` New feature (triggers MINOR version bump)
   - `fix:` Bug fix (triggers PATCH version bump)
   - `refactor:` Code refactoring
   - `docs:` Documentation
   - `test:` Tests
   - `chore:` Maintenance

## Phase 5: Report Status

5. Report final status:
   - Build/test results
   - Commit hash and push status
   - PR URL, CI status, review status
   - Remaining work

## Phase 6: Clear Loop State (if feature/fix completed)

6. If an agentic loop just completed successfully:
   - Read `.claude-harness/loops/state.json` (or legacy `loop-state.json`)
   - If `status` is "completed" and matches current feature/fix:
     - Reset loop state to idle:
       ```json
       {
         "version": 3,
         "feature": null,
         "featureName": null,
         "type": "feature",
         "linkedTo": {
           "featureId": null,
           "featureName": null
         },
         "status": "idle",
         "attempt": 0,
         "maxAttempts": 10,
         "startedAt": null,
         "lastAttemptAt": null,
         "verification": {},
         "history": [],
         "lastCheckpoint": "{commit-hash}",
         "escalationRequested": false
       }
       ```
     - Report: "Loop completed and reset" (indicate if it was a feature or fix)
   - If loop is still in progress, preserve state for session continuity

## Phase 7: Archive Completed Features and Fixes

7. Archive completed features and fixes:
   - Read `.claude-harness/features/active.json` (or legacy `feature-list.json`)

   **Archive features:**
   - Find all features with status="passing" or passes=true
   - If any completed features exist:
     - Read `.claude-harness/features/archive.json` (create if missing with `{"version":3,"archived":[],"archivedFixes":[]}`)
     - Add archivedAt timestamp to each completed feature
     - Append completed features to the `archived[]` array
     - Remove completed features from features array
   - Report: "Archived X completed features"

   **Archive fixes:**
   - Find all fixes with status="passing"
   - If any completed fixes exist:
     - Add archivedAt timestamp to each completed fix
     - Append completed fixes to the `archivedFixes[]` array
     - Remove completed fixes from fixes array
   - Report: "Archived X completed fixes"

   - Write updated `.claude-harness/features/active.json` and `.claude-harness/features/archive.json`

## Phase 8: Persist Orchestration Memory

8. Persist orchestration memory (if .claude-harness/agent-context.json exists):
   - Read `.claude-harness/agent-context.json`
   - Read `.claude-harness/agent-memory.json` (create if missing)

   - For each entry in `agentResults`:
     - If status is "completed":
       - Add to `.claude-harness/agent-memory.json.successfulApproaches` with:
         - task: the task description
         - approach: summary of what the agent did
         - agents: [agent name]
         - successRate: 1.0
       - Update `.claude-harness/agent-memory.json.agentPerformance[agent]`:
         - Increment tasksCompleted
         - Update successRate
     - If status is "failed":
       - Add to `.claude-harness/agent-memory.json.failedApproaches` with:
         - task: the task description
         - reason: failure reason
         - recordedAt: timestamp

   - If `sharedState.discoveredPatterns` has new entries:
     - Merge into `.claude-harness/agent-memory.json.learnedPatterns`

   - If `architecturalDecisions` has entries:
     - Keep in .claude-harness/agent-context.json (these persist across sessions)

   - Clear `agentResults` array (already persisted to memory)
   - Clear `pendingHandoffs` if all work is complete
   - Set `currentSession` to null
   - Update `lastUpdated` timestamp

   - Write updated `.claude-harness/agent-context.json` and `.claude-harness/agent-memory.json`
   - Report: "Persisted X agent results to memory"
