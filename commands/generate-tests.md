---
description: Generate test cases for a feature before implementation
argumentsPrompt: Feature ID (e.g., feature-001)
---

Generate test cases BEFORE implementation:

Arguments: $ARGUMENTS

## Core Principle
Test-driven development: Generate tests first, then implement to pass them.
This provides clear acceptance criteria and prevents "marking complete without testing".

## Phase 1: Load Feature
1. Parse feature ID from arguments
2. Read feature from .claude-harness/features/active.json (or .claude-harness/feature-list.json for v2.x compat)
3. Verify feature exists and is in pending/planning phase

## Phase 2: Analyze Project
4. Read .claude-harness/memory/semantic/architecture.json for:
   - Test framework (jest, vitest, pytest, etc.)
   - Test directory structure
   - Existing test patterns

5. Read .claude-harness/memory/procedural/successes.json for:
   - Test patterns that worked before
   - File naming conventions

## Phase 3: Generate Test Cases
6. Based on feature description, generate test cases:
   - Unit tests for core functionality
   - Integration tests for API/database
   - Edge cases and error handling

7. Create test file at `.claude-harness/features/tests/{feature-id}.json`:
   ```json
   {
     "featureId": "feature-XXX",
     "generatedAt": "<ISO timestamp>",
     "framework": "jest|pytest|vitest",
     "cases": [
       {
         "id": "test-001",
         "type": "unit|integration|e2e",
         "description": "Should do X when Y",
         "file": "tests/path/to/test.ts",
         "status": "pending",
         "code": "test code here",
         "dependencies": []
       }
     ],
     "coverage": {
       "target": 80,
       "current": 0
     }
   }
   ```

## Phase 4: Create Test Files
8. Write actual test files to the project:
   - Create test file(s) based on project conventions
   - Tests should FAIL initially (no implementation yet)

9. Run tests to confirm they fail (expected)

## Phase 5: Update Feature
10. Update feature in active.json:
    - Set status to "needs_implementation"
    - Set phase to "test_generation"
    - Set tests.generated = true
    - Set tests.file = path to test spec
    - Set tests.total = number of test cases

## Phase 6: Report
11. Report:
    - Number of test cases generated
    - Test file locations
    - Expected failures (normal - no implementation yet)
    - **Next**: Run `/claude-harness:implement feature-XXX` to implement
