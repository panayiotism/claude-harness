---
description: Save session progress - commits, pushes, creates/updates PR, archives completed features
argument-hint: "[--message COMMIT_MESSAGE]"
---

Create a checkpoint of the current session:

## Phase 0: Set Paths

1. **Set path variables**:
   - `FEATURES_FILE=".claude-harness/features/active.json"`
   - `ARCHIVE_FILE=".claude-harness/features/archive.json"`
   - `MEMORY_DIR=".claude-harness/memory/"`
   - `PROGRESS_FILE=".claude-harness/claude-progress.json"`
   - `SESSION_DIR=".claude-harness/sessions/{session-id}/"`

## Phase 1: Update Progress

1. Update `${PROGRESS_FILE}` with:
   - Summary of what was accomplished this session
   - Any blockers encountered
   - Recommended next steps
   - Update lastUpdated timestamp

## Phase 1.5: Capture Working Context

**Session Paths**: All session-specific state uses `.claude-harness/sessions/{session-id}/`. The session ID is provided by the SessionStart hook.

1.5. Update session-scoped working context `.claude-harness/sessions/{session-id}/working-context.json` with current working state:
   - Read `${FEATURES_FILE}` (from main repo in worktree mode) to identify active feature (first with passes=false)
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

## Phase 1.6: Persist to Memory Layers

1.6. **Persist session decisions to episodic memory**:
   - Read `${MEMORY_DIR}/episodic/decisions.json` (from main repo in worktree mode)
   - For each key decision made during this session:
     - Append new entry:
       ```json
       {
         "id": "{uuid}",
         "timestamp": "{ISO timestamp}",
         "feature": "{feature-id}",
         "decision": "{what was decided}",
         "rationale": "{why this decision was made}",
         "alternatives": ["{other options considered}"],
         "impact": "{files or areas affected}"
       }
       ```
   - If entries exceed `maxEntries` (default 50), remove oldest entries (FIFO)
   - Write updated file
   - Report: "Recorded {N} decisions to episodic memory"

1.7. **Update semantic memory with discovered patterns**:
   - Read `${MEMORY_DIR}/semantic/architecture.json` (from main repo in worktree mode)
   - Update based on work done this session:
     - Add new file paths to `structure.entryPoints`, `structure.components`, etc.
     - Update `patterns.naming` with discovered naming conventions
     - Update `patterns.fileOrganization` with discovered structures
     - Update `patterns.codeStyle` with observed patterns
   - Set `lastUpdated` to current timestamp
   - Write updated file

1.8. **Update semantic entities (if new concepts discovered)**:
   - Read `${MEMORY_DIR}/semantic/entities.json` (from main repo in worktree mode)
   - For new concepts/entities discovered:
     - Append entry with name, type, location, relationships
   - Write updated file

1.9. **Update procedural patterns**:
   - Read `${MEMORY_DIR}/procedural/patterns.json` (from main repo in worktree mode)
   - Extract reusable patterns from this session:
     - Code patterns that worked well
     - Naming conventions used
     - Project-specific rules learned
   - Merge into existing patterns (don't duplicate)
   - Write updated file
   - Report: "Updated procedural patterns"

## Phase 1.10: Auto-Reflect on User Corrections

1.10. **Auto-reflect is now always enabled** (part of UX simplification):
   - This phase always runs to capture learnings from the session
   - High-confidence rules are auto-saved; lower-confidence go to review queue

1.11. **Run reflection with auto mode**:
   - Execute the reflection logic (auto mode):
     - Scan conversation for user correction patterns
     - Filter for high-confidence corrections only
     - Skip interactive approval (auto mode)
   - For corrections with confidence >= `minConfidenceForAuto`:
     - Auto-approve and save to `${MEMORY_DIR}/learned/rules.json`
   - For lower confidence corrections:
     - Add to queue for manual review (don't save)

1.12. **Report auto-reflect results** (if rules extracted):
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  📚 AUTO-REFLECTION                                             │
   ├─────────────────────────────────────────────────────────────────┤
   │  High-confidence rules auto-saved: {N}                          │
   │  • {rule title}                                                 │
   │  • {rule title}                                                 │
   │                                                                 │
   │  Lower-confidence (manual review needed): {N}                   │
   │  (Low-confidence rules queued for next checkpoint review)       │
   └─────────────────────────────────────────────────────────────────┘
   ```

1.13. **If no corrections detected**:
   - Continue silently to Phase 2 (no noise if nothing found)

## Phase 2: Build & Test

2. Run build/test commands appropriate for the project
   - Check for errors and fix if possible
   - Report any failures

## Phase 3: Commit & Push

3. ALWAYS commit changes:
   - Stage all modified files (except secrets/env files)
   - Check loop state to determine commit prefix:
     - Read session-scoped loop state: `.claude-harness/sessions/{session-id}/loop-state.json`
     - If session file doesn't exist, check legacy: `.claude-harness/loops/state.json`
     - If `type` is "fix": Use `fix({linkedTo.featureId}): <description>` prefix
     - If `type` is "feature" or undefined: Use `feat({feature-id}): <description>` prefix
   - Write descriptive commit message summarizing the work
   - For fixes, include: `Fixes #{fix-issue-number}` and `Related to #{original-issue-number}`
   - Push to remote

## Phase 4: PR Management (if GitHub MCP available)

4. If on a feature/fix branch and GitHub MCP is available:
   - **Get GitHub owner/repo** (prefer cached from SessionStart):
     - First check SessionStart hook output for cached `github.owner` and `github.repo`
     - If cached values available, use them (faster, already parsed)
     - If not cached, parse from git remote:
       ```bash
       REMOTE_URL=$(git remote get-url origin 2>/dev/null)
       # SSH: git@github.com:owner/repo.git → owner, repo
       # HTTPS: https://github.com/owner/repo.git → owner, repo
       ```
   - Check loop state type to determine if this is a feature or fix
   - Check if PR exists for this branch (use parsed owner/repo)
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
     - For features: Update `${FEATURES_FILE}` features array with prNumber
     - For fixes: Update `${FEATURES_FILE}` fixes array with prNumber
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

## Phase 6: Clear Loop State and Tasks (if feature/fix completed)

6. If an agentic loop just completed successfully:
   - Read session-scoped loop state: `.claude-harness/sessions/{session-id}/loop-state.json`
   - If session file doesn't exist, check legacy: `.claude-harness/loops/state.json`
   - If `status` is "completed" and matches current feature/fix:
     - **Mark all tasks complete** (if tasks.enabled in loop-state):
       - Call `TaskList` to find feature's tasks
       - For any tasks not yet "completed", call `TaskUpdate` to mark as "completed"
       - Report: "All 5 tasks completed"
     - Reset loop state to idle (see `schemas/loop-state.schema.json` for canonical shape):
       ```json
       {
         "version": 9,
         "feature": null,
         "featureName": null,
         "type": "feature",
         "linkedTo": null,
         "status": "idle",
         "attempt": 0,
         "maxAttempts": 15,
         "startedAt": null,
         "lastAttemptAt": null,
         "verification": {},
         "history": [],
         "tasks": {
           "enabled": false,
           "chain": [],
           "current": null,
           "completed": []
         },
         "lastCheckpoint": "{commit-hash}",
         "escalationRequested": false
       }
       ```
     - Report: "Loop completed and reset" (indicate if it was a feature or fix)
   - If loop is still in progress, preserve state for session continuity
   - **Optional session cleanup**: If feature is archived and session is complete, the session directory `.claude-harness/sessions/{session-id}/` can be removed (it's gitignored anyway)

## Phase 7: Archive Completed Features and Fixes

7. Archive completed features and fixes:
   - Read `${FEATURES_FILE}` (from main repo in worktree mode)

   **Archive features:**
   - Find all features with status="passing" or passes=true
   - If any completed features exist:
     - Read `${ARCHIVE_FILE}` (create if missing with `{"version":3,"archived":[],"archivedFixes":[]}`)
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

   - Write updated `${FEATURES_FILE}` and `${ARCHIVE_FILE}`
## Phase 8: Persist Orchestration Memory

8. Persist orchestration memory (if orchestration was active):
   - Read `.claude-harness/agents/context.json` (or legacy `agent-context.json`)
   - Skip if no `currentSession` or no `agentResults`

   - For each entry in `agentResults`:
     - If status is "completed":
       - Add to `${MEMORY_DIR}/procedural/successes.json`:
         ```json
         {
           "id": "{uuid}",
           "timestamp": "{ISO timestamp}",
           "feature": "{feature-id}",
           "type": "orchestration",
           "approach": "{summary of what the agent did}",
           "agent": "{agent name}",
           "files": ["{affected files}"]
         }
         ```
     - If status is "failed":
       - Add to `${MEMORY_DIR}/procedural/failures.json`:
         ```json
         {
           "id": "{uuid}",
           "timestamp": "{ISO timestamp}",
           "feature": "{feature-id}",
           "type": "orchestration",
           "approach": "{what the agent attempted}",
           "agent": "{agent name}",
           "errors": ["{error details}"],
           "rootCause": "{analysis}"
         }
         ```

   - If `sharedState.discoveredPatterns` has new entries:
     - Merge into `${MEMORY_DIR}/procedural/patterns.json`

   - If `architecturalDecisions` has entries:
     - Persist to `${MEMORY_DIR}/episodic/decisions.json`

   - Clear `agentResults` array (already persisted to memory)
   - Set `currentSession` to null
   - Update `lastUpdated` timestamp

   - **If `teamState` is non-null** (Agent Teams was active):
     - Persist each teammate's results to `agentResults` (if not already there)
     - Set `teamState` to null (team cleanup complete)
     - Report: "Cleaned up team state for {teamState.teamName}"

   - Write updated files
   - Report: "Persisted {N} agent results to procedural memory"

## Phase 9: Context Management Recommendation

9. Display context management recommendation:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  ✅ CHECKPOINT COMPLETE                                         │
   │     Progress saved to memory layers                             │
   │     Commit: {hash}                                              │
   │     PR: #{number} (if applicable)                               │
   ├─────────────────────────────────────────────────────────────────┤
   │  💡 RECOMMENDED: Run /clear to reset context                    │
   │                                                                 │
   │     Your progress is preserved in:                              │
   │     • claude-progress.json (session summary)                    │
   │     • sessions/{id}/context.json (session working state)        │
   │     • memory/episodic/decisions.json (decisions)                │
   │     • memory/procedural/ (successes & failures)                 │
   │     • memory/learned/rules.json (learned rules)                 │
   │                                                                 │
   │     Fresh context = better performance on next task.            │
   │     Run /claude-harness:start after /clear to reload context.   │
   └─────────────────────────────────────────────────────────────────┘
   ```

   **Why clear context?**
   - Prevents "context rot" from accumulated irrelevant information
   - Reduces token costs for subsequent work
   - Improves Claude's focus on the next task
   - Memory files preserve all important learnings
