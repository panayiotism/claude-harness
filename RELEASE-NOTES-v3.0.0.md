# Release Notes: v3.0.0 - Memory Architecture

**Release Date**: January 2026
**Codename**: Memory Architecture Release

---

## Overview

Major release transforming claude-harness into an intelligent, learning agent harness with a 4-layer memory architecture. The agent now remembers what works, avoids past mistakes, and builds context that's always fresh and relevant.

### Inspiration

This release combines the best patterns from three pioneering projects:

| Project | What We Borrowed |
|---------|------------------|
| [Context-Engine](https://github.com/zeddy89/Context-Engine) | 4-layer memory architecture, computed context |
| [Agent-Foreman](https://github.com/mylukin/agent-foreman) | Granular status states, impact analysis |
| [Autonomous-Coding](https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding) | Test-driven features, two-phase pattern |

---

## Architecture

### Memory System Overview

```mermaid
flowchart TB
    subgraph Session["Each Session"]
        START["/start"] --> COMPILE["Compile Working Context"]
    end

    subgraph Memory["4-Layer Memory"]
        W["Working Memory<br/><i>Rebuilt fresh each session</i>"]
        E["Episodic Memory<br/><i>Rolling 50 decisions</i>"]
        S["Semantic Memory<br/><i>Project architecture</i>"]
        P["Procedural Memory<br/><i>Success/failure patterns</i>"]
    end

    COMPILE --> W
    E --> W
    S --> W
    P --> W

    subgraph Actions["During Work"]
        IMPL["/implement"] --> |"On failure"| P
        IMPL --> |"On success"| P
        CHECK["/checkpoint"] --> E
        CHECK --> S
    end

    style W fill:#e1f5fe
    style E fill:#fff3e0
    style S fill:#e8f5e9
    style P fill:#fce4ec
```

### Memory Layer Details

```mermaid
graph LR
    subgraph Working["Working Memory"]
        W1["Computed at session start"]
        W2["Contains only relevant context"]
        W3["Never accumulates stale data"]
    end

    subgraph Episodic["Episodic Memory"]
        E1["Last 50 decisions"]
        E2["With rationale"]
        E3["Tagged by feature/domain"]
    end

    subgraph Semantic["Semantic Memory"]
        S1["Project structure"]
        S2["Tech stack"]
        S3["Naming patterns"]
    end

    subgraph Procedural["Procedural Memory"]
        P1["Failures: what NOT to do"]
        P2["Successes: what works"]
        P3["Patterns: learned rules"]
    end

    style Working fill:#e1f5fe
    style Episodic fill:#fff3e0
    style Semantic fill:#e8f5e9
    style Procedural fill:#fce4ec
```

---

## Failure Prevention System

The harness now learns from mistakes and prevents repeating them.

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Impl as /implement
    participant Proc as Procedural Memory
    participant Code as Codebase

    Dev->>Impl: Start implementation
    Impl->>Proc: Query similar past approaches

    alt Similar failure found
        Proc-->>Impl: Warning + root cause
        Impl-->>Dev: "Similar approach failed before"
        Impl->>Proc: Get successful alternatives
        Proc-->>Impl: Alternative approaches
        Impl-->>Dev: Suggest alternatives
    else No match
        Impl->>Code: Proceed with implementation

        alt Implementation fails
            Code-->>Impl: Error
            Impl->>Proc: Record failure + root cause
            Impl->>Code: Try different approach
        else Implementation succeeds
            Code-->>Impl: Success
            Impl->>Proc: Record successful approach
        end
    end
```

### What Gets Recorded

**On Failure:**
```json
{
  "approach": "Used localStorage for JWT tokens",
  "files": ["src/auth/token.ts"],
  "error": "Tokens exposed to XSS attacks",
  "rootCause": "localStorage accessible from any script",
  "prevention": "Use httpOnly cookies instead"
}
```

**On Success:**
```json
{
  "approach": "Used httpOnly cookies for JWT tokens",
  "files": ["src/auth/token.ts", "src/api/middleware.ts"],
  "rationale": "Secure, not accessible from JavaScript",
  "reusableFor": ["authentication", "session management"]
}
```

---

## Test-Driven Features

Features now generate tests BEFORE implementation.

```mermaid
flowchart LR
    A["/feature"] --> B["/generate-tests"]
    B --> C["Tests exist<br/>(failing)"]
    C --> D["/plan-feature"]
    D --> E["/implement"]
    E --> F{"Tests pass?"}
    F -->|No| G["Record failure"]
    G --> E
    F -->|Yes| H["Record success"]
    H --> I["/checkpoint"]

    style B fill:#fff3e0
    style C fill:#ffcdd2
    style F fill:#e8f5e9
    style H fill:#c8e6c9
```

### Benefits

1. **Clear acceptance criteria** - Tests define "done"
2. **No false completions** - Can't mark done if tests fail
3. **Regression prevention** - Tests catch future breaks
4. **Documentation** - Tests show intended behavior

---

## Two-Phase Pattern

Separate planning from implementation for better outcomes.

```mermaid
flowchart TB
    subgraph Phase1["Phase 1: Planning"]
        P1["Analyze requirements"]
        P2["Check past failures"]
        P3["Analyze impact"]
        P4["Generate tests"]
        P5["Create implementation plan"]

        P1 --> P2 --> P3 --> P4 --> P5
    end

    subgraph Phase2["Phase 2: Implementation"]
        I1["Execute plan"]
        I2["Run verification"]
        I3{"All pass?"}
        I4["Record & retry"]
        I5["Record success"]

        I1 --> I2 --> I3
        I3 -->|No| I4 --> I1
        I3 -->|Yes| I5
    end

    Phase1 --> Phase2

    style Phase1 fill:#e3f2fd
    style Phase2 fill:#e8f5e9
```

### Commands

| Phase | Command | Purpose |
|-------|---------|---------|
| 1 | `/plan-feature` | Analyze, check failures, create plan |
| 2 | `/implement` | Execute with verification loop |

---

## Impact Analysis

Track file dependencies to prevent breaking changes.

```mermaid
graph TD
    subgraph Changed["File Being Changed"]
        A["src/auth/login.ts"]
    end

    subgraph Direct["Direct Dependents"]
        B["src/pages/login.tsx"]
        C["src/api/auth.ts"]
    end

    subgraph Indirect["Indirect Dependents"]
        D["src/pages/dashboard.tsx"]
        E["src/middleware/auth.ts"]
    end

    subgraph Tests["Related Tests"]
        T1["tests/auth/login.test.ts"]
        T2["tests/api/auth.test.ts"]
    end

    A --> B
    A --> C
    B --> D
    C --> E
    A -.-> T1
    C -.-> T2

    style A fill:#ffcdd2
    style Direct fill:#fff3e0
    style Tests fill:#e8f5e9
```

### Impact Scoring

| Score | Dependents | Action |
|-------|------------|--------|
| Low | 0-2 | Proceed normally |
| Medium | 3-5 | Run related tests |
| High | 6+ | Full test suite, careful review |

---

## New Commands

### `/claude-harness:generate-tests`

Generate test cases BEFORE implementation.

```
/claude-harness:generate-tests feature-001
```

**Output:**
- Test specification in `.claude-harness/features/tests/feature-001.json`
- Actual test files in project's test directory
- Tests initially FAIL (expected - no implementation yet)

### `/claude-harness:plan-feature`

Plan implementation with full context.

```
/claude-harness:plan-feature feature-001
```

**Checks:**
- Past failures for similar approaches
- Impact analysis for files to modify
- Dependencies on other features
- Test coverage requirements

### `/claude-harness:check-approach`

Validate an approach before implementing.

```
/claude-harness:check-approach "Store user session in Redis"
```

**Returns:**
- Similar past failures (if any)
- Successful alternatives
- Recommendation to proceed or reconsider

---

## New Directory Structure

```
.claude-harness/
├── memory/
│   ├── working/
│   │   └── context.json          # Rebuilt each session
│   ├── episodic/
│   │   └── decisions.json        # Rolling 50 decisions
│   ├── semantic/
│   │   ├── architecture.json     # Project structure
│   │   ├── entities.json         # Key components
│   │   └── constraints.json      # Project rules
│   └── procedural/
│       ├── failures.json         # What NOT to do
│       ├── successes.json        # What works
│       └── patterns.json         # Learned patterns
├── features/
│   ├── active.json               # Current features
│   └── tests/
│       └── {feature-id}.json     # Test specifications
├── impact/
│   └── dependency-graph.json     # File relationships
├── agents/
│   └── context.json              # Orchestration state
├── loops/
│   └── state.json                # Agentic loop state
├── feature-list.json             # (v2.x backward compat)
├── feature-archive.json          # Completed features
└── claude-progress.json          # Session continuity
```

---

## Complete Workflow

```mermaid
flowchart TD
    START["Session Start"] --> COMPILE["Compile Working Context"]
    COMPILE --> STATUS["Show Status"]

    STATUS --> FEATURE["Add Feature<br/>/feature"]
    FEATURE --> TESTS["Generate Tests<br/>/generate-tests"]
    TESTS --> PLAN["Plan Implementation<br/>/plan-feature"]

    PLAN --> CHECK{"Check Approach?"}
    CHECK -->|Optional| VALIDATE["Validate<br/>/check-approach"]
    VALIDATE --> IMPL
    CHECK -->|Skip| IMPL

    IMPL["Implement<br/>/implement"]
    IMPL --> VERIFY{"Verification"}

    VERIFY -->|Fail| RECORD_FAIL["Record Failure"]
    RECORD_FAIL --> IMPL

    VERIFY -->|Pass| RECORD_SUCCESS["Record Success"]
    RECORD_SUCCESS --> CHECKPOINT["Checkpoint<br/>/checkpoint"]

    CHECKPOINT --> MORE{"More Features?"}
    MORE -->|Yes| FEATURE
    MORE -->|No| MERGE["Merge All<br/>/merge-all"]

    style TESTS fill:#fff3e0
    style PLAN fill:#e3f2fd
    style IMPL fill:#e8f5e9
    style RECORD_FAIL fill:#ffcdd2
    style RECORD_SUCCESS fill:#c8e6c9
```

---

## Migration from v2.x

### Automatic Migration

Run `/claude-harness:setup` in your project. It automatically:

1. Detects v2.x structure (no `memory/` directory)
2. Creates new directory structure
3. Migrates existing files:
   - `agent-memory.json` → `memory/procedural/`
   - `working-context.json` → `memory/working/context.json`
   - `agent-context.json` → `agents/context.json`
   - `loop-state.json` → `loops/state.json`
4. Preserves backward-compatible files:
   - `feature-list.json` (still works)
   - `feature-archive.json`
   - `claude-progress.json`
5. Creates `.migrated-from-v2` marker

### What Stays the Same

- All existing commands work unchanged
- Feature tracking format compatible
- GitHub integration unchanged
- Agentic loops work as before

### What's New

- Memory persists across sessions
- Failures prevent repeat mistakes
- Tests generated before coding
- Impact analysis warns of breaking changes

---

## Breaking Changes

**None.**

v2.x projects are automatically migrated with full backward compatibility.

---

## Upgrade Instructions

```bash
# 1. Pull latest plugin version
cd ~/.claude/plugins/claude-harness
git pull origin main

# 2. In your project
cd your-project
claude

# 3. Run setup (auto-detects and migrates)
/claude-harness:setup

# 4. Start using new features
/claude-harness:start
```

---

## Credits

- **Context-Engine** by [@zeddy89](https://github.com/zeddy89) - Memory architecture concept
- **Agent-Foreman** by [@mylukin](https://github.com/mylukin) - Impact analysis patterns
- **Autonomous-Coding** by [Anthropic](https://github.com/anthropics) - Test-driven approach
- **Anthropic Engineering** - [Effective Harnesses article](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

---

## What's Next

Future releases may include:
- Automatic dependency graph generation
- Cross-project memory sharing
- Performance metrics and optimization suggestions
- Integration with external test runners
