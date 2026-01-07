# Mandelbrot-Inspired Orchestrator Refactoring Prompt

## CONTEXT

You are refactoring a Claude Code multi-agent orchestrator script that currently uses a "Turing's Maze" three-phase model (READ → TRANSFORM → EMIT). The goal is to incorporate Mandelbrot set algorithmic concepts to improve agent supervision, task decomposition, and convergence detection.

**NOTE**: This prompt uses function names and section markers rather than line numbers. Before modifying, run `grep -n "function_name\|SECTION_MARKER" orchestrate` to find current locations in your version.

## CURRENT ARCHITECTURE SUMMARY

The existing script has:
- **Signal-based coordination** with checksums and sequence numbers
- **Three-phase agent execution**: READ (check preconditions) → TRANSFORM (execute work) → EMIT (output results)
- **Parallel/sequential agent spawning** with dependency graphs
- **Iterative feedback loop** for refinement cycles
- **Checkpointing** for recovery
- **Simple timeout-based failure detection** (TIMEOUT variable, default 6 hours)
- **Linear retry logic** with exponential backoff (MAX_RETRIES, RETRY_BASE_DELAY)

## MANDELBROT CONCEPTS TO IMPLEMENT

### 1. Escape-Time Supervision (Replace Simple Timeouts)

**Mathematical basis**: In Mandelbrot rendering, `|z|² > 4` guarantees divergence. Rather than asking "has this run too long?", ask "is this agent making bounded progress?"

**Implementation requirements**:

```bash
# NEW: Divergence detection state
DIVERGENCE_SCORE=0
DIVERGENCE_THRESHOLD=100
CONVERGENCE_WINDOW=5  # iterations to confirm convergence
ESCAPE_RADIUS=4       # complexity threshold for atomic vs recursive

# NEW: Metrics to track per agent
declare -A AGENT_METRICS
# - output_hash: MD5 of last output (detect stagnation)
# - change_rate: % change between iterations
# - token_efficiency: tokens per progress unit
# - state_transitions: unique states visited
```

**Escape detection function**:
```bash
# Returns: BOUNDED | ESCAPING | CONVERGED
check_agent_trajectory() {
    local agent_id="$1"
    local current_output="$2"
    local current_hash=$(echo "$current_output" | md5sum | cut -d' ' -f1)
    local prev_hash="${AGENT_METRICS[$agent_id:output_hash]:-}"
    
    # Calculate change rate
    local change_rate=100
    if [[ -n "$prev_hash" ]]; then
        if [[ "$current_hash" == "$prev_hash" ]]; then
            change_rate=0
        else
            # Approximate change via diff size ratio
            change_rate=$(compute_semantic_change "$prev_hash" "$current_hash")
        fi
    fi
    
    # Update divergence score (smooth iteration count analog)
    local score="${AGENT_METRICS[$agent_id:divergence_score]:-0}"
    if [[ $change_rate -lt 5 ]]; then
        score=$((score + 25))  # Accelerating toward escape
    elif [[ $change_rate -lt 20 ]]; then
        score=$((score + 5))   # Slow progress
    else
        score=$((score > 15 ? score - 15 : 0))  # Good progress, pull back
    fi
    
    # Store updated metrics
    AGENT_METRICS[$agent_id:output_hash]="$current_hash"
    AGENT_METRICS[$agent_id:divergence_score]="$score"
    AGENT_METRICS[$agent_id:change_rate]="$change_rate"
    
    # Classification
    if [[ $score -ge $DIVERGENCE_THRESHOLD ]]; then
        echo "ESCAPING"
    elif [[ $change_rate -lt 2 ]] && [[ $score -lt 20 ]]; then
        echo "CONVERGED"
    else
        echo "BOUNDED"
    fi
}
```

### 2. Fractal Task Decomposition (Self-Similar Recursion)

**Mathematical basis**: Mini-Mandelbrots appear at all scales. The same coordination logic should apply at every level of task hierarchy.

**Implementation requirements**:

```bash
# NEW: Fractal orchestration parameters
FRACTAL_DEPTH=${FRACTAL_DEPTH:-0}
FRACTAL_MAX_DEPTH=${FRACTAL_MAX_DEPTH:-3}
FRACTAL_ESCAPE_THRESHOLD=${FRACTAL_ESCAPE_THRESHOLD:-4}  # Complexity threshold

# Complexity measurement (file count + decision count + system count)
measure_task_complexity() {
    local task_description="$1"
    local file_count=$(echo "$task_description" | grep -oE '[0-9]+ files?' | head -1 | grep -oE '[0-9]+' || echo "1")
    local system_count=$(echo "$task_description" | grep -cE 'frontend|backend|database|api|auth' || echo "1")
    local decision_count=$(echo "$task_description" | grep -cE 'decide|choose|option|alternative' || echo "0")
    
    echo $((file_count + system_count * 2 + decision_count))
}

# Fractal decomposition decision
should_decompose() {
    local complexity="$1"
    local current_depth="${FRACTAL_DEPTH:-0}"
    
    # Escape threshold tightens with depth (like zoom requiring more iterations)
    local adjusted_threshold=$((FRACTAL_ESCAPE_THRESHOLD * (FRACTAL_MAX_DEPTH - current_depth + 1) / FRACTAL_MAX_DEPTH))
    
    if [[ $complexity -gt $adjusted_threshold ]] && [[ $current_depth -lt $FRACTAL_MAX_DEPTH ]]; then
        echo "DECOMPOSE"
    else
        echo "ATOMIC"
    fi
}
```

**Self-similar sub-orchestrator spawning**:
```bash
spawn_fractal_agent() {
    local subtask="$1"
    local parent_correlation="$2"
    
    # Spawn with incremented depth and inherited parameters
    FRACTAL_DEPTH=$((FRACTAL_DEPTH + 1)) \
    FRACTAL_MAX_DEPTH=$FRACTAL_MAX_DEPTH \
    FRACTAL_ESCAPE_THRESHOLD=$FRACTAL_ESCAPE_THRESHOLD \
    CORRELATION_ID="${parent_correlation}.${FRACTAL_DEPTH}" \
    "$0" "$subtask" &
    
    echo $!  # Return PID for supervision
}
```

### 3. Fixed-Point Convergence Detection (Feedback Loop Termination)

**Mathematical basis**: Fixed points satisfy `f(z) = z`. Detect when iterations produce semantically identical outputs.

**Implementation requirements**:

```bash
# NEW: Convergence tracking for feedback loop
declare -a ITERATION_OUTPUTS
CONVERGENCE_THRESHOLD=95  # % similarity to declare convergence

# Semantic similarity (hash-based approximation)
compute_similarity() {
    local output_a="$1"
    local output_b="$2"
    
    # Normalize and hash chunks
    local chunks_a=$(echo "$output_a" | fold -w 100 | md5sum | cut -d' ' -f1)
    local chunks_b=$(echo "$output_b" | fold -w 100 | md5sum | cut -d' ' -f1)
    
    # Simple: exact match = 100, else estimate via shared lines
    if [[ "$chunks_a" == "$chunks_b" ]]; then
        echo 100
    else
        local shared=$(comm -12 <(echo "$output_a" | sort -u) <(echo "$output_b" | sort -u) | wc -l)
        local total=$(echo "$output_a" | sort -u | wc -l)
        echo $((shared * 100 / (total + 1)))
    fi
}

# Floyd's tortoise-and-hare cycle detection (adapted)
detect_iteration_cycle() {
    local current_output="$1"
    local window_size=3
    
    ITERATION_OUTPUTS+=("$current_output")
    local len=${#ITERATION_OUTPUTS[@]}
    
    if [[ $len -lt 2 ]]; then
        echo "CONTINUE"
        return
    fi
    
    # Check against recent outputs for convergence
    for ((i = len - 2; i >= 0 && i >= len - window_size; i--)); do
        local similarity=$(compute_similarity "$current_output" "${ITERATION_OUTPUTS[$i]}")
        if [[ $similarity -ge $CONVERGENCE_THRESHOLD ]]; then
            echo "CONVERGED:iteration_$i"
            return
        fi
    done
    
    # Check for oscillation (A → B → A pattern)
    if [[ $len -ge 3 ]]; then
        local sim_to_two_back=$(compute_similarity "$current_output" "${ITERATION_OUTPUTS[$((len-3))]}")
        if [[ $sim_to_two_back -ge $CONVERGENCE_THRESHOLD ]]; then
            echo "OSCILLATING"
            return
        fi
    fi
    
    echo "CONTINUE"
}
```

### 4. Bounded Region Detection (Scope Connectivity)

**Mathematical basis**: Julia sets partition space into connected (bounded) and disconnected regions. Connected scopes need coordination; disconnected scopes can parallelize freely.

**Implementation requirements**:

```bash
# NEW: Scope connectivity analysis
analyze_scope_connectivity() {
    local agent_scopes="$1"  # newline-separated "agent:scope" pairs
    
    declare -A scope_files
    declare -A scope_dirs
    
    # Parse scopes into file/directory sets
    while IFS=: read -r agent scope; do
        scope_files[$agent]=$(echo "$scope" | tr ',' '\n' | grep -E '\.[a-z]+$' | sort -u)
        scope_dirs[$agent]=$(echo "$scope" | tr ',' '\n' | grep -vE '\.[a-z]+$' | sed 's|/$||' | sort -u)
    done <<< "$agent_scopes"
    
    # Build connectivity graph
    local connections=""
    for agent_a in "${!scope_dirs[@]}"; do
        for agent_b in "${!scope_dirs[@]}"; do
            [[ "$agent_a" == "$agent_b" ]] && continue
            
            # Check directory overlap
            local shared_dirs=$(comm -12 \
                <(echo "${scope_dirs[$agent_a]}") \
                <(echo "${scope_dirs[$agent_b]}"))
            
            if [[ -n "$shared_dirs" ]]; then
                connections+="$agent_a<->$agent_b:$shared_dirs\n"
            fi
        done
    done
    
    if [[ -z "$connections" ]]; then
        echo "DISCONNECTED"  # Full parallelization safe
    else
        echo "CONNECTED"
        echo -e "$connections"
    fi
}
```

### 5. Supervision Tree with Restart Limits

**Mathematical basis**: Mandelbrot's max_iteration prevents infinite loops. Apply same principle to restart attempts.

**Implementation requirements**:

```bash
# NEW: Supervision parameters
MAX_RESTARTS_PER_AGENT=3
RESTART_WINDOW_SECONDS=300
declare -A AGENT_RESTART_HISTORY

# Supervision strategy enum
# ONE_FOR_ONE: restart only failed agent
# ONE_FOR_ALL: restart all sibling agents  
# ESCALATE: pass to parent orchestrator
SUPERVISION_STRATEGY="ONE_FOR_ONE"

get_restart_count() {
    local agent_id="$1"
    local window_start=$(($(date +%s) - RESTART_WINDOW_SECONDS))
    local history="${AGENT_RESTART_HISTORY[$agent_id]:-}"
    
    # Count restarts within window
    local count=0
    for timestamp in $history; do
        if [[ $timestamp -ge $window_start ]]; then
            ((count++))
        fi
    done
    echo $count
}

record_restart() {
    local agent_id="$1"
    local now=$(date +%s)
    AGENT_RESTART_HISTORY[$agent_id]+=" $now"
}

handle_agent_failure() {
    local agent_id="$1"
    local failure_type="$2"  # TIMEOUT | DIVERGENCE | ERROR | FATAL
    local restart_count=$(get_restart_count "$agent_id")
    
    trace "agent_failure" "$agent_id" \
        "$(jq -nc --arg type "$failure_type" --arg restarts "$restart_count" \
        '{failure_type: $type, restart_count: $restarts}')"
    
    # Max restarts exceeded = escalate (like exceeding max_iteration)
    if [[ $restart_count -ge $MAX_RESTARTS_PER_AGENT ]]; then
        log "ERROR" "Agent $agent_id: max restarts ($MAX_RESTARTS_PER_AGENT) exceeded, escalating"
        emit_signal "ESCALATE" "$agent_id" "max_restarts_exceeded"
        return 1
    fi
    
    case "$failure_type" in
        "TIMEOUT")
            # May converge on retry with fresh context
            record_restart "$agent_id"
            echo "RESTART"
            ;;
        "DIVERGENCE")
            # Retry with perturbation (different prompt seed)
            record_restart "$agent_id"
            echo "RESTART_WITH_PERTURBATION"
            ;;
        "ERROR")
            # Transient error, simple retry
            record_restart "$agent_id"
            echo "RESTART"
            ;;
        "FATAL")
            # Cannot recover at this level
            echo "ESCALATE"
            ;;
        *)
            echo "ESCALATE"
            ;;
    esac
}
```

---

## REFACTORING INSTRUCTIONS

### Phase 1: Add Mandelbrot State Infrastructure

1. **Add new global variables** after `RETRY_BASE_DELAY=...` (in the global variables section near the top):
   - Escape-time parameters: `DIVERGENCE_THRESHOLD`, `CONVERGENCE_EPSILON`, `ESCAPE_RADIUS`
   - Fractal parameters: `FRACTAL_DEPTH`, `FRACTAL_MAX_DEPTH`
   - Associative arrays: `AGENT_METRICS`, `AGENT_RESTART_HISTORY`, `ITERATION_OUTPUTS`

2. **Add new functions** after `generate_agent_id()` function:
   - `check_agent_trajectory()` - escape-time detection
   - `measure_task_complexity()` - fractal decomposition decision
   - `should_decompose()` - atomic vs recursive decision
   - `compute_similarity()` - convergence detection
   - `detect_iteration_cycle()` - feedback loop termination
   - `analyze_scope_connectivity()` - parallel safety analysis
   - `handle_agent_failure()` - supervision with restart limits

### Phase 2: Modify `run_agent()` Function

**Location**: Search for `^run_agent()` or the comment `# PHASE 1: READ`

Replace the simple timeout-based execution with escape-time supervision:

1. **In PHASE 1 (READ)**: Add initial metric collection
2. **In PHASE 2 (TRANSFORM)**: 
   - Wrap execution in an iteration loop with `check_agent_trajectory()`
   - Add divergence detection that can abort early
   - Replace fixed timeout with trajectory-based termination
3. **In PHASE 3 (EMIT)**: 
   - Use `handle_agent_failure()` for failures instead of simple error logging
   - Emit richer signals including trajectory classification

### Phase 3: Modify `phase_discovery()` Function

**Location**: Search for `^phase_discovery()` or `=== PHASE 1: DISCOVERY ===`

Add fractal decomposition intelligence:

1. After receiving discovery output, call `measure_task_complexity()`
2. Use `should_decompose()` to decide split vs direct
3. If decomposing, call `analyze_scope_connectivity()` to determine parallel safety
4. Pass `FRACTAL_DEPTH` to spawned sub-agents

### Phase 4: Modify `phase_spawn()` Function

**Location**: Search for `^phase_spawn()` or `=== PHASE 2: SPAWNING SUB-AGENTS ===`

Add scope connectivity analysis:

1. Before spawning agents, extract all scopes and run `analyze_scope_connectivity()`
2. If `DISCONNECTED`: spawn all agents in parallel (current behavior)
3. If `CONNECTED`: identify connected components and serialize within components

### Phase 5: Modify `feedback_loop()` Function

**Location**: Search for `^feedback_loop()` or `ITERATION $iteration COMPLETE`

Add convergence detection:

1. After each iteration, call `detect_iteration_cycle()`
2. If `CONVERGED`: offer to terminate with success summary
3. If `OSCILLATING`: detect and offer perturbation or termination
4. Track iteration quality trajectory and warn if diverging

### Phase 6: Update Signal Types

Add new signal types to support Mandelbrot patterns (update `emit_signal()` documentation):

```bash
# Existing signals: READY, BLOCKED, FAILED, DATA

# NEW signals:
# ESCAPING:<agent>       - Agent detected as diverging
# CONVERGED:<agent>      - Agent reached fixed point
# OSCILLATING:<agent>    - Agent cycling between states
# ESCALATE:<agent>       - Failure passed to parent
# DECOMPOSED:<agent>     - Task split into sub-agents
```

---

## OUTPUT REQUIREMENTS

Produce a complete refactored script that:

1. **Maintains backward compatibility** - existing command-line interface unchanged
2. **Adds new CLI options** (update `print_usage()` and argument parsing):
   - `--fractal-depth N` - set max recursion depth (default: 3)
   - `--escape-threshold N` - divergence score limit (default: 100)
   - `--convergence-threshold N` - similarity % for convergence (default: 95)
3. **Preserves all existing functionality** - checkpointing, resume, validate, status
4. **Adds rich trajectory logging** - include Mandelbrot metrics in trace.jsonl
5. **Includes inline documentation** explaining the mathematical basis for each new function

## VERIFICATION CHECKLIST

After refactoring, verify:

- [ ] `co "simple task"` works identically to before
- [ ] `co -x "complex task"` spawns agents with connectivity analysis
- [ ] Agents that stagnate are detected and aborted before timeout
- [ ] Feedback loop detects convergence and offers termination
- [ ] Deeply nested tasks trigger fractal decomposition
- [ ] Restart limits prevent infinite retry loops
- [ ] All new parameters have sensible defaults
- [ ] Trace output includes trajectory metrics
- [ ] Checkpoints include Mandelbrot state for recovery

---

## FUNCTION LOCATION QUICK REFERENCE

To find current locations in your script version:

```bash
# Global variables section
grep -n "^TIMEOUT=\|^MAX_RETRIES=\|^RETRY_BASE_DELAY=" orchestrate

# Key functions to modify
grep -n "^run_agent()\|^phase_discovery()\|^phase_spawn()\|^feedback_loop()" orchestrate

# Helper functions (add new ones after these)
grep -n "^generate_agent_id()\|^generate_correlation_id()" orchestrate

# Signal handling
grep -n "^emit_signal()\|^wait_for_signal()" orchestrate

# CLI parsing
grep -n "^print_usage()\|while \[\[ \$# -gt 0 \]\]" orchestrate
```

---

## MATHEMATICAL REFERENCE

For implementer reference, the key Mandelbrot formulas being adapted:

| Mandelbrot Concept | Formula | Orchestration Analog |
|-------------------|---------|---------------------|
| Escape condition | \|z\|² > 4 | divergence_score > threshold |
| Iteration count | n where \|zₙ\| > 2 | iterations until escape/converge |
| Smooth iteration | n + 1 - log(log\|z\|)/log(2) | weighted divergence score |
| Fixed point | f(z) = z | output_n ≈ output_{n-1} |
| Period detection | f^p(z) = z | output_n ≈ output_{n-p} |
| Julia connectivity | c ∈ M ⟺ Jc connected | shared_context ⟺ needs_coordination |
| Bailout radius | R = max(2, \|c\|) | threshold scales with complexity |

---

## EXISTING SCRIPT REFERENCE

The script to refactor should be provided alongside this prompt. Key sections to locate:

| Section | How to Find |
|---------|-------------|
| Global variables | Top of file, after `set -euo pipefail` |
| ID generation helpers | Search for `generate_correlation_id()` and `generate_agent_id()` |
| Signal handling | Search for `emit_signal()`, `wait_for_signal()` |
| Retry logic | Search for `execute_with_retry()` |
| Agent execution | Search for `run_agent()` — contains READ/TRANSFORM/EMIT phases |
| Discovery phase | Search for `phase_discovery()` |
| Spawn phase | Search for `phase_spawn()` |
| Feedback loop | Search for `feedback_loop()` |
| CLI parsing | Search for `print_usage()` and `while [[ $# -gt 0 ]]` |
