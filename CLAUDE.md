# Claude Harness Plugin

## Project Overview
Claude Code plugin for automated, context-preserving coding sessions with feature tracking, GitHub integration, and multi-agent orchestration.

## Tech Stack
- Shell/Bash (setup.sh, init.sh)
- Markdown (commands)
- JSON (configuration, state files)

## Session Startup Protocol
On every session start:
1. Run `pwd` to confirm working directory
2. Read `.claude-harness/working-context.json` for active working state (if exists)
3. Read `.claude-harness/claude-progress.json` for context
4. Run `git log --oneline -5` to see recent changes
5. Check `.claude-harness/feature-list.json` for current priorities

## Project Structure
- `commands/` - Harness command definitions (markdown)
- `.claude-plugin/` - Plugin configuration
- `setup.sh` - Installation script

## Development Rules
- Work on ONE feature at a time
- Always update `.claude-harness/claude-progress.json` after completing work
- Update version in `.claude-plugin/plugin.json` for every change
- Update changelog in `README.md`
- Commit with descriptive messages
- Leave codebase in clean, working state

## Available Commands
- `/claude-harness:setup` - Initialize harness in project
- `/claude-harness:start` - Start session with GitHub dashboard
- `/claude-harness:feature` - Add new feature
- `/claude-harness:orchestrate` - Spawn multi-agent team
- `/claude-harness:checkpoint` - Save progress, create PR
- `/claude-harness:merge-all` - Merge all PRs with auto-versioning

## Orchestration Architecture: Hybrid Turing's Maze + Mandelbrot

The `/claude-harness:orchestrate` command uses a **hybrid computational model** combining two algorithmic approaches:

### Turing's Maze (Execution Layer)
**Deterministic agent navigation** based on local rules:
- **Three-phase execution**: READ (preconditions) → TRANSFORM (work) → EMIT (results)
- **Signal-based coordination**: Agents communicate via filesystem signals
- **Right-hand rule navigation**: Agents follow established patterns deterministically
- **Express-and-reset pattern**: Each agent reads inputs, executes, emits outputs, resets state

### Mandelbrot Set (Planning Layer)
**Adaptive supervision and decomposition** based on mathematical convergence principles:

1. **Escape-Time Supervision** (`|z|² > 4` analog):
   - Track agent trajectory via divergence_score
   - Detect agents making unbounded progress vs diverging
   - Early abort when divergence_score >= threshold (default 100)
   - Classification: BOUNDED | ESCAPING | CONVERGED

2. **Fractal Task Decomposition** (self-similar recursion):
   - Measure complexity: file_count + (system_count × 2) + decision_count
   - Compare to ESCAPE_RADIUS (default 4) adjusted by depth
   - Recommendation: ATOMIC (proceed) | DECOMPOSE (split into sub-orchestrators)
   - Same orchestration logic applies at all decomposition levels

3. **Fixed-Point Convergence Detection** (`f(z) = z`):
   - Track verification loop outputs in ITERATION_OUTPUTS
   - Compute similarity between iterations
   - If similarity >= CONVERGENCE_THRESHOLD (default 95%): Fixed point reached
   - Detect oscillation patterns (A → B → A) using Floyd's algorithm

4. **Bounded Region Analysis** (Julia set connectivity):
   - Analyze agent scope overlaps before parallel execution
   - DISCONNECTED scopes → safe parallel execution
   - CONNECTED scopes → serialize within connected components
   - Prevents coordination conflicts

5. **Supervision Tree with Restart Limits** (max_iteration analog):
   - Track restart count per agent within time window (default 300s)
   - Max restarts per agent: 3 (configurable)
   - Restart strategies: RESTART | RESTART_WITH_PERTURBATION | ESCALATE
   - Prevents infinite retry loops

### How They Work Together

```
┌─────────────────────────────────────────────────────────────────┐
│  PLANNING LAYER (Mandelbrot)                                    │
│  - Measures complexity → decides ATOMIC vs DECOMPOSE            │
│  - Analyzes scope connectivity → parallel vs serial             │
│  - Detects convergence → terminates loops early                 │
│  - Tracks trajectories → aborts diverging agents                │
│  - Enforces restart limits → prevents infinite loops            │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼ (informs)
┌─────────────────────────────────────────────────────────────────┐
│  EXECUTION LAYER (Turing's Maze)                                │
│  - Spawns agents following execution plan                       │
│  - Coordinates via signals (READY, FAILED, BLOCKED, DATA)       │
│  - Manages handoffs between sequential agents                   │
│  - Runs verification loops with aggregation                     │
└─────────────────────────────────────────────────────────────────┘
```

**Mathematical Basis:**
- Turing's Maze: Deterministic state machines, local rules → global behavior
- Mandelbrot: Iteration dynamics, escape-time detection, convergence analysis

**Signals:**
- Standard: READY, FAILED, BLOCKED, DATA
- Mandelbrot: ESCAPING, CONVERGED, OSCILLATING, ESCALATE, DECOMPOSED

**CLI Options:**
- `--fractal-depth N`: Max decomposition levels (default: 3)
- `--escape-threshold N`: Divergence score limit (default: 100)
- `--convergence-threshold N`: Similarity % for fixed-point (default: 95%)

## Progress Tracking
See: `.claude-harness/claude-progress.json` and `.claude-harness/feature-list.json`
