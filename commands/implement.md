---
description: Start or resume an agentic loop to implement a feature until verification passes
argumentsPrompt: Feature ID to implement (e.g., feature-001)
---

Implement a feature using a persistent agentic loop that continues until verification passes:

Arguments: $ARGUMENTS

## Core Principle (from Anthropic)
"Claude marked features complete without proper testing" - NEVER trust self-assessment. Always run actual verification commands.

## Phase 0: Load Loop State

1. Check for existing loop state:
   - Read `.claude-harness/loops/state.json` (or legacy `loop-state.json`)
   - If `status` is "in_progress" and matches $ARGUMENTS:
     - Display: "Resuming loop for {feature} at attempt {attempt}/{maxAttempts}"
     - Load history of previous attempts
   - If no active loop or different feature:
     - Initialize new loop state

2. Read feature definition:
   - Parse $ARGUMENTS as feature ID (supports both feature-XXX and fix-XXX)
   - Read `.claude-harness/features/active.json` (or legacy `feature-list.json`)
   - Extract feature/fix details including `verificationCommands`
   - If `verificationCommands` is missing, detect or ask user

3. Initialize/update `.claude-harness/loops/state.json`:
   ```json
   {
     "version": 3,
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

## Phase 0.5: Query Failure Memory (BEFORE Implementation)

4. **Query procedural memory for similar past failures**:
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
     │  2. {approach} → {rootCause}                                   │
     │     Prevention: {prevention}                                   │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - Use these to inform approach selection (avoid repeating failures)

5. **Query procedural memory for successful approaches**:
   - Read `.claude-harness/memory/procedural/successes.json`
   - Filter entries for similar file patterns or feature types
   - If matching successes found:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  ✅ SUCCESSFUL APPROACHES TO CONSIDER                          │
     ├─────────────────────────────────────────────────────────────────┤
     │  • {approach} - worked for {feature}                           │
     │  • {approach} - worked for {feature}                           │
     └─────────────────────────────────────────────────────────────────┘
     ```
   - Use these as potential starting points

## Phase 1: Health Check

6. Before attempting any work, verify the environment is healthy:
   - Run build command (if defined) to ensure app isn't broken
   - If health check fails:
     - Check git status for uncommitted changes
     - Attempt `git stash` or inform user
     - If still failing, this is attempt 0 - fixing baseline

7. Report health status:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  AGENTIC LOOP: {feature-name}                                   │
   ├─────────────────────────────────────────────────────────────────┤
   │  Health Check: ✅ PASSED (build succeeds, tests baseline)       │
   │  Attempt: {n}/{maxAttempts}                                     │
   │  Previous attempts: {count}                                     │
   └─────────────────────────────────────────────────────────────────┘
   ```

## Phase 2: Attempt Implementation

8. Read attempt history to understand what was tried:
   - If history exists, summarize:
     - What approaches were tried
     - What errors occurred
     - What files were modified
   - Use this to avoid repeating failed approaches

9. Plan the current attempt:
   - Read feature description and verification criteria
   - If first attempt: Plan fresh approach
   - If retry: Analyze previous errors and plan different approach
   - Document the approach in loop state before executing

10. Execute the implementation:
   - Work on the feature following the planned approach
   - Make code changes as needed
   - Document key decisions made

11. Update loop state after attempt:
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

12. Run ALL verification commands:
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

13. Collect verification results:
    - For each command, capture:
      - Exit code (0 = pass, non-zero = fail)
      - stdout/stderr output
      - Specific error messages

14. Determine overall result:
    - ALL commands must pass for success
    - Any failure = overall failure
    - Parse error output to identify specific issues

## Phase 4: Handle Result

### If ALL Verification Passes:

15. Celebration and checkpoint:
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

16. **Record success to procedural memory**:
    - Read `.claude-harness/memory/procedural/successes.json`
    - Append new entry:
      ```json
      {
        "id": "{uuid}",
        "timestamp": "{ISO timestamp}",
        "feature": "{feature-id}",
        "type": "feature",
        "linkedTo": null,
        "approach": "{description of what worked}",
        "files": ["{modified files}"],
        "verificationResults": {
          "build": "passed",
          "tests": "passed",
          "lint": "passed",
          "typecheck": "passed"
        },
        "patterns": ["{reusable patterns discovered}"],
        "lessons": ["{key learnings}"]
      }
      ```
    - Write updated file
    - This enables future implementations to learn from successes

17. Create git checkpoint:
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

18. Update loop state to completed:
    ```json
    {
      "status": "completed",
      "completedAt": "{timestamp}",
      "totalAttempts": {n},
      "finalCommit": "{commit-hash}",
      "history": [..., {
        "attempt": {n},
        "result": "passed",
        "verificationResults": {
          "build": "passed",
          "tests": "passed",
          "lint": "passed",
          "typecheck": "passed"
        }
      }]
    }
    ```

19. Update features/active.json:
    - Set `passes: true` or `status: "passing"`

20. Report success and next steps:
    - Recommend: `/claude-harness:checkpoint` to push and create PR

### If Verification Fails:

21. Analyze failures:
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

22. Parse and categorize errors:
    - Extract specific error messages
    - Identify affected files and line numbers
    - Categorize: type errors, test failures, lint issues, runtime errors

23. **Record failure to procedural memory**:
    - Read `.claude-harness/memory/procedural/failures.json`
    - Append new entry:
      ```json
      {
        "id": "{uuid}",
        "timestamp": "{ISO timestamp}",
        "feature": "{feature-id}",
        "type": "feature",
        "linkedTo": null,
        "attempt": {n},
        "approach": "{description of what was tried}",
        "files": ["{affected files}"],
        "errors": ["{error messages}"],
        "rootCause": "{analysis of why it failed}",
        "tags": ["{error-type}", "{category}"],
        "prevention": "{how to avoid in future}"
      }
      ```
    - Write updated file
    - This enables future implementations to avoid repeating mistakes

24. Update loop state with failure details:
    ```json
    {
      "history": [..., {
        "attempt": {n},
        "result": "failed",
        "errors": [
          "TS2322: Type 'string' is not assignable to type 'number' at src/auth.ts:42",
          "Test: auth.test.ts - expected 200, got 401"
        ],
        "verificationResults": {
          "build": "passed",
          "tests": "failed",
          "lint": "passed",
          "typecheck": "failed"
        }
      }]
    }
    ```

25. Check attempt count:
    - If `attempt < maxAttempts`: Continue to Phase 5 (Retry)
    - If `attempt >= maxAttempts`: Go to Phase 6 (Escalation)

## Phase 5: Retry

26. Increment attempt counter and save state:
    ```json
    {
      "attempt": {n+1},
      "lastAttemptAt": "{timestamp}"
    }
    ```

27. Analyze what went wrong:
    - Review the specific errors
    - Compare with previous attempts to avoid repeating
    - Identify if approach needs fundamental change or just fixes

28. Plan new approach:
    - If same errors recurring: Try fundamentally different approach
    - If new errors: Fix specific issues
    - Document new plan in loop state

29. Return to Phase 2 (Attempt Implementation)
    - Continue the loop until success or max attempts

## Phase 6: Escalation

30. If max attempts reached without success:
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
    │  Recurring Issues:                                              │
    │  - {pattern of failures}                                        │
    │                                                                 │
    │  Recommendation:                                                │
    │  {suggested human intervention or alternative approach}         │
    └─────────────────────────────────────────────────────────────────┘
    ```

31. Update loop state:
    ```json
    {
      "status": "escalated",
      "escalationRequested": true,
      "escalationReason": "{summary of why automation couldn't complete}",
      "escalatedAt": "{timestamp}"
    }
    ```

32. Offer options:
    - Increase maxAttempts and continue: `/claude-harness:implement {feature-id} --max-attempts 20`
    - Get human guidance and retry
    - Abort and preserve progress

## Session Continuity

If context window runs out during a loop:

33. Loop state is preserved in `.claude-harness/loops/state.json`

34. SessionStart hook will display:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  🔄 ACTIVE LOOP: {feature-id} (attempt {n}/{max})               │
    │     Last: "{approach summary}" → {result}                       │
    │     Resume: /claude-harness:implement {feature-id}              │
    └─────────────────────────────────────────────────────────────────┘
    ```

35. Running `/claude-harness:implement {feature-id}` resumes from Phase 0

## Loop Control Commands

- Resume loop: `/claude-harness:implement {feature-id}`
- Check status: Read `.claude-harness/loops/state.json`
- Abort loop: Set `status: "aborted"` in loops/state.json
- Increase attempts: `/claude-harness:implement {feature-id} --max-attempts {n}`
