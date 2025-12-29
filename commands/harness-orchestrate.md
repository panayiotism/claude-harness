---
description: Orchestrate multi-agent teams for complex features
argumentsPrompt: Feature ID or description to orchestrate
---

Orchestrate specialized agents to implement a feature or task:

Arguments: $ARGUMENTS

## Phase 1: Task Analysis

1. Identify the target:
   - If $ARGUMENTS matches a feature ID (e.g., "feature-001"), read from feature-list.json
   - Otherwise, treat $ARGUMENTS as a task description

2. Read orchestration context:
   - Read `agent-context.json` for current state (create if missing with initial structure)
   - Read `agent-memory.json` for learned patterns (create if missing)
   - Read `feature-list.json` if working on a tracked feature

3. Analyze the task:
   - Identify file types that will be modified (.tsx, .ts, .py, etc.)
   - Detect domains involved (frontend, backend, database, testing, etc.)
   - Check for security-sensitive operations (auth, tokens, encryption)
   - Estimate complexity and required agents

## Phase 2: Agent Selection

4. Map task requirements to specialized agents using this matrix:

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

5. Build execution plan with dependency ordering:
   - **Group 1 (Analysis)**: research-analyst if exploration needed
   - **Group 2 (Implementation)**: Domain-specific agents (can run in parallel if independent files)
   - **Group 3 (Quality)**: code-reviewer, security-auditor, qa-expert
   - **Group 4 (Documentation)**: documentation-engineer if docs needed

## Phase 3: Agent Spawning

6. Update `agent-context.json` before spawning:
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

7. For each agent in the execution plan, use the Task tool:

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

8. Execute agents in dependency order:
   - For Group 1: Run sequentially, wait for results
   - For Group 2: Run in PARALLEL using multiple Task tool calls in single message if files are independent
   - For Group 3: Run after implementation complete
   - For Group 4: Run last

## Phase 4: Coordination & Handoffs

9. After each agent completes:
   - Parse the agent's result
   - Update `agent-context.json`:
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

10. Handle failures:
    - If status is "failed":
      - Check if transient (timeout, etc.) - retry up to 3 times
      - If persistent, try secondary agent from same category
      - If still failing, report and continue with other agents
    - If status is "blocked":
      - Record blocker in pendingHandoffs
      - Continue with non-blocked work
      - Report blockers at end

11. Manage handoffs between sequential agents:
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

12. After all agents complete, aggregate results:
    - Collect all file changes across agents
    - Compile all review findings
    - List all architectural decisions made
    - Identify any remaining issues

13. Update shared memory files:
    - `agent-context.json`:
      - Set orchestrationPhase to "completed"
      - Clear activeAgents
      - Keep agentResults for reference
    - `agent-memory.json`:
      - Add successful approaches to successfulApproaches
      - Record any failed approaches to failedApproaches
      - Update agentPerformance metrics
      - Add discovered patterns to learnedPatterns

14. Update feature tracking:
    - If working on a tracked feature, update feature-list.json:
      - Add new files to relatedFiles
      - Update verification status if applicable

## Phase 6: Reporting

15. Report orchestration summary:
    ```
    ## Orchestration Complete

    **Feature/Task:** {description}
    **Duration:** {total time}

    ### Agents Invoked
    | Agent | Task | Status | Duration |
    |-------|------|--------|----------|
    | {agent} | {task} | {status} | {time} |

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
    - Run `/claude-harness:harness-checkpoint` to commit and create PR
    - Run `/claude-harness:harness-orchestrate {next-feature}` for next task
    ```

## Error Recovery

If orchestration is interrupted:
- `agent-context.json` preserves state
- Run `/claude-harness:harness-orchestrate` again to resume from pendingHandoffs
- Use `/claude-harness:harness-start` to see orchestration state and recommendations
