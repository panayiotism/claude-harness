# TDD Enforcement Mode - Implementation Plan

**Feature ID:** feature-012
**Issue:** #23
**Branch:** feature/feature-012
**Status:** Planning (--plan-only)

## Executive Summary

This plan outlines how to add opt-in TDD (Test-Driven Development) enforcement to the claude-harness workflow. The key principle is **backward compatibility** - existing users should experience no change unless they explicitly opt in.

## Research Findings

### Current Workflow Analysis

The `/claude-harness:do` command has 4 phases:
1. **Phase 1: Feature Creation** - Creates GitHub issue, branch, feature entry
2. **Phase 2: Planning** - Analyzes requirements, creates implementation plan
3. **Phase 3: Implementation** - Executes code changes with verification loop
4. **Phase 4: Checkpoint** - Commits, pushes, creates PR

**Key Integration Points:**
- Phase 2 (Planning): TDD mode should generate test plan FIRST
- Phase 3 (Implementation): TDD mode should enforce "write tests" before "write code"
- Verification loop (step 19): Already runs tests, but after implementation

### TDD Best Practices (2025)

Based on research from [AI-Powered TDD Guide 2025](https://www.nopaccelerate.com/test-driven-development-guide-2025/) and [Monday.com TDD Guide](https://monday.com/blog/rnd/what-is-tdd/):

1. **Red-Green-Refactor Cycle:**
   - RED: Write failing test first
   - GREEN: Write minimal code to pass
   - REFACTOR: Improve code while keeping tests green

2. **CI/CD Integration:**
   - [Travis CI Integration Guide](https://www.travis-ci.com/blog/how-to-integrate-test-driven-development-with-ci-cd/)
   - Fail builds if tests don't exist (quality gate)
   - Code coverage thresholds

3. **Mutation Testing:**
   - [Mutation Testing Guide 2025](https://mastersoftwaretesting.com/testing-fundamentals/types-of-testing/mutation-testing)
   - Tests your tests by introducing faults
   - Higher mutation score = better test quality

## Proposed Solution

### Option A: Minimal TDD Flag (Recommended)

Add `--tdd` flag that:
1. Modifies planning phase to generate test specs first
2. Adds "test existence check" before implementation
3. Enforces test-first workflow within implementation loop

**Pros:**
- Simple, low complexity
- Easy to understand
- No breaking changes

**Cons:**
- Requires discipline (tests could be stubs)
- No test quality enforcement

### Option B: Full TDD Pipeline with Quality Gates

Add `--tdd` flag plus:
1. Test existence verification
2. Code coverage threshold (configurable)
3. Optional mutation testing integration

**Pros:**
- Higher quality guarantee
- Measurable metrics

**Cons:**
- Higher complexity
- Requires external tools (coverage, mutation)
- Slower feedback loop

### Option C: Progressive TDD (Hybrid)

Three levels of TDD enforcement:
- `--tdd`: Basic test-first workflow
- `--tdd=strict`: Test-first + coverage threshold
- `--tdd=mutation`: Full mutation testing

**Pros:**
- Flexible for different project needs
- Progressive adoption

**Cons:**
- More complex implementation
- More documentation needed

## Recommended Approach: Option A (Minimal)

Start with Option A for v1, with architecture allowing future Option C expansion.

## Implementation Steps

### Step 1: Add TDD Mode Configuration

**Files:** `.claude-harness/settings.json` (new), `commands/do.md`

Add configuration schema:
```json
{
  "tdd": {
    "enabled": false,
    "mode": "basic",
    "testPatterns": {
      "javascript": ["**/*.test.js", "**/*.spec.js", "**/__tests__/**"],
      "typescript": ["**/*.test.ts", "**/*.spec.ts", "**/__tests__/**"],
      "python": ["**/test_*.py", "**/*_test.py", "**/tests/**"],
      "default": ["**/*test*", "**/*spec*"]
    },
    "coverageThreshold": null,
    "failOnMissingTests": true
  }
}
```

### Step 2: Modify Argument Parsing in do.md

**Files:** `commands/do.md`

Add to option parsing (Section 2):
```markdown
- `--tdd`: Enable TDD mode for this feature
  - Enforces test-first workflow
  - Blocks implementation until tests exist
```

### Step 3: Add TDD Phase to Planning (Phase 2)

**Files:** `commands/do.md`

Insert new step 7.5 after requirements analysis:

```markdown
7.5. **TDD Test Planning (if --tdd or tdd.enabled)**:
   - Analyze feature requirements
   - Generate test specifications:
     - Unit tests for new functions/modules
     - Integration tests for feature behavior
     - Edge cases and error scenarios
   - Identify test files to create
   - Add to plan.steps as FIRST steps:
     ```json
     {
       "step": 1,
       "type": "test",
       "description": "Write failing test for X",
       "files": ["src/__tests__/x.test.ts"]
     }
     ```
   - Display test plan:
     ```
     ┌─────────────────────────────────────────────────────────────────┐
     │  🧪 TDD MODE: Test Plan                                         │
     ├─────────────────────────────────────────────────────────────────┤
     │  Tests to write first:                                          │
     │  1. src/__tests__/x.test.ts - Core functionality               │
     │  2. src/__tests__/x.integration.ts - Integration tests         │
     └─────────────────────────────────────────────────────────────────┘
     ```
```

### Step 4: Add Test Existence Check to Implementation (Phase 3)

**Files:** `commands/do.md`

Insert new step 17.5 before implementation loop:

```markdown
17.5. **Test Existence Verification (if TDD mode)**:
   - Read feature's planned test files from plan.steps
   - Check if test files exist on disk:
     ```bash
     for file in "${TEST_FILES[@]}"; do
       if [ ! -f "$file" ]; then
         MISSING_TESTS+=("$file")
       fi
     done
     ```
   - If missing tests and first attempt:
     - Display prompt to write tests first:
       ```
       ┌─────────────────────────────────────────────────────────────────┐
       │  🧪 TDD MODE: Tests Required First                             │
       ├─────────────────────────────────────────────────────────────────┤
       │  Missing test files:                                            │
       │  • src/__tests__/x.test.ts                                      │
       │                                                                  │
       │  Write these tests before implementation.                       │
       │  Tests should be FAILING (red) initially.                       │
       └─────────────────────────────────────────────────────────────────┘
       ```
     - Set implementation focus to "tests" (not "code")
   - If tests exist but empty/no assertions:
     - Warn but allow proceeding
```

### Step 5: Modify Implementation Loop for TDD

**Files:** `commands/do.md`

Modify step 19 to support TDD workflow:

```markdown
19. Execute implementation loop (TDD-aware):
   - **If TDD mode and phase="tests":**
     - Write failing tests (RED phase)
     - Run tests to confirm they fail
     - If tests pass unexpectedly: warn (tests may be trivial)
     - Update loop state: phase="implementation"

   - **If TDD mode and phase="implementation":**
     - Write minimal code to pass tests (GREEN phase)
     - Run ALL verification commands
     - If tests pass: prompt for refactoring opportunity
     - Update loop state: phase="refactor" (optional)

   - **If not TDD mode (default):**
     - Current behavior unchanged
```

### Step 6: Update Loop State Schema

**Files:** `.claude-harness/loops/state.json`

Add TDD tracking:
```json
{
  "version": 4,
  "tdd": {
    "enabled": false,
    "phase": null,
    "testsWritten": [],
    "coverageBaseline": null
  }
}
```

### Step 7: Update Documentation

**Files:** `README.md`, `commands/do.md`

Add TDD section to README:
```markdown
## TDD Mode

Enable test-driven development workflow:

```bash
# Single feature
/claude-harness:do --tdd "Add user authentication"

# Project default
# In .claude-harness/settings.json:
{ "tdd": { "enabled": true } }
```
```

## Impact Analysis

| File | Change Type | Impact |
|------|-------------|--------|
| commands/do.md | Modify | Medium - Add TDD phases, preserve existing logic |
| README.md | Modify | Low - Add documentation section |
| .claude-harness/loops/state.json | Modify | Low - Add tdd field to schema |
| .claude-harness/settings.json | New | Low - Configuration file |

**Impact Score: Medium**
- Core workflow modified but existing paths preserved
- No breaking changes to existing users

## Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| TDD mode adds friction | Medium | Clear opt-in, good UX messaging |
| Test detection false positives | Low | Configurable test patterns |
| Performance impact | Low | Test checks are fast |
| Breaking existing workflow | Low | Thorough testing, feature flag |

## Verification Plan

1. **Unit Testing:**
   - Test TDD flag parsing
   - Test test-file detection logic
   - Test phase transitions

2. **Integration Testing:**
   - Full workflow with --tdd flag
   - Full workflow without --tdd (unchanged)
   - Mixed scenarios (TDD enabled mid-feature)

3. **Manual Testing:**
   - Run `/claude-harness:do --tdd "test feature"` on sample project
   - Verify prompts and phase transitions
   - Verify existing workflow unaffected

## Future Enhancements (v2+)

1. **Coverage Integration:**
   - Parse coverage reports
   - Enforce coverage thresholds

2. **Mutation Testing:**
   - Integrate with [Stryker](https://stryker-mutator.io/) or [PIT](https://pitest.org/)
   - Quality gates based on mutation score

3. **AI-Assisted Test Generation:**
   - Use Claude to generate test scaffolds
   - Suggest edge cases based on code analysis

## Decision Log

| Decision | Rationale | Alternatives |
|----------|-----------|--------------|
| Opt-in TDD mode | Backward compatibility critical | Could have made it default |
| Basic test-first v1 | Lower complexity, faster delivery | Could have added coverage/mutation |
| File-based test detection | Works across languages | Could have required test manifest |

---

**Plan Status:** Ready for review
**Next Step:** Run `/claude-harness:do feature-012` to implement
