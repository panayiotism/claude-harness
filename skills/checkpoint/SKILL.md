---
name: checkpoint
description: Save session progress by committing changes, pushing to remote, creating or updating a pull request, persisting decisions and patterns to memory layers, compiling session briefing, and archiving completed features. Use when saving work, creating a PR, preserving session state, or manually checkpointing progress.
argument-hint: "[optional commit context]"
allowed-tools: "Bash(git *), Bash(gh *)"
disable-model-invocation: true
---

# Checkpoint - Save Session Progress

Create a checkpoint of the current session: commit, push, PR, memory persistence, and feature archival.

Arguments: $ARGUMENTS

Session ID: ${CLAUDE_SESSION_ID} — session state lives in `.claude-harness/sessions/${CLAUDE_SESSION_ID}/`.

## Phase 0: Set Paths

1. **Set path variables**:
   - `FEATURES_FILE=".claude-harness/features/active.json"`
   - `ARCHIVE_FILE=".claude-harness/features/archive.json"`
   - `MEMORY_DIR=".claude-harness/memory/"`
   - `PROGRESS_FILE=".claude-harness/claude-progress.json"`
   - `SESSION_DIR=".claude-harness/sessions/${CLAUDE_SESSION_ID}/"`

## Phase 1: Update Progress

1. Update `${PROGRESS_FILE}` with:
   - Summary of what was accomplished this session
   - Any blockers encountered
   - Recommended next steps
   - Update lastUpdated timestamp

## Phase 1.6: Persist to Memory Layers

1.6. **Persist session decisions to episodic memory**:
   - Read `${MEMORY_DIR}/episodic/decisions.json`
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
   - Read `${MEMORY_DIR}/semantic/architecture.json`
   - Update based on work done this session:
     - Add new file paths to `structure.entryPoints`, `structure.components`, etc.
     - Update `patterns.naming` with discovered naming conventions
     - Update `patterns.fileOrganization` with discovered structures
     - Update `patterns.codeStyle` with observed patterns
   - Set `lastUpdated` to current timestamp
   - Write updated file

1.8. **Update semantic entities (if new concepts discovered)**:
   - Read `${MEMORY_DIR}/semantic/entities.json`
   - For new concepts/entities discovered:
     - Append entry with name, type, location, relationships
   - Write updated file

1.9. **Update procedural patterns**:
   - Read `${MEMORY_DIR}/procedural/patterns.json`
   - Extract reusable patterns from this session:
     - Code patterns that worked well
     - Naming conventions used
     - Project-specific rules learned
   - Merge into existing patterns (don't duplicate)
   - Write updated file
   - Report: "Updated procedural patterns"

## Phase 1.9.5: Compile Session Briefing

1.9.5. **Write persistent session briefing** to `.claude-harness/session-briefing.md`:
   - The SessionStart hook points Claude at this file on every new session
   - It ensures Claude is immediately aware of project state on new sessions without manual `/start`
   - Compile from current state -- read features, decisions, failures, rules, and status:

   ```markdown
   # Session Briefing
   Last updated: {ISO timestamp}

   ## Active Features
   - {id}: {name} [{status}]
     {one-line description}
     Acceptance: {N} scenarios | Files: {relatedFiles summary}

   ## Recent Decisions (last 5)
   - {decision} ({feature}, {date})

   ## Approaches to AVOID
   - {approach} -> {rootCause} ({feature})

   ## Learned Rules
   - {title}: {description}

   ## Current Status
   Last checkpoint: {commit message summary}
   Branch: {current branch}
   Next steps: {immediate actionable items}
   ```

   - Keep under 120 lines (~1500 tokens) to avoid context bloat
   - Source data: `${FEATURES_FILE}`, `${MEMORY_DIR}/episodic/decisions.json`, `${MEMORY_DIR}/procedural/failures.json`, `${MEMORY_DIR}/learned/rules.json`
   - This file is git-tracked and persists across sessions, `/clear`, and machine reboots

## Phase 1.10: Auto-Reflect on User Corrections

1.10. **Auto-reflect is always enabled**:
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
   AUTO-REFLECTION
   High-confidence rules auto-saved: {N}
   - {rule title}
   - {rule title}

   Lower-confidence (manual review needed): {N}
   (Low-confidence rules queued for next checkpoint review)
   ```

1.13. **If no corrections detected**:
   - Continue silently to Phase 2 (no noise if nothing found)

## Phase 2: Build & Test

2. Run build/test commands appropriate for the project
   - Check for errors and fix if possible
   - Report any failures

## Phase 3: Commit & Push

3. ALWAYS commit changes:
   - **Stage harness state files first**: `git add .claude-harness/` (sessions/ and working/ are gitignored, so only persistent state is staged)
   - Stage all other modified files: `git add -A` (except secrets/env files)
   - Check loop state to determine commit prefix:
     - Read session-scoped loop state: `.claude-harness/sessions/${CLAUDE_SESSION_ID}/loop-state.json`
     - If `type` is "fix": Use `fix({linkedTo.featureId}): <description>` prefix
     - If `type` is "feature" or undefined: Use `feat({feature-id}): <description>` prefix
   - Write descriptive commit message summarizing the work
   - For fixes, include: `Fixes #{fix-issue-number}` and `Related to #{original-issue-number}`
   - Push with `git push -u origin {branch}`

## Phase 4: PR Management

4. If on a feature/fix branch (`gh` CLI must be authenticated -- check `gh auth status` on failure):
   - **Get GitHub owner/repo**: use the cached values from the session context (injected at SessionStart); only if absent, parse once from `git remote get-url origin`
   - Check loop state type to determine if this is a feature or fix
   - Check if a PR exists for this branch: `gh pr list --head {branch} --json number,url`
   - If no PR exists, create one:
     ```
     gh pr create --title "{title}" --body "{body}" --label "{labels}"
     ```
     - Title follows conventional commits:
       - For features: `feat: <description>`
       - For fixes: `fix: <description>`
       - `refactor: <description>` for refactoring
       - `docs: <description>` for documentation
     - Body should include:
       - Link to issue: "Closes #XX" or "Fixes #XX"
       - For fixes: Also reference original feature issue
       - Summary of changes (bullet points)
       - Testing instructions
       - Breaking changes (if any)
     - Labels:
       - For features: Copy from linked issue + add `status:ready-for-review`
       - For fixes: Add `bugfix` + `linked-to:{feature-id}` + `status:ready-for-review`
   - If PR exists:
     - Update PR description with latest progress: `gh pr edit {number} --body "{updated body}"`
     - Add comment summarizing checkpoint changes: `gh pr comment {number} --body "..."`
     - Update labels based on current status
   - Check PR status: `gh pr view {number} --json state,mergeable,reviewDecision,statusCheckRollup`
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
   - Read session-scoped loop state: `.claude-harness/sessions/${CLAUDE_SESSION_ID}/loop-state.json`
   - If `status` is "completed" and matches current feature/fix:
     - **Mark all tasks complete** (if tasks.enabled in loop-state):
       - Call `TaskList` to find the feature's tasks
       - For any tasks not yet "completed", call `TaskUpdate` to mark as "completed"
       - Report: "All 6 tasks completed"
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
         "maxAttempts": 12,
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
     - Report: "Loop completed and reset"
   - If loop is still in progress, preserve state for session continuity
   - **Optional session cleanup**: If feature is archived and session is complete, the session directory can be removed (it's gitignored anyway; the SessionEnd hook also removes it on clean exit)

## Phase 7: Archive Completed Features and Fixes

7. Archive completed features and fixes:
   - Read `${FEATURES_FILE}`

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
   - Read `.claude-harness/agents/context.json`
   - Skip if no `currentSession` or no `agentResults`

   - For each entry in `agentResults`:
     - If status is "completed":
       - Add to `${MEMORY_DIR}/procedural/successes.json`
     - If status is "failed":
       - Add to `${MEMORY_DIR}/procedural/failures.json`

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

## Phase 9: Report Completion

9. Display checkpoint summary:
   ```
   CHECKPOINT COMPLETE
   Progress saved to memory layers
   Commit: {hash}
   PR: #{number} (if applicable)

   Your progress is preserved in:
   - claude-progress.json (session summary)
   - memory/episodic/decisions.json (decisions)
   - memory/procedural/ (successes & failures)
   - memory/learned/rules.json (learned rules)
   - session-briefing.md (pointed to at next session start)
   ```

   **NOTE**: There is no need to `/clear` after a checkpoint. Feature work runs
   in isolated subagents (fresh context per feature), and Claude Code's native
   compaction preserves task-relevant context automatically. Clear only if you
   want a full manual reset.
