---
description: Orchestrate multi-agent teams for complex features
argumentsPrompt: Feature ID or description to orchestrate
---

Orchestrate specialized agents to implement a feature or task:

Arguments: $ARGUMENTS

## Mandelbrot-Enhanced Orchestration Parameters

This orchestrator uses Mandelbrot set algorithms to enhance agent supervision, task decomposition, and convergence detection:

**Configuration Parameters (from CLI or defaults):**
```
# Accept via arguments like: --fractal-depth 5 --escape-threshold 150
# If not provided, use these defaults:
DIVERGENCE_THRESHOLD=100     # Score threshold for agent divergence detection (--escape-threshold)
CONVERGENCE_THRESHOLD=95     # Similarity % for convergence detection (--convergence-threshold)
ESCAPE_RADIUS=4              # Complexity threshold for atomic vs recursive
FRACTAL_MAX_DEPTH=3          # Maximum task decomposition depth (--fractal-depth)
MAX_RESTARTS_PER_AGENT=3     # Restart limit per agent (Mandelbrot max_iteration analog)
RESTART_WINDOW_SECONDS=300   # Time window for restart counting
```

**CLI Options:**
- `--fractal-depth N`: Set maximum decomposition depth (default: 3)
- `--escape-threshold N`: Set divergence score limit (default: 100)
- `--convergence-threshold N`: Set similarity % for convergence (default: 95)

Parse these from $ARGUMENTS before processing feature ID.

**State Tracking (maintain during orchestration):**
- `AGENT_METRICS`: Track per-agent output_hash, divergence_score, change_rate
- `AGENT_RESTART_HISTORY`: Track restart timestamps per agent
- `ITERATION_OUTPUTS`: Track verification loop outputs for cycle detection
- `FRACTAL_DEPTH`: Current decomposition depth (inherited from parent orchestrator)

## Phase 1: Task Analysis

1. Identify the target:
   - If $ARGUMENTS matches a feature ID (e.g., "feature-001"), read from .claude-harness/feature-list.json
   - Otherwise, treat $ARGUMENTS as a task description

2. Read orchestration context:
   - Read `.claude-harness/agent-context.json` for current state (create if missing with initial structure)
   - Read `.claude-harness/agent-memory.json` for learned patterns (create if missing)
   - Read `.claude-harness/feature-list.json` if working on a tracked feature

3. Analyze the task:
   - Identify file types that will be modified (.tsx, .ts, .py, etc.)
   - Detect domains involved (frontend, backend, database, testing, etc.)
   - Check for security-sensitive operations (auth, tokens, encryption)
   - Estimate complexity and required agents

### Phase 1.5: Mandelbrot Complexity Analysis

4. **Measure Task Complexity** (measure_task_complexity - fractal decomposition decision):
   - Count file modifications required (from feature.relatedFiles or discovery)
   - Count systems involved (frontend=1, backend=1, database=1, etc.)
   - Count decision points (keywords: "decide", "choose", "option", "alternative")
   - **Complexity Score** = file_count + (system_count × 2) + decision_count

5. **Decomposition Decision** (should_decompose check):
   - Calculate adjusted threshold: `ESCAPE_RADIUS × (FRACTAL_MAX_DEPTH - FRACTAL_DEPTH + 1) / FRACTAL_MAX_DEPTH`
   - If complexity_score > adjusted_threshold AND FRACTAL_DEPTH < FRACTAL_MAX_DEPTH:
     - **Recommendation**: DECOMPOSE via fractal sub-orchestrator
     - Suggest splitting task into sub-features with clearer boundaries
     - Each sub-task spawns new orchestrator with FRACTAL_DEPTH + 1
   - Else:
     - **Recommendation**: ATOMIC - proceed with current orchestration
   - Log complexity score and decision to trace

## Phase 2: Agent Selection

6. Map task requirements to specialized agents using this matrix:

   **Implementation Agents:**
   | Domain | Primary Agent (subagent_type) | Triggers |
   |--------|-------------------------------|----------|
   | React/Frontend | react-specialist | .tsx, .jsx, component, UI |
   | Backend/API | backend-developer | route.ts, api/, endpoint, REST |
   | Next.js | nextjs-developer | app/, pages/, Next.js specific |
   | Database | database-administrator | prisma, schema, migration, SQL |
   | Python | python-pro | .py files |
   | TypeScript | typescript-pro | complex type work, generics |
   | Go | golang-pro | .go files |
   | Rust | rust-engineer | .rs files |

   **Quality Agents (mandatory for code changes):**
   | Type | Agent (subagent_type) | When to Include |
   |------|----------------------|-----------------|
   | Review | code-reviewer | Always for code changes |
   | Security | security-auditor | Auth, tokens, encryption, API keys |
   | Testing | qa-expert | New features, bug fixes |
   | Performance | performance-engineer | Performance-critical code |

   **Support Agents:**
   | Type | Agent (subagent_type) | When to Include |
   |------|----------------------|-----------------|
   | Research | research-analyst | Unknown patterns, exploration needed |
   | Docs | documentation-engineer | README, API docs updates |
   | DevOps | devops-engineer | CI/CD, Docker, deployment |

7. Build execution plan with dependency ordering:
   - **Group 1 (Analysis)**: research-analyst if exploration needed
   - **Group 2 (Implementation)**: Domain-specific agents (can run in parallel if independent files)
   - **Group 3 (Quality)**: code-reviewer, security-auditor, qa-expert
   - **Group 4 (Documentation)**: documentation-engineer if docs needed

## Phase 3: Agent Spawning

### Phase 3.1: Scope Connectivity Analysis (Bounded Region Detection)

8. **Analyze Scope Connectivity** (analyze_scope_connectivity) before parallel spawning:
   - Extract all agent scopes from execution plan
   - For each agent pair, check for scope overlap:
     - Parse scopes into file sets and directory sets
     - Detect directory overlaps: shared directories = potential conflicts
     - Detect file overlaps: same files = definite conflicts
   - Build connectivity graph:
     - **DISCONNECTED**: No overlaps → full parallelization safe
     - **CONNECTED**: Overlaps detected → coordination required
   - **Parallelization Strategy**:
     - If DISCONNECTED: Spawn all Group 2 agents in parallel
     - If CONNECTED: Identify connected components, serialize within components
     - Log connectivity analysis results (Julia set connectivity analog)

9. Update `.claude-harness/agent-context.json` before spawning:
   ```json
   {
     "currentSession": {
       "id": "session-{timestamp}",
       "startedAt": "{timestamp}",
       "activeFeature": "{feature-id or description}",
       "orchestrationPhase": "implementation",
       "activeAgents": ["{agent-names}"]
     }
   }
   ```

10. For each agent in the execution plan, use the Task tool:

   **Prompt Template for Each Agent:**
   ```
   You are working as part of a multi-agent team on: {task description}

   ## Your Role
   You are the {agent-type} specialist responsible for: {specific responsibility}

   ## Shared Context
   Project: {from agent-context.json projectContext}
   Tech Stack: {techStack}

   ## Architectural Decisions Made
   {from agent-context.json architecturalDecisions}

   ## Active Constraints
   {from agent-context.json activeConstraints}

   ## Previous Agent Results
   {from agent-context.json agentResults - relevant ones}

   ## Learned Patterns (from previous sessions)
   {from agent-memory.json learnedPatterns}

   ## Your Task
   {specific task for this agent}

   ## Files to Work On
   {relevant files from feature.relatedFiles or discovered}

   ## Expected Output
   Complete your task and provide a structured result:
   - Files created/modified
   - Key decisions made
   - Any issues encountered
   - Context for the next agent
   ```

11. Execute agents in dependency order:
   - For Group 1: Run sequentially, wait for results
   - For Group 2: Run in PARALLEL using multiple Task tool calls in single message if scope analysis allows
   - For Group 3: Run after implementation complete
   - For Group 4: Run last

### Phase 3.2: Escape-Time Agent Supervision

12. **Track Agent Trajectory** during execution (check_agent_trajectory - divergence detection):
    - For each spawned agent, monitor progress periodically
    - After agent completes, analyze output:
      - Compute output_hash (MD5 or similar)
      - If previous output exists, calculate change_rate (% difference)
      - Update divergence_score:
        - If change_rate < 5%: score += 25 (accelerating toward escape)
        - If change_rate < 20%: score += 5 (slow progress)
        - Else: score -= 15 (good progress, pull back)
    - **Trajectory Classification**:
      - If divergence_score >= DIVERGENCE_THRESHOLD: **ESCAPING** → abort early, trigger restart logic
      - If change_rate < 2% AND divergence_score < 20: **CONVERGED** → accept result
      - Else: **BOUNDED** → continue normally
    - Store AGENT_METRICS for each agent (output_hash, divergence_score, change_rate)
    - Log trajectory classification to trace

## Phase 4: Coordination & Handoffs

13. After each agent completes:
   - Parse the agent's result
   - Update `.claude-harness/agent-context.json`:
     ```json
     {
       "agentResults": [{
         "agent": "{agent-name}",
         "task": "{task description}",
         "status": "completed|failed|blocked",
         "filesModified": ["{paths}"],
         "filesCreated": ["{paths}"],
         "completedAt": "{timestamp}",
         "notes": "{agent's summary}",
         "decisionsRecorded": [{architectural decisions to add}]
       }]
     }
     ```
   - If agent discovered patterns, add to `sharedState.discoveredPatterns`
   - If agent made architectural decisions, add to `architecturalDecisions`

14. **Handle Failures with Supervision Tree** (restart limits):
    - Count restarts for this agent within RESTART_WINDOW_SECONDS
    - If restart_count >= MAX_RESTARTS_PER_AGENT:
      - **ESCALATE**: Max restarts exceeded (Mandelbrot max_iteration analog)
      - Emit ESCALATE signal, log to trace
      - Report failure and continue with other agents
    - Else, determine restart strategy based on failure type:
      - **TIMEOUT**: May converge on retry → RESTART
      - **DIVERGENCE** (from trajectory tracking): Retry with perturbation → RESTART_WITH_PERTURBATION
      - **ERROR**: Transient error → RESTART
      - **FATAL**: Cannot recover → ESCALATE
    - Record restart timestamp in AGENT_RESTART_HISTORY
    - Log restart decision to trace

15. Handle failures (legacy behavior):
    - If status is "failed":
      - Check if transient (timeout, etc.) - retry up to 3 times
      - If persistent, try secondary agent from same category
      - If still failing, report and continue with other agents
    - If status is "blocked":
      - Record blocker in pendingHandoffs
      - Continue with non-blocked work
      - Report blockers at end

16. Manage handoffs between sequential agents:
    - Add to `pendingHandoffs`:
      ```json
      {
        "from": "{previous-agent}",
        "to": "{next-agent}",
        "files": ["{files to review/work on}"],
        "context": "{what was done, what needs to happen next}"
      }
      ```
    - Include handoff context in next agent's prompt

## Phase 5: Result Aggregation

17. After all agents complete, aggregate results:
    - Collect all file changes across agents
    - Compile all review findings
    - List all architectural decisions made
    - Identify any remaining issues

18. Update shared memory files:
    - `.claude-harness/agent-context.json`:
      - Set orchestrationPhase to "completed"
      - Clear activeAgents
      - Keep agentResults for reference
    - `.claude-harness/agent-memory.json`:
      - Add successful approaches to successfulApproaches
      - Record any failed approaches to failedApproaches
      - Update agentPerformance metrics
      - Add discovered patterns to learnedPatterns

19. Update feature tracking:
    - If working on a tracked feature, update .claude-harness/feature-list.json:
      - Add new files to relatedFiles
      - Update verification status if applicable

## Phase 6: Verification Loop (MANDATORY)

### Phase 6.1: Convergence Detection (Fixed-Point Analysis)

20. **Detect Iteration Convergence** (detect_iteration_cycle - feedback loop termination):
    - After each verification iteration, compute output similarity:
      - Hash the aggregated output (all agent results + verification status)
      - Compare with previous iterations in ITERATION_OUTPUTS (sliding window of 3-5)
      - Calculate similarity percentage (shared lines / total lines × 100)
    - **Cycle Detection** (Floyd's tortoise-and-hare adapted):
      - If similarity >= CONVERGENCE_THRESHOLD with any recent iteration:
        - **CONVERGED**: Fixed point reached → offer to terminate with success
      - If oscillating pattern detected (A → B → A):
        - **OSCILLATING**: Suggest perturbation or termination
      - Else:
        - **CONTINUE**: Proceed with next iteration
    - Append current output to ITERATION_OUTPUTS for next comparison
    - Log convergence analysis to trace

21. Run verification commands (from feature's `verificationCommands`):
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

22. Handle verification results:
    - **If ALL pass**: Continue to Phase 7 (Reporting)
    - **If ANY fail**:
      - Parse error messages to identify failing component
      - Determine which agent should fix (e.g., type errors → typescript-pro)
      - Re-spawn relevant agent with error context
      - Repeat verification
      - Track attempts in loop state (max 10 by default)

23. If verification keeps failing after multiple agent re-runs:
    - Escalate: Report which verification step fails persistently
    - Provide error summary and agent history
    - Recommend: Manual intervention or `/claude-harness:implement` for focused loop

## Mandelbrot Signal Types

This orchestrator emits enhanced signals for Mandelbrot-based supervision:

**Standard Signals:**
- `READY:<agent>` - Agent completed successfully
- `FAILED:<agent>` - Agent failed
- `BLOCKED:<agent>` - Agent blocked on dependency
- `DATA:<agent>:<path>` - Agent produced artifact

**Mandelbrot Enhancement Signals:**
- `ESCAPING:<agent>` - Agent trajectory diverging (divergence_score >= threshold)
- `CONVERGED:<agent>` - Agent reached fixed point (change_rate < 2%)
- `OSCILLATING:<agent>` - Verification loop cycling between states
- `ESCALATE:<agent>` - Failure escalated (max restarts exceeded)
- `DECOMPOSED:<feature>` - Task split via fractal decomposition

## Phase 7: Reporting

24. **Persist Mandelbrot State** (checkpoint for recovery):
    - Save to checkpoint file or trace:
      - AGENT_METRICS (output_hash, divergence_score, change_rate per agent)
      - AGENT_RESTART_HISTORY (restart timestamps)
      - ITERATION_OUTPUTS (verification loop outputs)
      - FRACTAL_DEPTH (current decomposition level)
    - Include trajectory metrics in trace.jsonl:
      - `{"type": "trajectory", "agent": "...", "divergence_score": N, "change_rate": N, "classification": "BOUNDED|ESCAPING|CONVERGED"}`
      - `{"type": "complexity", "score": N, "decision": "ATOMIC|DECOMPOSE"}`
      - `{"type": "connectivity", "result": "DISCONNECTED|CONNECTED", "connections": [...]}`
      - `{"type": "convergence", "iteration": N, "similarity": N, "status": "CONTINUE|CONVERGED|OSCILLATING"}`

25. Report orchestration summary:
    ```
    ## Orchestration Complete

    **Feature/Task:** {description}
    **Duration:** {total time}

    ### Agents Invoked
    | Agent | Task | Status | Duration |
    |-------|------|--------|----------|
    | {agent} | {task} | {status} | {time} |

    ### Verification Results
    | Check | Status |
    |-------|--------|
    | Build | ✅ PASSED |
    | Tests | ✅ PASSED |
    | Lint | ✅ PASSED |
    | Typecheck | ✅ PASSED |

    ### Files Modified
    - {filepath} ({agent that modified})

    ### Files Created
    - {filepath} ({agent that created})

    ### Architectural Decisions Made
    - {decision} (by {agent})

    ### Issues Found
    - {issue} (by {agent}) - {resolution status}

    ### Patterns Learned
    - {pattern description}

    ### Next Steps
    - {recommended actions}

    ### Commands to Continue
    - Run `/claude-harness:checkpoint` to commit and create PR
    - Run `/claude-harness:orchestrate {next-feature}` for next task
    ```

26. Update feature status if verification passed:
    - Set `passes: true` in `.claude-harness/feature-list.json`
    - Create git checkpoint with verification results

## Error Recovery

If orchestration is interrupted:
- `.claude-harness/agent-context.json` preserves state
- `.claude-harness/loop-state.json` tracks verification attempts
- Run `/claude-harness:orchestrate` again to resume from pendingHandoffs
- Run `/claude-harness:implement {feature-id}` for focused single-agent loop
- Use `/claude-harness:start` to see orchestration state and recommendations
