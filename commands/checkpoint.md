---
description: Save session progress - commits, pushes, creates/updates PR, archives completed features
---

Create a checkpoint of the current session:

## Phase 1: Update Progress

1. Update `claude-progress.json` with:
   - Summary of what was accomplished this session
   - Any blockers encountered
   - Recommended next steps
   - Update lastUpdated timestamp

## Phase 1.5: Capture Working Context

1.5. Update `working-context.json` with current working state:
   - Read `feature-list.json` to identify active feature (first with passes=false)
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
   - Write descriptive commit message summarizing the work
   - Push to remote

## Phase 4: PR Management (if GitHub MCP available)

4. If on a feature branch and GitHub MCP is available:
   - Check if PR exists for this branch
   - If no PR exists:
     - Create PR with descriptive title following conventional commits:
       - `feat: <description>` for features
       - `fix: <description>` for bug fixes
       - `refactor: <description>` for refactoring
       - `docs: <description>` for documentation
     - Body should include:
       - Link to issue: "Closes #XX" or "Fixes #XX"
       - Summary of changes (bullet points)
       - Testing instructions
       - Breaking changes (if any)
     - Labels: Copy from linked issue + add `status:ready-for-review`
   - If PR exists:
     - Update PR description with latest progress
     - Add comment summarizing checkpoint changes
     - Update labels based on current status
   - Check PR status:
     - CI/CD status
     - Review status
     - Merge conflicts
   - Update feature-list.json with prNumber
   - Report PR URL and status

   **PR Title Convention (Conventional Commits):**
   - `feat:` New feature
   - `fix:` Bug fix
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

## Phase 6: Archive Completed Features

6. Archive completed features (to prevent feature-list.json from growing too large):
   - Read feature-list.json
   - Find all features with passes=true
   - If any completed features exist:
     - Read feature-archive.json (create if it does not exist with {"version":1,"archived":[]})
     - Add archivedAt timestamp to each completed feature
     - Append completed features to the archived[] array
     - Write updated feature-archive.json
     - Remove completed features from feature-list.json and save
   - Report: "Archived X completed features"

## Phase 7: Persist Orchestration Memory

7. Persist orchestration memory (if agent-context.json exists):
   - Read `agent-context.json`
   - Read `agent-memory.json` (create if missing)

   - For each entry in `agentResults`:
     - If status is "completed":
       - Add to `agent-memory.json.successfulApproaches` with:
         - task: the task description
         - approach: summary of what the agent did
         - agents: [agent name]
         - successRate: 1.0
       - Update `agent-memory.json.agentPerformance[agent]`:
         - Increment tasksCompleted
         - Update successRate
     - If status is "failed":
       - Add to `agent-memory.json.failedApproaches` with:
         - task: the task description
         - reason: failure reason
         - recordedAt: timestamp

   - If `sharedState.discoveredPatterns` has new entries:
     - Merge into `agent-memory.json.learnedPatterns`

   - If `architecturalDecisions` has entries:
     - Keep in agent-context.json (these persist across sessions)

   - Clear `agentResults` array (already persisted to memory)
   - Clear `pendingHandoffs` if all work is complete
   - Set `currentSession` to null
   - Update `lastUpdated` timestamp

   - Write updated `agent-context.json` and `agent-memory.json`
   - Report: "Persisted X agent results to memory"
