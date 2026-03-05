# Team ATDD - Agent Teams Implementation

Covers Phase 0.2 (Team Preflight), Phase 3.7 (Team Roster), and Phase 4 Team mode (ATDD with Agent Teams).

## Phase 0.2: Team Preflight

1. **Verify Agent Teams environment**:
   - Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` env var is set to `1`
   - If not set: display error with instructions to enable in config.json, run `/claude-harness:setup`, then STOP
   - Read `.claude-harness/config.json` `agentTeams` section:
     - Verify `agentTeams.enabled` is `true`. If not: display "Enable agentTeams in config.json" and STOP
     - Cache team config: `defaultTeamSize`, `roles`, `requirePlanApproval`, `teammateModel`

---

## Phase 3.7: Team Roster

1. **Prepare team structure** from config.json `agentTeams`:
   - Team name: `"{projectName}-{feature-id}"`
   - Roles from config (default: `["implementer", "reviewer", "tester"]`)
   - Model override from config `teammateModel` (null = inherit lead's model)

2. **Prepare ATDD spawn prompts** for each role:

   **Tester** (spawns first -- writes acceptance tests):
   ```
   You are the Tester for {feature-id}: {featureName}.

   YOUR PRIMARY TASK: Write executable acceptance tests from these Gherkin criteria BEFORE any implementation exists.
   This is the RED phase of ATDD -- tests MUST fail initially (there's no implementation yet).

   Acceptance Criteria:
   {for each criterion in acceptanceCriteria}
   Scenario: {scenario}
     Given {given}
     When {when}
     Then {then}
   {end}

   Test framework: {from config.json verification.tests}
   Acceptance test command: {from config.json verification.acceptance}
   Project patterns: {from procedural memory test patterns}

   Write tests that are:
   - Executable with the project's test framework
   - Focused on behavior (not implementation details)
   - Independent of each other
   - Clear about expected outcomes

   After writing tests, run them to confirm they execute (failures expected in RED phase).
   ```

   **Implementer** (spawns in parallel -- plans approach):
   ```
   You are the Implementer for {feature-id}: {featureName}.

   YOUR PRIMARY TASK: Make all acceptance tests pass (GREEN phase of ATDD).

   Wait for the Tester to complete writing acceptance tests (Task 1).
   Then implement the feature to make every test pass.

   Plan: {from Phase 3}
   Acceptance Criteria: {acceptanceCriteria summary}
   Related files: {relatedFiles}
   Verification commands: {from config.json}

   Past failures to AVOID: {from procedural memory, last 3}
   Learned rules: {from learned rules}

   Follow test-driven approach:
   1. Read the acceptance tests the Tester wrote
   2. Implement minimal code to make each test pass
   3. Refactor while keeping tests green
   4. Run ALL verification commands before marking complete
   ```

   **Reviewer** (spawns last -- reviews after implementation):
   ```
   You are the Reviewer for {feature-id}: {featureName}.

   YOUR PRIMARY TASK: Review the implementation for quality, security, and adherence to patterns.

   Wait for the Implementer to complete (Task 3). Then review:

   Code standards: {from semantic memory architecture.patterns}
   Project patterns: {from procedural memory patterns}
   Acceptance criteria: {acceptanceCriteria -- verify all are covered}

   Review checklist:
   - [ ] All acceptance criteria covered by tests
   - [ ] No security vulnerabilities (OWASP top 10)
   - [ ] Follows existing code patterns and naming conventions
   - [ ] Error handling for edge cases
   - [ ] No unnecessary complexity or over-engineering
   - [ ] Clean, readable code

   Report findings with severity: CRITICAL (must fix), WARNING (should fix), INFO (suggestion).
   ```

3. Store roster in session context for checkpoint persistence.

---

## Phase 4 (Team -- if --team): ATDD with Agent Teams

### 18T: Create the Agent Team

- Tell Claude to create an agent team named `"{teamName}"` with delegate mode
- Spawn 3 teammates using the prompts from Phase 3.7:
  - Tester (with `requirePlanApproval: true` from config)
  - Implementer (with `requirePlanApproval: true` from config)
  - Reviewer (no plan approval needed)
- If `agentTeams.teammateModel` is set, specify model for each teammate
- Update loop-state `team.teammates[].name` with spawned teammate names
- Update `.claude-harness/agents/context.json` with `teamState`

### 19T: Create ATDD Shared Task Chain (6 tasks with dependencies)

```
Task 1: "Write acceptance tests for {feature}" (tester)       -- no deps
Task 2: "Plan implementation for {feature}" (implementer)     -- no deps
Task 3: "Implement {feature}" (implementer)                    -- blocked by Task 1, Task 2
Task 4: "Code review {feature}" (reviewer)                     -- blocked by Task 3
Task 5: "Address review feedback for {feature}" (implementer)  -- blocked by Task 4
Task 6: "Final verification for {feature}" (tester)            -- blocked by Task 5
```

Tasks 1 and 2 run in parallel. The implementer cannot start coding until acceptance tests exist.

### 20T: Monitor Team Progress

- The lead (this session) operates in delegate mode -- coordination only
- `TeammateIdle` hook enforces: no uncommitted changes, verification passing
- `TaskCompleted` hook enforces ATDD gates:
  - Task 1 (RED): acceptance tests exist and can be executed
  - Task 3 (GREEN): acceptance tests pass
  - Task 6 (VERIFY): ALL verification commands pass
- When teammates send messages, review and redirect if needed
- Periodically check task list progress

### 21T: Handle Team Completion or Failure

- **Success**: All 6 tasks complete -> shut down teammates -> clean up team -> proceed to Phase 4.1
- **Teammate failure**: If a teammate stops with errors:
  - Spawn replacement teammate with same role and context
  - Increment attempt count
- **Team failure** (max attempts exhausted):
  - Shut down all teammates
  - Clean up team resources
  - Record failure to procedural memory
  - Fall back to standard Phase 4 (direct implementation) as safety net

### 22T: Mandatory Team Shutdown Gate (MUST complete before Phase 5)

This gate ensures ALL teammates are fully stopped before proceeding. Skipping this creates zombie agents that drain CPU/RAM.

**Step A -- Request shutdown for each teammate** (in parallel):
- For each teammate in the team roster:
  - Send shutdown request: "Please shut down now. Your work is complete."
  - Record shutdown request time

**Step B -- Verify shutdown with polling loop** (max 60 seconds):
```
attempts = 0
max_poll_attempts = 12  (every 5 seconds for 60s total)
while attempts < max_poll_attempts:
  Check each teammate status (via team list / Shift+Up/Down)
  If ALL teammates stopped: BREAK -> proceed to Step C
  If any still running: wait 5 seconds, increment attempts
```

**Step C -- Handle stragglers** (if any teammate still running after 60s):
- For each still-running teammate:
  - Send forceful message: "You must shut down immediately."
  - Wait 10 seconds
  - If STILL running: proceed anyway -- the team cleanup command will report
- **Log warning** to stderr and loop-state history

**Step D -- Run team cleanup**:
- Execute team cleanup command (removes shared team resources)
- If cleanup fails because teammates are still active:
  - Log the failure
  - **In autonomous mode**: CRITICAL -- do NOT proceed. Mark feature as "needs_review" and add to `skippedFeatures` with reason "team-cleanup-failed"
  - **In standard mode**: warn user, suggest manual tmux session cleanup

**Step E -- Verify and persist**:
- Confirm no orphaned tmux sessions: `tmux ls 2>/dev/null | grep "{teamName}"` -- if found, kill: `tmux kill-session -t "{teamName}"`
- Persist team results to `agents/context.json` `agentResults`
- Set `agents/context.json` `teamState` to null
- Update loop-state `team.teammates[].status` to "completed"
- Update loop-state `team.enabled` to false

**IMPORTANT**: The flow MUST NOT proceed to Phase 5 (Checkpoint) until Step E completes successfully. This is a hard gate, not a soft recommendation.
