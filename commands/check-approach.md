---
description: Check if a proposed approach matches past failures
argumentsPrompt: Describe the approach you plan to take
---

Check if your planned approach matches any past failures:

Arguments: $ARGUMENTS

## Core Principle
Learn from mistakes. Do not repeat approaches that failed before.

## Phase 1: Parse Approach
1. Extract approach description from arguments
2. Identify key elements:
   - Files involved
   - Technique/pattern being used
   - Problem being solved

## Phase 2: Query Failure Memory
3. Read .claude-harness/memory/procedural/failures.json
4. For each failure entry:
   - Calculate similarity score based on:
     - File overlap (same files affected)
     - Technique similarity (same approach)
     - Problem similarity (same type of issue)
   - If similarity > 0.7, flag as potential match

## Phase 3: Report Matches
5. If matches found:
   ```
   SIMILAR APPROACH FAILED BEFORE

   Failure: {failure description}
   When: {timestamp}
   Files: {affected files}
   Error: {error messages}
   Root Cause: {why it failed}

   Prevention Tip: {how to avoid}
   ```

## Phase 4: Suggest Alternatives
6. Read .claude-harness/memory/procedural/successes.json
7. Find successful approaches for similar problems
8. Report alternatives:
   ```
   SUCCESSFUL ALTERNATIVE

   Approach: {description}
   When: {timestamp}
   Files: {files}
   Why it worked: {rationale}
   ```

## Phase 5: Recommendation
9. If high-similarity failure found:
   - Recommend NOT proceeding with current approach
   - Suggest specific alternative

10. If no matches:
    - "No similar failures found. Proceed with caution."
    - Still recommend running tests frequently
