---
description: Plan feature implementation before coding (Phase 1 of two-phase pattern)
argumentsPrompt: Feature ID to plan (e.g., feature-001)
---

Plan a feature before implementation (Two-Phase Pattern - Phase 1):

Arguments: $ARGUMENTS

## Core Principle
Separate planning from implementation for better outcomes.
This is Phase 1: Planning. Phase 2 is /implement.

## Phase 1: Load Context
1. Parse feature ID from arguments
2. Read feature from .claude-harness/features/active.json (or .claude-harness/feature-list.json for v2.x compat)
3. Read compiled context from .claude-harness/memory/working/context.json
4. Read semantic memory for project architecture

## Phase 2: Analyze Requirements
5. Break down feature into sub-tasks
6. Identify files to create/modify
7. Identify dependencies on other features/modules

## Phase 3: Impact Analysis
8. Read .claude-harness/impact/dependency-graph.json
9. For each file to modify:
   - Identify dependent files (importedBy)
   - Identify related tests
   - Calculate impact score
10. Warn if high-impact changes detected

## Phase 4: Check Past Approaches
11. Read .claude-harness/memory/procedural/failures.json
12. Check if planned approach matches any past failures
13. If match found:
    - Warn about similar past failure
    - Show root cause and prevention tips
    - Suggest alternative approach from successes.json

## Phase 5: Generate Tests (if not done)
14. If feature.tests.generated = false:
    - Automatically run test generation
    - Or prompt to run /generate-tests first

## Phase 6: Create Implementation Plan
15. Write implementation plan to feature:
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

## Phase 7: Update Feature
16. Update feature in active.json:
    - Set phase to "planned"
    - Store implementation plan

## Phase 8: Report
17. Report:
    - Implementation steps
    - Files to modify
    - Impact analysis
    - Risks and mitigations
    - Past failures to avoid
    - **Next**: Run `/claude-harness:implement feature-XXX` to start coding
