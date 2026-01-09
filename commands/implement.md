---
description: Start or resume an agentic loop to implement a feature until verification passes
argumentsPrompt: Feature ID to implement (e.g., feature-001) with optional flags (--autonomous, --max-attempts N)
---

Implement a feature using a persistent agentic loop that continues until verification passes:

Arguments: $ARGUMENTS

## Core Principle (from Anthropic)
"Claude marked features complete without proper testing" - NEVER trust self-assessment. Always run actual verification commands.

## Command Options

Parse $ARGUMENTS for:
- **Feature ID**: Required. e.g., `feature-001` or `fix-002`
- **--autonomous**: Enable Ralph-style loop continuation. Stop hook will block exit and re-feed prompt until verification passes or max attempts reached.
- **--max-attempts N**: Override default max attempts (default: 10)

Example usage:
```
/claude-harness:implement feature-010                    # Standard mode
/claude-harness:implement feature-010 --autonomous      # Ralph mode (loops until done)
/claude-harness:implement feature-010 --max-attempts 20 # Custom max attempts
```

## Phase 0: Load Loop State

1. Check for existing loop state:
   - Read `.claude-harness/loops/state.json` (or legacy `loop-state.json`)
   - If `status` is "in_progress" and matches feature ID:
     - Display: "Resuming loop for {feature} at attempt {attempt}/{maxAttempts}"
     - Load history of previous attempts
     - **Read `.claude-harness/loops/progress.txt`** for cross-context continuity
     - **Read `.claude-harness/loops/guardrails.md`** for approaches to avoid
   - If no active loop or different feature:
     - Initialize new loop state

2. Read feature definition:
   - Parse feature ID (supports both feature-XXX and fix-XXX)
   - Read `.claude-harness/features/active.json` (or legacy `feature-list.json`)
   - Extract feature/fix details including `verificationCommands`
   - If `verificationCommands` is missing, detect or ask user

3. Initialize/update `.claude-harness/loops/state.json`:
   ```json
   {
     "version": 4,
     "feature": "{feature-id}",
     "featureName": "{feature name}",
     "type": "feature",
     "linkedTo": {
       "featureId": null,
       "featureName": null
     },
     "status": "in_progress",
     "attempt": 1,
     "maxAttempts": 10,
     "autonomous": false,
     "startedAt": "{timestamp}",
     "lastAttemptAt": null,
     "verification": {
       "build": "npm run build",
       "tests": "npm run test",
       "lint": "npm run lint",
       "typecheck": "npx tsc --noEmit",
       "custom": []
     },
     "history": [],
     "lastCheckpoint": null,
     "escalationRequested": false
   }
   ```

   **Note**: Set `"autonomous": true` if `--autonomous` flag is provided.

## Phase 0.5: Query Memory (BEFORE Implementation)

4. **Read guardrails.md** (Ralph-style failure patterns):
   - Check `.claude-harness/loops/guardrails.md`
   - If exists and non-empty, display:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  🚫 GUARDRAILS - Approaches to AVOID                           │
     ├─────────────────────────────────────────────────────────────────┤
     │  {contents of guardrails.md}                                   │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - These are patterns that have failed repeatedly - DO NOT repeat them

5. **Read progress.txt** (Ralph-style cross-context log):
   - Check `.claude-harness/loops/progress.txt`
   - If exists, display last 5 entries:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  📋 RECENT PROGRESS (from previous context windows)            │
     ├─────────────────────────────────────────────────────────────────┤
     │  {last 5 lines of progress.txt}                                │
     └─────────────────────────────────────────────────────────────────┘
     ```

6. **Query procedural memory for similar past failures**:
   - Read `.claude-harness/memory/procedural/failures.json`
   - Filter entries where:
     - `files` array overlaps with feature's `relatedFiles`
     - OR `tags` match the type of work (e.g., "auth", "api", "ui")
     - OR `feature` is the same (for retries/fixes)
   - If matching failures found:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  ⚠️  SIMILAR PAST FAILURES DETECTED                            │
     ├─────────────────────────────────────────────────────────────────┤
     │  1. {approach} → {rootCause}                                   │
     │     Prevention: {prevention}                                   │
     └─────────────────────────────────────────────────────────────────┘
     ```

7. **Query procedural memory for successful approaches**:
   - Read `.claude-harness/memory/procedural/successes.json`
   - Filter entries for similar file patterns or feature types
   - If matching successes found:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  ✅ SUCCESSFUL APPROACHES TO CONSIDER                          │
     ├─────────────────────────────────────────────────────────────────┤
     │  • {approach} - worked for {feature}                           │
     └─────────────────────────────────────────────────────────────────┘
     ```

## Phase 1: Health Check

8. Before attempting any work, verify the environment is healthy:
   - Run build command (if defined) to ensure app isn't broken
   - If health check fails:
     - Check git status for uncommitted changes
     - Attempt `git stash` or inform user
     - If still failing, this is attempt 0 - fixing baseline

9. Report health status:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  AGENTIC LOOP: {feature-name}                                   │
   ├─────────────────────────────────────────────────────────────────┤
   │  Mode: {STANDARD | AUTONOMOUS (Ralph)}                          │
   │  Health Check: ✅ PASSED                                         │
   │  Attempt: {n}/{maxAttempts}                                     │
   │  Previous attempts: {count}                                     │
   └─────────────────────────────────────────────────────────────────┘
   ```

## Phase 2: Attempt Implementation

10. Read attempt history to understand what was tried:
    - If history exists, summarize:
      - What approaches were tried
      - What errors occurred
      - What files were modified
    - Use this to avoid repeating failed approaches

11. Plan the current attempt:
    - Read feature description and verification criteria
    - **Check guardrails.md** - avoid any patterns listed there
    - If first attempt: Plan fresh approach
    - If retry: Analyze previous errors and plan different approach
    - Document the approach in loop state before executing

12. Execute the implementation:
    - Work on the feature following the planned approach
    - Make code changes as needed
    - Document key decisions made

13. Update loop state after attempt:
    ```json
    {
      "history": [..., {
        "attempt": {n},
        "timestamp": "{ISO timestamp}",
        "approach": "{description of what was tried}",
        "filesModified": ["{paths}"],
        "filesCreated": ["{paths}"],
        "result": "pending_verification"
      }]
    }
    ```

## Phase 3: Verification (MANDATORY - NEVER SKIP)

14. Run ALL verification commands:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  VERIFICATION PHASE                                             │
    ├─────────────────────────────────────────────────────────────────┤
    │  ⏳ Running: npm run build                                      │
    │  ⏳ Running: npm run test                                       │
    │  ⏳ Running: npm run lint                                       │
    │  ⏳ Running: npx tsc --noEmit                                   │
    └─────────────────────────────────────────────────────────────────┘
    ```

15. Collect verification results:
    - For each command, capture:
      - Exit code (0 = pass, non-zero = fail)
      - stdout/stderr output
      - Specific error messages

16. Determine overall result:
    - ALL commands must pass for success
    - Any failure = overall failure
    - Parse error output to identify specific issues

## Phase 4: Handle Result

### If ALL Verification Passes:

17. **Log success to progress.txt**:
    ```
    echo "[{timestamp}] Attempt {n} | PASSED | Approach: {approach summary}" >> .claude-harness/loops/progress.txt
    ```

18. Celebration and checkpoint:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ VERIFICATION PASSED                                         │
    ├─────────────────────────────────────────────────────────────────┤
    │  Build:     ✅ PASSED                                           │
    │  Tests:     ✅ PASSED                                           │
    │  Lint:      ✅ PASSED                                           │
    │  Typecheck: ✅ PASSED                                           │
    ├─────────────────────────────────────────────────────────────────┤
    │  Feature complete in {n} attempts!                              │
    └─────────────────────────────────────────────────────────────────┘
    ```

19. **Record success to procedural memory**:
    - Read `.claude-harness/memory/procedural/successes.json`
    - Append new entry with approach, files, verification results, patterns, lessons
    - Write updated file

20. Create git checkpoint:
    - Stage all changes: `git add -A`
    - Commit with descriptive message:
      ```
      feat({feature-id}): {feature-name}

      Implemented via agentic loop ({n} attempts)

      Verification passed:
      - Build: ✅
      - Tests: ✅
      - Lint: ✅
      - Typecheck: ✅
      ```
    - Record commit hash in loop state

21. Update loop state to completed:
    ```json
    {
      "status": "completed",
      "completedAt": "{timestamp}",
      "totalAttempts": {n},
      "finalCommit": "{commit-hash}"
    }
    ```

22. Update features/active.json:
    - Set `passes: true`

23. Report success and next steps:
    - Recommend: `/claude-harness:checkpoint` to push and create PR

### If Verification Fails:

24. **Log failure to progress.txt** (CRITICAL for Ralph-style loops):
    ```
    echo "[{timestamp}] Attempt {n} | FAILED | Approach: {approach} | Error: {primary error message}" >> .claude-harness/loops/progress.txt
    ```
    This log persists across context windows, allowing fresh agents to learn from failures.

25. Analyze failures:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ❌ VERIFICATION FAILED                                         │
    ├─────────────────────────────────────────────────────────────────┤
    │  Build:     ✅ PASSED                                           │
    │  Tests:     ❌ FAILED - 2 tests failing                         │
    │  Lint:      ✅ PASSED                                           │
    │  Typecheck: ❌ FAILED - 3 type errors                           │
    ├─────────────────────────────────────────────────────────────────┤
    │  Attempt {n}/{maxAttempts}                                      │
    └─────────────────────────────────────────────────────────────────┘
    ```

26. Parse and categorize errors:
    - Extract specific error messages
    - Identify affected files and line numbers
    - Categorize: type errors, test failures, lint issues, runtime errors

27. **Check for repeated errors and update guardrails.md**:
    - If same error pattern appears 2+ times in progress.txt:
      ```
      echo "" >> .claude-harness/loops/guardrails.md
      echo "## Do NOT: {failed approach}" >> .claude-harness/loops/guardrails.md
      echo "Reason: {why it fails}" >> .claude-harness/loops/guardrails.md
      echo "Failed {n} times with error: {error pattern}" >> .claude-harness/loops/guardrails.md
      ```
    - This prevents future agents (and fresh contexts) from repeating the same mistake

28. **Record failure to procedural memory**:
    - Read `.claude-harness/memory/procedural/failures.json` (create if doesn't exist)
    - Append new entry with approach, files, errors, rootCause, tags, prevention
    - Write updated file

29. Update loop state with failure details:
    ```json
    {
      "history": [..., {
        "attempt": {n},
        "result": "failed",
        "errors": ["{error messages}"],
        "verificationResults": {
          "build": "passed",
          "tests": "failed",
          ...
        }
      }]
    }
    ```

30. Check attempt count:
    - If `attempt < maxAttempts`: Continue to Phase 5 (Retry)
    - If `attempt >= maxAttempts`: Go to Phase 6 (Escalation)

## Phase 5: Retry

31. Increment attempt counter and save state:
    ```json
    {
      "attempt": {n+1},
      "lastAttemptAt": "{timestamp}"
    }
    ```

32. Analyze what went wrong:
    - Review the specific errors
    - **Review guardrails.md** - ensure new approach doesn't repeat failures
    - Compare with previous attempts to avoid repeating
    - Identify if approach needs fundamental change or just fixes

33. Plan new approach:
    - If same errors recurring: Try fundamentally different approach
    - If new errors: Fix specific issues
    - Document new plan in loop state

34. Return to Phase 2 (Attempt Implementation)
    - Continue the loop until success or max attempts

## Phase 6: Escalation

35. If max attempts reached without success:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ⚠️  ESCALATION REQUIRED                                        │
    ├─────────────────────────────────────────────────────────────────┤
    │  Max attempts ({maxAttempts}) reached without success           │
    │                                                                 │
    │  Attempts Summary:                                              │
    │  1. {approach} → {error summary}                                │
    │  2. {approach} → {error summary}                                │
    │  ...                                                            │
    │                                                                 │
    │  Recurring Issues (from guardrails.md):                         │
    │  - {pattern of failures}                                        │
    │                                                                 │
    │  Recommendation:                                                │
    │  {suggested human intervention or alternative approach}         │
    └─────────────────────────────────────────────────────────────────┘
    ```

36. Update loop state:
    ```json
    {
      "status": "escalated",
      "escalationRequested": true,
      "escalationReason": "{summary of why automation couldn't complete}",
      "escalatedAt": "{timestamp}"
    }
    ```

37. Offer options:
    - Increase maxAttempts and continue: `/claude-harness:implement {feature-id} --max-attempts 20`
    - Get human guidance and retry
    - Abort and preserve progress

## Session Continuity (Ralph-Style)

If context window runs out during a loop:

38. **In AUTONOMOUS mode**: Stop hook will block exit and re-feed prompt with:
    - Current attempt count
    - Contents of guardrails.md (approaches to avoid)
    - Last 5 lines of progress.txt (what was tried)
    - Instructions to continue implementing

39. **In STANDARD mode**: Loop state is preserved in `.claude-harness/loops/state.json`
    - SessionStart hook will display active loop status
    - User can resume with `/claude-harness:implement {feature-id}`

40. Key files for cross-context persistence:
    - `.claude-harness/loops/state.json` - Current loop state
    - `.claude-harness/loops/progress.txt` - Human-readable attempt log
    - `.claude-harness/loops/guardrails.md` - Failure patterns to avoid

## Loop Control Commands

- Resume loop: `/claude-harness:implement {feature-id}`
- Start autonomous loop: `/claude-harness:implement {feature-id} --autonomous`
- Check status: Read `.claude-harness/loops/state.json`
- Abort loop: Set `status: "aborted"` in loops/state.json
- Increase attempts: `/claude-harness:implement {feature-id} --max-attempts {n}`

## Ralph Mode Philosophy

When using `--autonomous`, the loop embodies these principles:
1. **Iteration beats perfection** - Keep trying until verification passes
2. **Progress persists in files, not context** - progress.txt and git history survive context rotation
3. **Failures are data** - guardrails.md captures patterns to avoid
4. **Fresh context avoids accumulated confusion** - Each iteration starts with clean slate + learned guardrails
