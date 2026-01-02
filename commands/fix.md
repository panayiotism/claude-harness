---
description: Create and implement a bug fix linked to an original feature
argumentsPrompt: Feature ID to fix, followed by bug description (e.g., feature-001 "Token expiry not handled")
---

Create a bug fix linked to an original feature and implement it using the agentic loop:

Arguments: $ARGUMENTS

## Core Principle
Bug fixes are linked to their original features for context. They share memory,
verification commands, and contribute learnings back to the feature's knowledge base.
Commits use `fix:` prefix for proper PATCH versioning.

## Phase 0: Parse Arguments

1. Parse arguments:
   - Extract feature ID (e.g., feature-001)
   - Extract bug description from quoted string
   - Parse optional flags: --test-pattern, --verify, --max-attempts

2. Validate feature exists:
   - Search in `.claude-harness/features/active.json` features array
   - Search in `.claude-harness/features/archive.json` archived array
   - Extract feature details (name, issueNumber, verification commands)
   - If not found: Error and exit with message

## Phase 1: Generate Fix Entry

3. Generate fix ID:
   - Read existing fixes from `.claude-harness/features/active.json` fixes array
   - Count existing fixes for this feature
   - Format: `fix-{feature-id}-{sequential-number}` (3 digits, zero-padded)
   - Example: `fix-feature-001-001`, `fix-feature-001-002`

4. Generate branch name:
   - Format: `fix/{feature-id}-{slug}`
   - Slug: kebab-case from description, max 30 chars
   - Example: `fix/feature-001-token-expiry`

5. Inherit verification commands:
   - Copy from original feature's verification settings
   - Apply --test-pattern if provided (modifies test command)
   - Apply --verify override if provided
   - Set `inherited: true` in verification

## Phase 2: GitHub Integration (if MCP available)

6. Create GitHub issue:
   - Title: `fix: {bug description}`
   - Body template:
     ```markdown
     ## Bug Report: {bug description}

     ### Related Feature
     - Feature: #{original-issue-number} - {feature-name}
     - Original Branch: `{original-feature-branch}`

     ### Bug Description
     {user-provided description}

     ### Affected Files
     {list of relatedFiles from original feature}

     ### Verification Checklist
     - [ ] Build passes
     - [ ] Tests pass
     - [ ] Lint passes
     - [ ] Typecheck passes
     - [ ] Bug is resolved
     - [ ] Regression tests added (if applicable)

     ---
     _This fix is linked to #{original-issue-number}_
     ```
   - Labels: `["bugfix", "claude-harness", "linked-to:{feature-id}"]`

7. Add comment to original feature issue:
   - Body: `Bug fix created: #{new-issue-number} - {bug description}`

8. Create and checkout branch:
   - Create branch from current HEAD: `fix/{feature-id}-{slug}`
   - Checkout the new branch

## Phase 3: Create Fix Entry

9. Add to `.claude-harness/features/active.json` fixes array:
   ```json
   {
     "id": "fix-{feature-id}-{NNN}",
     "name": "{bug description}",
     "description": "{full description}",
     "linkedTo": {
       "featureId": "{original-feature-id}",
       "featureName": "{original-feature-name}",
       "issueNumber": {original-issue-number}
     },
     "type": "bugfix",
     "status": "pending",
     "phase": "implementation",
     "verification": {
       "build": "{inherited or override}",
       "tests": "{inherited or override}",
       "lint": "{inherited or override}",
       "typecheck": "{inherited or override}",
       "custom": [],
       "inherited": true
     },
     "attempts": 0,
     "maxAttempts": 10,
     "relatedFiles": ["{inherited from original}"],
     "github": {
       "issueNumber": {new-issue-number},
       "prNumber": null,
       "branch": "fix/{feature-id}-{slug}"
     },
     "createdAt": "{ISO timestamp}",
     "updatedAt": "{ISO timestamp}"
   }
   ```

## Phase 4: Query Memory for Context

10. Query procedural memory for original feature:
    - Read `.claude-harness/memory/procedural/failures.json`
      - Filter entries where `feature` matches original feature ID
      - Filter entries where `linkedTo` matches original feature ID
      - Extract: what approaches failed and why
    - Read `.claude-harness/memory/procedural/successes.json`
      - Filter same as above
      - Extract: what approaches worked

11. Compile fix context:
    - Include original feature learnings
    - Include related file patterns
    - Include successful approaches to consider
    - Include failed approaches to avoid

12. Display context summary:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  FIX CONTEXT: {fix-id}                                          │
    │  Linked to: {feature-name} (#{original-issue})                  │
    ├─────────────────────────────────────────────────────────────────┤
    │  Previous learnings for this feature:                           │
    │    ✓ {N} successful approaches                                  │
    │    ✗ {N} failed approaches to avoid                             │
    │  Files commonly affected: {file list}                           │
    └─────────────────────────────────────────────────────────────────┘
    ```

## Phase 5: Initialize Agentic Loop

13. Initialize loop state in `.claude-harness/loops/state.json`:
    ```json
    {
      "version": 3,
      "feature": "{fix-id}",
      "featureName": "{bug description}",
      "type": "fix",
      "linkedTo": {
        "featureId": "{original-feature-id}",
        "featureName": "{original-feature-name}"
      },
      "status": "in_progress",
      "attempt": 1,
      "maxAttempts": 10,
      "startedAt": "{ISO timestamp}",
      "lastAttemptAt": null,
      "verification": {
        "build": "{command}",
        "tests": "{command}",
        "lint": "{command}",
        "typecheck": "{command}",
        "custom": []
      },
      "history": [],
      "lastCheckpoint": null,
      "escalationRequested": false
    }
    ```

## Phase 6: Execute Agentic Loop

14. Run the same agentic loop as /implement:
    - Phase 1: Health check (run build to ensure baseline works)
    - Phase 2: Attempt implementation
      - Read attempt history to avoid repeating failed approaches
      - Plan approach (document in loop state)
      - Execute code changes
      - Record files modified
    - Phase 3: Verification (MANDATORY - NEVER SKIP)
      - Run ALL verification commands
      - ALL must pass for success
    - Phase 4: Handle result
      - If ALL pass: Success flow
      - If ANY fail: Failure flow
    - Phase 5: Retry if failed and attempts remain
    - Phase 6: Escalate if max attempts reached

## Phase 7: On Completion

### If ALL Verification Passes:

15. Celebration and update:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ FIX VERIFIED                                                │
    ├─────────────────────────────────────────────────────────────────┤
    │  Build:     ✅ PASSED                                           │
    │  Tests:     ✅ PASSED                                           │
    │  Lint:      ✅ PASSED                                           │
    │  Typecheck: ✅ PASSED                                           │
    ├─────────────────────────────────────────────────────────────────┤
    │  Fix complete in {n} attempts!                                  │
    │  Linked to: {feature-name}                                      │
    └─────────────────────────────────────────────────────────────────┘
    ```

16. Update fix status:
    - Set status to "passing" in fixes array
    - Set phase to "complete"
    - Update timestamp

17. Record to procedural memory:
    - Add to `.claude-harness/memory/procedural/successes.json`:
      ```json
      {
        "id": "{uuid}",
        "timestamp": "{ISO timestamp}",
        "feature": "{fix-id}",
        "type": "fix",
        "linkedTo": "{original-feature-id}",
        "approach": "{what worked}",
        "files": ["{modified files}"],
        "verificationResults": {
          "build": "passed",
          "tests": "passed",
          "lint": "passed",
          "typecheck": "passed"
        },
        "patterns": ["{reusable patterns discovered}"]
      }
      ```

18. Create git commit:
    - Stage all changes: `git add -A`
    - Commit with message:
      ```
      fix({original-feature-id}): {bug description}

      {Brief description of the fix}

      Verification passed:
      - Build: ✅
      - Tests: ✅
      - Lint: ✅
      - Typecheck: ✅

      Fixes #{fix-issue-number}
      Related to #{original-issue-number}
      ```

19. Update loop state:
    - Set status to "completed"
    - Record finalCommit hash

20. Report success and next steps:
    - Recommend: `/claude-harness:checkpoint` to push and create PR

### If Verification Fails:

21. Record failure:
    - Add to `.claude-harness/memory/procedural/failures.json`:
      ```json
      {
        "id": "{uuid}",
        "timestamp": "{ISO timestamp}",
        "feature": "{fix-id}",
        "type": "fix",
        "linkedTo": "{original-feature-id}",
        "attempt": {n},
        "approach": "{what was tried}",
        "files": ["{affected files}"],
        "errors": ["{error messages}"],
        "rootCause": "{analysis of why it failed}",
        "tags": ["{error-type}", "{category}"],
        "prevention": "{how to avoid in future}"
      }
      ```

22. Increment attempt and retry or escalate:
    - If attempt < maxAttempts: Retry with different approach
    - If attempt >= maxAttempts: Escalate

### On Escalation:

23. Update fix status to "escalated"

24. Generate escalation report:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ⚠️  FIX ESCALATION REQUIRED                                    │
    ├─────────────────────────────────────────────────────────────────┤
    │  Fix: {fix-id}                                                  │
    │  Linked to: {feature-name}                                      │
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
    │  {suggested manual intervention or alternative approach}        │
    └─────────────────────────────────────────────────────────────────┘
    ```

## Session Continuity

Fix loop state persists in `.claude-harness/loops/state.json` across sessions.

SessionStart hook will display:
```
┌─────────────────────────────────────────────────────────────────┐
│  🔧 ACTIVE FIX: {fix-id} (attempt {n}/{max})                    │
│     Linked to: {feature-name}                                   │
│     Last: "{approach summary}" → {result}                       │
│     Resume: /claude-harness:implement {fix-id}                  │
└─────────────────────────────────────────────────────────────────┘
```

Running `/claude-harness:implement {fix-id}` resumes the fix loop.

## Commands

- Start new fix: `/claude-harness:fix feature-001 "Bug description"`
- Resume fix: `/claude-harness:implement fix-feature-001-001`
- With focused tests: `/claude-harness:fix feature-001 "Bug" --test-pattern="auth"`
- With custom verification: `/claude-harness:fix feature-001 "Bug" --verify="npm run test:auth"`
- More attempts: `/claude-harness:fix feature-001 "Bug" --max-attempts=20`
