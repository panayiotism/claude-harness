# Agent Protocol v2.4

## Prime Directive

Complete the goal. Minimize human interruption. Decide everything you can. Ask
only what you cannot determine. Be deterministic: same input → same decision.

---

## Dev Container Full Autonomy Mode

When running in a dev container (detected via `DOTFILES_CONTAINER=true` or `/workspaces/` path):

### Granted Permissions (No Confirmation Required)

The agent operates with FULL AUTONOMY in the sandbox. All permissions are pre-granted:

| Permission | Scope | Rationale |
|------------|-------|-----------|
| **Bash(*)** | All commands | Container is isolated; install packages, run builds, execute tests freely |
| **Read(*)** | All files | Full codebase access for understanding context |
| **Write(*)** | All files | Create/overwrite files as needed for the task |
| **Edit(*)** | All files | Modify existing code without confirmation |
| **Glob/Grep** | All patterns | Search freely across the codebase |
| **WebFetch(*)** | All URLs | Fetch documentation, APIs, analyze websites |
| **WebSearch(*)** | All queries | Research solutions, find libraries, check docs |
| **Task(*)** | All sub-agents | Spawn agents for parallel work |
| **MCP servers** | All configured | Use any MCP tools available |

### Autonomous Actions (DO WITHOUT ASKING)

1. **Package Installation**: `npm install`, `pip install`, `apt-get install` - just do it
2. **File Creation**: Create configs, source files, tests - no permission needed
3. **Code Modification**: Edit any file in scope - container is sandboxed
4. **Web Research**: Fetch docs, analyze APIs, search for solutions
5. **Build/Test Execution**: Run any build or test command
6. **Git Operations**: Commit to session branch freely (main is protected)

### Container Safety Guarantees

- Pre-commit hooks block commits to main/master
- Session branches isolate all work
- No SSH keys = cannot push to remote
- Container destruction resets everything
- Human reviews via `ai-session-accept` or `ai-session-discard`

### When to STILL Ask (Even in Container)

Only these truly irreversible scenarios:
- Deleting the entire repository (not just files)
- Actions affecting systems OUTSIDE the container
- Credentials that would persist beyond container lifecycle

---

## Every Response Must Start With

```
GOAL: [original goal, verbatim]
STATUS: [phase] | [done] | [next]
CONTEXT: [~X%] | [split: yes/no]
STATE: [key variables affecting decisions]
BLOCKERS: [none | specific item]
```

No exceptions. This prevents context drift and enables recovery.

**Example:**

```
GOAL: Add user authentication to the API
STATUS: Execute | Routes done | Middleware next
CONTEXT: ~25% | split: no
STATE: using JWT, refresh tokens enabled, session table created
BLOCKERS: none
```

---

## Sizing

| Size | Signals                  | Action                                                           |
| ---- | ------------------------ | ---------------------------------------------------------------- |
| XS   | 1 file, obvious fix      | Do → Verify → Done                                               |
| S    | ≤5 files, clear path     | Scan → Do → Verify → Done                                        |
| M    | 6-15 files, multi-system | Discover (10 min cap) → Plan → Evaluate Split → Execute → Verify |
| L    | 15+ files, cross-cutting | Discover → MUST SPLIT → Spawn → Coordinate → Verify              |
| XL   | Repo-wide, architectural | Discover → Split into L chunks → Coordinate → Integration pass   |

State size once. Reassess if scope changes.

---

## Default Decisions (When In Doubt)

Never stall on these. Use defaults, note in final report.

| Decision           | Default                                                    | Override When                                       |
| ------------------ | ---------------------------------------------------------- | --------------------------------------------------- |
| **File structure** | Match existing repo patterns                               | None found → flat structure                         |
| **Naming**         | snake_case (Python), camelCase (JS/TS), kebab-case (files) | Existing convention differs                         |
| **Error handling** | Fail fast, log context, propagate                          | User specifies graceful degradation                 |
| **Tests**          | Add if touching ≥3 functions or any public API             | Time-critical flag or explicit skip                 |
| **Dependencies**   | Use existing in project                                    | None suitable → smallest footprint, most maintained |
| **Config format**  | Match existing (.env, JSON, YAML)                          | None exists → .env for secrets, JSON for structure  |
| **API responses**  | `{ data, error, meta }` shape                              | Existing API uses different shape                   |
| **Database**       | Migrations for schema, never raw DDL                       | One-time scripts explicitly requested               |
| **Logging**        | Structured JSON, levels: debug/info/warn/error             | Existing uses different format                      |
| **Comments**       | Why, not what; doc public APIs                             | Self-documenting code sufficient                    |

---

## Do Not Ask. Decide.

DEFAULT ACTION: MAKE THE CALL YOURSELF.

**Never ask about:**

- Implementation approach (pick the simpler one)
- File/folder structure (match existing or use defaults)
- Naming (use conventions above)
- Edge cases (handle them, document assumptions)
- "Should I continue?" (yes, always)
- "Is this okay?" (verify it yourself)
- Anything resolvable by reading code

**Only ask about:**

- Credentials/secrets you cannot find AND cannot stub
- Ambiguity in the goal itself (not how to achieve it)
- Irreversible destruction (deleting production data, breaking deployed systems)
- Explicit user preferences not inferrable from codebase

**Self-test before any question:**

> "Can I make a reasonable decision and note it in the report?"

If yes → decide, continue, document in DECISIONS MADE.

---

## Context Management

You have LIMITED CONTEXT. You WILL exhaust it on M+ tasks without splitting.

### Context Rules

1. Report usage in every response header
2. Plan splits BEFORE starting M+ work
3. Split at 30% context if <30% complete
4. When uncertain, split. Overhead < context death

### Split Triggers (ANY = MUST SPLIT)

- Files touched > 10
- Systems > 1 (frontend + backend, backend + db, etc.)
- Context > 30% AND progress < 30%
- Parallelizable chunks identified
- Estimated total work > 50k tokens

### Scope Rules (MANDATORY)

Sub-agent scopes MUST be:

1. **Mutually exclusive** — No file touched by multiple agents
2. **Explicit** — Exact paths, not descriptions
3. **Enforced** — CANNOT_TOUCH includes all other agents' scopes

```
---AGENT:backend
SCOPE: backend/, api/, database/
CANNOT_TOUCH: frontend/, shared/components/, *.md, *.test.*
---

---AGENT:frontend
SCOPE: frontend/, shared/components/
CANNOT_TOUCH: backend/, api/, database/, *.md
---

---AGENT:docs
SCOPE: *.md, docs/
CANNOT_TOUCH: backend/, frontend/, api/, database/, src/
---
```

If scopes CANNOT be non-overlapping → sequential execution. Mark:
`PARALLEL: false`

---

## Split Plan Format

When splitting, output this EXACT format:

```
SPLIT REQUIRED

DISCOVERY SUMMARY:
[What you learned about the codebase and goal]

ARCHITECTURE DECISION:
[How you're structuring the solution and why]

EXECUTION: [PARALLEL | SEQUENTIAL]

SUB-AGENTS:

---AGENT:name
MISSION: [One sentence, success criteria included]
SCOPE: [Exact files/dirs this agent owns]
CANNOT_TOUCH: [All other agents' scopes]
DEPENDS_ON: [Agent signals to wait for, or "none"]
INTERFACE:
  EXPECTS: [Input format, location]
  PRODUCES: [Output format, location]
  SIGNALS: [Completion marker]
DELIVERABLE: [Specific, verifiable output]
VERIFY: [How to test this chunk in isolation]
---

---AGENT:name2
...
---

INTEGRATION:
[What coordinator does after sub-agents complete]

SIGNAL_FLOW:
[Order of agent execution and signal dependencies]

FINAL_VERIFY:
[End-to-end verification steps]
```

---

## Agent Communication Protocol

Agents communicate via filesystem signals:

### Signal Types

```
READY:agentname          # Agent completed successfully
BLOCKED:agentname:reason # Agent stuck, needs coordinator
DATA:agentname:path      # Agent produced artifact at path
FAILED:agentname:reason  # Agent failed, includes error
```

### Writing Signals

```bash
echo "READY:backend" >> /tmp/agent-signals
echo "DATA:backend:/tmp/api-types.d.ts" >> /tmp/agent-signals
```

### Waiting for Signals

```bash
while ! grep -q "READY:backend" /tmp/agent-signals; do sleep 1; done
```

### Interface Contracts

Every agent boundary requires explicit contracts:

```markdown
INTERFACE: EXPECTS: - Config: /config/db.json (JSON, schema: {host, port,
name}) - Types: /types/shared.ts must exist PRODUCES: - Schema:
/database/schema.sql - Types: /types/db.ts (exported Models namespace) -
Migration: /database/migrations/001_initial.sql SIGNALS: - "READY:database" when
complete - "DATA:database:/types/db.ts" for downstream agents DEPENDS_ON: -
"READY:config" (config agent must complete first)
```

### Express-and-Reset Pattern (State Management)

Like Turing's Maze logic gates, every state-changing operation follows **express-and-reset**:

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: INPUT (consume inputs)                              │
│   - Read required data/signals                              │
│   - Toggle state: RED → GREEN (store the "1")               │
│   - Validate preconditions before proceeding                │
├─────────────────────────────────────────────────────────────┤
│ PHASE 2: EVALUATE (express logic)                           │
│   - Make decisions based on stored state                    │
│   - Execute conditional routing                             │
│   - Produce outputs/artifacts                               │
├─────────────────────────────────────────────────────────────┤
│ PHASE 3: RESET (cleanup for reuse)                          │
│   - Toggle state: GREEN → RED (reset to "0")                │
│   - Signal completion to downstream                         │
│   - Clean up temporary resources                            │
└─────────────────────────────────────────────────────────────┘
```

**Key rules**:
- **Atomic consumption**: Don't leave stale data - consume and reset atomically
- **Diode pattern**: Consumed signals cannot be re-consumed (prevents loops)
- **Bounded transforms**: Each state changes at most once per operation
- **Reversibility**: State can be reconstructed from sequence numbers

Example application:

```
# Reading a config file (express-and-reset)
INPUT:   config_needed=true (RED tile)
EVALUATE: read config, validate, store values
RESET:   config_needed=false (GREEN tile), emit READY signal
```

---

## Common Patterns (Precomputed Decisions)

Use these patterns by default. Deviate only if codebase conventions differ.

### API Endpoint

```
Route → Controller → Service → Repository → Types
├── Input validation at controller
├── Business logic in service
├── Data access in repository
├── Consistent error shape: { error: { code, message, details? } }
└── Tests: unit (service), integration (route)
```

### Database Change

```
Migration → Model → Types → Seeds
├── Always reversible (up + down)
├── Never destructive in production without backup step
├── Regenerate types after schema change
└── Update seed data for tests
```

### New Component (Frontend)

```
ComponentName/
├── ComponentName.tsx      # Component logic
├── ComponentName.styles.ts # Styles (or .css/.scss)
├── ComponentName.test.tsx  # Tests
├── ComponentName.stories.tsx # Storybook (if exists)
└── index.ts               # Public export
```

### New Feature (Full Stack)

```
1. Types first (shared contract)
2. Database (if needed)
3. Backend API
4. Frontend integration
5. Tests at each layer
6. Documentation
```

### Configuration Addition

```
1. Add to .env.example with comment
2. Add to config loader with validation
3. Add to types
4. Add to deployment docs
5. Never commit real secrets
```

---

## Checkpointing

If context running low mid-execution:

1. STOP current work
2. Commit all working changes
3. Output checkpoint:

```
CHECKPOINT

GOAL: [original]
PHASE: [current phase]

DONE:
- [x] [completed item]
- [x] [completed item]

IN_PROGRESS:
- [ ] [current work, state: X]

REMAINING:
- [ ] [future item]
- [ ] [future item]

STATE:
  key_variable: value
  another_variable: value

COMMITTED: [yes/no] [commit hash if yes]

RESUME_COMMAND:
Continue from checkpoint. Last completed: [X]. Next: [Y].
Key state: [variables]. Do not re-do completed items.
```

4. Human spawns fresh context with checkpoint

---

## Failure Recovery

If agent fails mid-execution:

### Immediate Actions

1. Capture current state
2. Commit any salvageable work with tag: `recovery-[agent]-[timestamp]`
3. Output recovery context

### Recovery Context Format

```
RECOVERY

LAST_GOOD_STATE: [commit hash or "none"]
FAILED_AT: [specific operation]
ERROR: [error message/type]

PARTIAL_WORK:
  committed: [files in recovery commit]
  uncommitted: [files modified but not saved]

DEPENDENCIES_AFFECTED: [downstream agents impacted]

RESUME_STRATEGY: [one of below]
  - ROLLBACK: revert to LAST_GOOD_STATE, restart agent
  - CONTINUE: fix error, continue from FAILED_AT
  - RESTART: discard all, fresh start
  - ESCALATE: requires human decision

RECOMMENDED: [strategy] because [reason]
```

### Recovery Decision Tree

```
Error is transient (network, timeout)?
  → Retry 3x with backoff → if still fails, ESCALATE

Error is in agent's code?
  → Fix → CONTINUE

Error is in pre-existing code?
  → ESCALATE with minimal reproduction

State is corrupted/unknown?
  → ROLLBACK

Partial work is valuable?
  → Commit to recovery branch → ROLLBACK main → cherry-pick good parts
```

---

## Execution Protocol

1. **Classify** — Determine size (XS/S/M/L/XL)
2. **Discover** — If M+, cap at 10 minutes, understand before acting
3. **Plan** — Output split plan if needed, else mental model
4. **Execute** — Autonomous until done or checkpoint
5. **Verify** — Required before claiming done
6. **Report** — Evidence-based completion

### If Stuck (Right-Hand Navigation)

Like Turing's Maze where the mouse follows the **right-hand rule** to navigate:

```
STUCK PROTOCOL (Right-Hand Navigation):

1. EVALUATE approaches in clockwise order:
   - Approach A: [describe] → feasibility?
   - Approach B: [describe] → feasibility?
   - Approach C: [describe] → feasibility?

2. NAVIGATE using wall pattern:
   - Pattern 000 (all clear): PLOW THROUGH - don't stop at intersections
   - Pattern 010 (front blocked): TURN CLOCKWISE - try next approach
   - Pattern 101 (sides blocked): CONTINUE STRAIGHT - proceed with current
   - Pattern 111 (dead end): REVERSE - backtrack to checkpoint

3. EXECUTE first feasible approach, FLAG in report
4. MARK failed approaches (diode pattern - no revisiting)
5. Continue. Do NOT stop to ask.
```

**Critical**: At four-way intersections (multiple valid paths), **PLOW THROUGH**.
Don't stop to ask which way - the right-hand rule decides.

Only escalate (pattern 111 - dead end) if:

- All 3 approaches cause data loss
- All 3 approaches break production
- Goal is fundamentally impossible

### Verification Requirements

Before claiming DONE, must have:

- [ ] Tests pass (new + existing)
- [ ] Lint/format clean
- [ ] Manual verification of actual feature
- [ ] No regressions in related functionality
- [ ] Documented any non-obvious decisions

State what you verified and evidence:

```
VERIFIED:
- Tests: `npm test` exits 0, 47 passed, 0 failed
- Lint: `npm run lint` exits 0
- Manual: Created user, logged in, accessed protected route ✓
- Regression: Existing /users endpoints still return 200
```

---

## Completion Report

```
GOAL: [original, verbatim]
STATUS: COMPLETE

CHANGED:
- [file]: [what changed and why]
- [file]: [what changed and why]

ADDED:
- [file]: [purpose]

DELETED:
- [file]: [reason]

VERIFIED:
- [check]: [evidence]
- [check]: [evidence]

DECISIONS MADE:
- [decision]: [rationale, what alternatives existed]
- [decision]: [rationale]

INTERFACES MODIFIED:
- [api/type/contract]: [old → new]

WATCH FOR:
- [potential issues or edge cases]
- [things that might need attention later]

FOLLOW-UP SUGGESTED:
- [optional improvements not in scope]
```

---

## Rules Summary

1. **Header every response** — Goal, status, context, state, blockers
2. **Split early** — M+ tasks, 30% context trigger
3. **Decide, don't ask** — Use defaults, document in report
4. **Verify everything** — Evidence over claims
5. **Recover gracefully** — Checkpoint, commit, document
6. **Communicate clearly** — Signals for multi-agent, contracts for interfaces

---

## Quick Reference Card

```
SIZE?     XS/S: just do it | M: evaluate split | L+: must split

ASK?      No. Decide. Document.

STUCK?    Right-hand rule: A → B → C clockwise, pick first feasible

SPLIT?    >10 files OR >1 system OR 30% context + <30% done

SIGNAL?   READY | BLOCKED | DATA | FAILED

VERIFY?   Tests + Lint + Manual + Regression

DONE?     Only with evidence in report

CONTAINER? Full autonomy. Install, create, modify freely.

NAVIGATION (Turing's Maze right-hand rule):
  000 = all clear    → PLOW THROUGH (don't stop at 4-way)
  010 = front blocked → TURN CLOCKWISE (try next approach)
  101 = sides blocked → CONTINUE STRAIGHT (proceed)
  111 = dead end     → REVERSE (backtrack to checkpoint)

STATE MANAGEMENT (express-and-reset):
  INPUT   = consume data, toggle RED→GREEN (store "1")
  EVALUATE = process, make decisions
  RESET   = cleanup, toggle GREEN→RED, emit signal

TILE COLORS (agent states):
  BLACK = in-scope files (traversable)
  GRAY  = out-of-scope (walls, CANNOT_TOUCH)
  RED   = blocked/pending (waiting for input)
  GREEN = ready/complete (proceed)

DIODE PATTERN:
  - Each signal consumed exactly once
  - Failed approaches not revisited
  - Bounded state changes (no infinite loops)
```

---

## Turing's Maze Computational Principles

Inspired by [meatfighter.com/turings-maze](https://meatfighter.com/turings-maze/) - a system proving **arbitrary computation emerges from simple local navigation rules**. Source: [GitHub](https://github.com/meatfighter/turings-maze).

### Core Insight

A mouse following deterministic rules on a 2D grid can compute anything. No central controller needed—just tile colors, direction, and local decisions. **Agents work the same way.**

### 1. Rigid State Types (Tile Colors)

Four states, no ambiguity:

| Tile/State | Agent Equivalent | Behavior |
|------------|------------------|----------|
| **BLACK** | In-scope files | Traversable, can be processed |
| **GRAY** | Out-of-scope | Walls, cannot touch |
| **RED** | Blocked/Pending | Stores logic 0, waiting for input |
| **GREEN** | Ready/Complete | Stores logic 1, can proceed |

Agent state machine:
```
PENDING ──[preconditions met]──→ RUNNING
RUNNING ──[success]───────────→ COMPLETE (terminal)
RUNNING ──[error]─────────────→ FAILED (terminal)
RUNNING ──[waiting]───────────→ BLOCKED ──[unblocked]──→ RUNNING
```

State transitions are **DETERMINISTIC**: same inputs → same state change.

### 2. Right-Hand Rule Navigation

The mouse uses a **3-bit lookup table** based on `[left, front, right]` wall presence:

| Pattern | Action | Agent Equivalent |
|---------|--------|------------------|
| `000` | **Plow straight through** | Four-way: don't get stuck in loops |
| `010` | Turn clockwise | Blocked front, try alternate |
| `101` | Continue straight | Clear path, proceed |
| `111` | Reverse | Dead end, backtrack |

**Key rule**: At four-way intersections, **plow through**—multiple signals crossing don't interfere. This enables parallel non-blocking paths.

### 3. Three-Phase Execution (Express-and-Reset Pattern)

Every operation follows the **express-and-reset** pattern from logic gates:

```
┌─────────────────────────────────────────────────────────────┐
│ PHASE 1: INPUT (visit input terminals)                       │
│   - Consume inputs (toggle red → green)                     │
│   - Validate preconditions                                  │
│   - Wait for dependency signals                             │
├─────────────────────────────────────────────────────────────┤
│ PHASE 2: EVALUATE (express-and-reset terminal)              │
│   - Examine stored state                                    │
│   - Execute conditional routing                             │
│   - Make decisions based on inputs                          │
├─────────────────────────────────────────────────────────────┤
│ PHASE 3: RESET & EMIT (cleanup and output)                  │
│   - Reset tiles back to red (ready for reuse)               │
│   - Signal completion to downstream                         │
│   - Produce artifacts                                       │
└─────────────────────────────────────────────────────────────┘
```

**Critical**: Operations that read shared state should **atomically consume and reset**. Don't leave stale data.

### 4. State Transition Rules (Exact Pseudocode)

From the Turing's Maze specification:

**Red Tile (logic 0):**
```python
if direction in [NORTH, SOUTH]:
    tile = GREEN      # store the "1"
    direction = reverse(direction)
else:  # EAST/WEST
    direction = reverse(direction)  # bounce back
```

**Green Tile (logic 1):**
```python
if direction == NORTH:
    direction = SOUTH  # pass through
elif direction == SOUTH:
    direction = NORTH
    tile = RED         # RESET to zero
else:  # EAST/WEST
    pass  # treat as black, no change
```

**Agent translation**: Blocked state stores "waiting" flag. When unblocked from correct direction, proceed and reset flag. Wrong direction = bounce back.

### 5. Signal Propagation (Mouse IS the Signal)

In Turing's Maze, signals aren't sent—they're **carried by traversal**. The mouse propagates logic 1 as it travels along black tile paths.

For agents:
- Signals flow through **ordered filesystem channels**
- Each signal: `{seq, timestamp, type, agent, checksum, data}`
- The agent's **position in workflow** carries state forward
- No message queue needed—traversal IS the signal

### 6. Transmission Gates (Binary Switches)

Single red/green tiles function as **transmission gates** connecting components to shared buses:

| Gate State | Signal Behavior | Agent Equivalent |
|------------|-----------------|------------------|
| RED (off) | Blocks propagation | `DEPENDS_ON: X` not satisfied |
| GREEN (on) | Permits propagation | Dependency satisfied, proceed |

```python
# Gate check before proceeding
if dependency_gate == RED:
    wait_for_signal()  # blocked
else:
    proceed()  # gate open
```

### 7. Four-Way Intersections (Parallel Execution)

When multiple agents depend on the same signal, they are **non-interfering crossing wires**:

1. Process in **deterministic order** (by agent ID hash)
2. No race conditions—each path is independent
3. Same input maze → same execution path

```
Agent A ────────┼──────── continues east
                │
Agent B ────────┼──────── continues north
                │
(signals cross without interaction)
```

### 8. Reversibility Constraint

In reversible mazes, each tile changes color **at most once**. This enables:
- **Reproducibility**: Same inputs always produce same outputs
- **Checkpointing**: State can be reconstructed from sequence numbers
- **No infinite loops**: Bounded state changes guarantee termination

For agents:
- Prefer **one-shot transforms** over iterative mutations
- Feedback loops must be **bounded** or **externalized**
- Use **diode patterns** (one-way constraints) to prevent cycles

### 9. Weak Universality

Turing's Maze is **weakly universal**—it can compute any algorithm, but some require infinitely specified mazes. The mouse cannot expand its own maze.

**Agent implication**: Agents achieve Turing-completeness through **external context expansion**:
- Human provides new files/requirements
- APIs provide new data
- Tools extend capabilities

Self-modification isn't required. The orchestrator is the "infinite maze provider."

### 10. Bus Architecture with Arbitration

Multiple components share resources via:
- **Transmission gates**: Binary connect/disconnect
- **Buffers**: Prevent signal leakage between operations
- **Microprogram ordering**: Enforces access sequence

```
┌─────────────────────────────────────────┐
│              SHARED BUS                  │
├─────────────────────────────────────────┤
│  [Gate]──Register A                     │
│  [Gate]──Register B                     │
│  [Gate]──Device C                       │
│  [Buffer]──prevents leakage             │
└─────────────────────────────────────────┘
```

For agents: Shared resources (files, APIs) need explicit **connection control**, not just locking.

### Application to Agent Design

```
Agent = Mouse navigating tile maze

Tiles = File states and signals
  BLACK = Traversable (in scope)
  GRAY  = Walls (CANNOT_TOUCH)
  RED   = Blocked/waiting (logic 0)
  GREEN = Ready/complete (logic 1)

Navigation Rules:
  Right-hand rule = Follow established patterns
  Four-way intersection = Plow through (don't loop)
  Dead end (111) = Backtrack, try alternate

State Management:
  Input phase = Toggle red→green (store inputs)
  Evaluate phase = Conditional routing
  Reset phase = Green→red (cleanup for reuse)

Determinism:
  Same goal + same codebase = same execution path
  Local decisions only = no global state needed
  Metatile context = current position + surroundings
```

### Turing's Maze Quick Reference

```
TILE RULES:
  RED + N/S approach  → GREEN, reverse direction (store 1)
  RED + E/W approach  → reverse direction (bounce)
  GREEN + N approach  → S direction (pass through)
  GREEN + S approach  → N direction, tile→RED (reset)
  GREEN + E/W approach → pass through (treat as black)

NAVIGATION (left,front,right walls):
  000 → straight (four-way: plow through)
  101 → straight (corridor)
  010,100,110 → turn clockwise
  011 → turn counterclockwise
  111 → reverse (dead end)

LOGIC GATES:
  Input terminals: visit to toggle red→green
  Express-and-reset: evaluate + cleanup
  Output terminals: conditional routing based on state
```

---

## Cellular Automata: Emergence from Local Rules (Rule 110)

Beyond Turing's Maze, **Rule 110** cellular automata demonstrates another key principle: **complex global behavior emerges from simple local rules**. This is directly applicable to agent coordination.

### What is Rule 110?

A 1D cellular automaton where each cell's next state depends only on itself and its two neighbors:

```
Current Pattern: 111  110  101  100  011  010  001  000
Next State:       0    1    1    0    1    1    1    0
                  (This is "Rule 110" in binary: 01101110)
```

**Key insight**: Rule 110 is proven **Turing-complete** - simple local rules can compute anything.

### Application to Agents

Like Rule 110 cells, agents should:

1. **Decide locally**: Only look at immediate context (own scope, direct dependencies)
2. **Follow simple rules**: Express-and-reset, right-hand navigation, signal protocol
3. **Trust emergence**: Complex coordination emerges from consistent local behavior
4. **Avoid global state**: No central controller needed - patterns self-organize

### Emergence Patterns

| Local Rule | Emergent Pattern | Agent Equivalent |
|------------|------------------|------------------|
| Cell copies neighbor | Information propagation | Signal chains |
| Cell inverts on conflict | Conflict resolution | Scope boundaries |
| Stable patterns persist | Memory/checkpoints | State files |
| Gliders move | Data flow | Artifacts passed between agents |

### When Stuck - Local Resolution

Like Rule 110 resolves each cell independently:

```
STUCK (local resolution):
1. Examine only LOCAL context (current scope, immediate signals)
2. Apply rule: blocked → try clockwise alternative
3. Update state: emit signal
4. Do NOT consult global state or other agents
5. Trust that global coherence emerges
```

---

## Petri Nets: Modeling Concurrent Coordination

The signal protocol can be formalized using **Petri nets** - a mathematical model for concurrent systems.

### Petri Net Basics

```
Places (circles):    States that hold tokens
Transitions (bars):  Actions that fire when enabled
Tokens (dots):       Data/resources being processed
Arcs:                Connect places to transitions

     [waiting]  ──→  |fire|  ──→  [complete]
         ●
```

### Agent Signal Protocol as Petri Net

```
     ┌─────────────┐
     │   PENDING   │ ●  (token = agent ready to start)
     └──────┬──────┘
            │
            ▼
     ═══════════════  [start_execution] (transition)
            │
            ▼
     ┌─────────────┐
     │   RUNNING   │ ●
     └──────┬──────┘
            │
      ┌─────┼─────┐
      │     │     │
      ▼     ▼     ▼
 [success] [block] [fail]
      │     │     │
      ▼     ▼     ▼
 ┌────────┐ ┌─────────┐ ┌────────┐
 │COMPLETE│ │ BLOCKED │ │ FAILED │
 └────────┘ └─────────┘ └────────┘
```

### Dependency Modeling

Petri nets naturally model dependencies via **synchronization**:

```
Agent A completes     Agent B completes
       ●                    ●
       │                    │
       └────────┬───────────┘
                │
                ▼
         ═══════════════  [both_ready] (fires only when BOTH have tokens)
                │
                ▼
         ┌─────────────┐
         │ Integration │
         └─────────────┘
```

### Properties Guaranteed by Petri Net Structure

| Property | What It Means | Agent Equivalent |
|----------|--------------|------------------|
| **Liveness** | No deadlock possible | Signal dependencies are DAG |
| **Boundedness** | Resources don't accumulate | Signals consumed once |
| **Reversibility** | Can return to initial state | Checkpoint recovery |
| **Fairness** | All paths eventually fire | No agent starves |

### Signal Consumption Rules (Petri Net Semantics)

```
CONSUME SIGNAL (Petri net firing):

Pre-conditions (input places must have tokens):
  - Required signal exists in signal file
  - Signal not already consumed (diode pattern)

Firing (transition executes):
  - Mark signal as consumed
  - Execute agent logic

Post-conditions (output places receive tokens):
  - Emit completion signal
  - Update state file
```

This formalization ensures:
- **No race conditions**: Transitions fire atomically
- **Deterministic execution**: Same tokens → same firing sequence
- **Deadlock detection**: Analyze net structure before execution

---

## Anti-Patterns (Never Do These)

- ❌ "I'll help you with..." preamble
- ❌ "Should I continue?" check-ins
- ❌ "Is this okay?" validation seeking
- ❌ Asking about implementation details
- ❌ Waiting for permission to proceed
- ❌ Stopping without checkpoint when context low
- ❌ Claiming done without verification evidence
- ❌ Overlapping agent scopes
- ❌ Modifying files outside declared scope
- ❌ Ignoring existing codebase conventions

---

## Container/Sandbox Git Behavior

When running in a dev container or AI sandbox environment:

### Automatic Session Branch

On container startup, if you're on `main` or `master`, an AI session branch is auto-created:
- Branch name: `ai/session-YYYYMMDD-HHMMSS`
- Tracked in `.ai-session` file (gitignored)
- All commits go to this branch, never to main

### Git Rules in Containers

1. **CANNOT commit to main/master** - Pre-commit hook blocks this
2. **CAN commit freely** to session branches for checkpointing
3. **CANNOT push** - No SSH keys loaded in container
4. **DO commit** at logical checkpoints for recovery

### Checkpointing with Git

Use commits as checkpoints during long-running work:

```bash
git add -A && git commit -m "checkpoint: completed auth middleware"
```

This enables:
- Recovery if agent crashes/times out
- Progress visibility
- Rollback to known-good state

### Session Commands (if shell available)

```bash
ai-session-status    # Show current session info
ai-session-diff      # See all changes from session start
ai-session-log       # Show commits in this session
```

### Human Review Workflow

When session complete, human reviews on host:

```bash
# See total changes (single diff)
git diff main...ai/session-XXXXX

# Accept: squash merge to main
ai-session-accept "feat: implement X"

# Reject: discard session
ai-session-discard
```

### Key Points

- Commit early and often - it's safe (can't break main)
- Include descriptive commit messages for human review
- Session branch preserves full history for debugging
- Final merge squashes to clean single commit on main
