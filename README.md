# Claude Code Long-Running Agent Harness

A Claude Code plugin for automated, context-preserving coding sessions with **5-layer memory architecture**, failure prevention, test-driven features, GitHub integration, **git worktree support for parallel development**, and multi-agent orchestration.

Based on [Anthropic's engineering article](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) and enhanced with patterns from:
- [Context-Engine](https://github.com/zeddy89/Context-Engine) - Memory architecture
- [Agent-Foreman](https://github.com/mylukin/agent-foreman) - Task management patterns
- [Autonomous-Coding](https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding) - Test-driven approach

## TL;DR - End-to-End Workflow

### Quick Start (Unified Command)

```bash
# Setup once
claude plugin install claude-harness github:panayiotism/claude-harness
cd your-project && claude
/claude-harness:setup

# NEW in v4.5: Single command for entire workflow (start → do → checkpoint → merge)
/claude-harness:flow "Add user authentication with JWT tokens"
# Auto-compiles context, creates issue/branch, implements, checkpoints, merges

# Or step-by-step with /do (creates worktree by default)
/claude-harness:do "Add user authentication with JWT tokens"
# Creates worktree at ../your-project-feature-XXX/ (isolated working directory)
# Then gives you instructions to continue in the new worktree
```

The **`/flow`** command (v4.5) handles the entire lifecycle automatically - from context compilation to PR merge. Use `--autonomous` (v5.1) to batch-process all active features with TDD enforcement. The `/do` command chains creation through checkpoint with interactive prompts. Both support worktrees for parallel development. Use `--inline` to skip worktree creation for quick fixes, `--quick` to skip planning for simple tasks, or `--auto` for full automation.

### Complete Workflow (10 Commands Total)

```bash
# 1. SETUP (one-time)
/claude-harness:setup                              # Initialize harness in project

# 2. START SESSION (or skip with /flow)
/claude-harness:start                              # Compile context, show status

# 2b. AUTOMATED END-TO-END (NEW in v4.5, autonomous in v5.1)
/claude-harness:flow "Add dark mode"               # Complete lifecycle in one command
/claude-harness:flow --no-merge "Add feature"      # Stop at checkpoint (don't auto-merge)
/claude-harness:flow --autonomous                   # NEW: Batch-process all features with TDD

# 2b. PRD BOOTSTRAP (for new projects)
/claude-harness:prd-breakdown "Your PRD..."                           # Analyze inline PRD → extract atomic features
/claude-harness:prd-breakdown @./docs/prd.md                         # Read PRD from file (@ syntax)
/claude-harness:prd-breakdown --file ./docs/prd.md                   # Read PRD from file (--flag syntax)
/claude-harness:prd-breakdown --url https://github.com/.../issues/42 # Fetch from GitHub
/claude-harness:prd-breakdown @./prd.md --create-issues --auto       # Full automation: create features + GitHub issues

# 3. DEVELOPMENT - Features and Fixes (auto-creates worktree by default)
/claude-harness:do "Add authentication"  # New feature + worktree (default)
/claude-harness:do --inline "Quick fix"  # Skip worktree, work in current dir
/claude-harness:do --fix feature-001 "Token bug"  # Bug fix linked to feature
/claude-harness:do feature-001           # Resume existing feature/fix

# 3b. TDD DEVELOPMENT - Test-Driven (tests first)
/claude-harness:do-tdd "Add authentication"  # TDD: write tests BEFORE code

# 4. MANUAL CHECKPOINT (optional - /do includes checkpoint)
/claude-harness:checkpoint               # Commit, push, create PR

# 5. WORKTREE MANAGEMENT
/claude-harness:worktree list            # Show all worktrees
/claude-harness:worktree remove feature-001  # Clean up after merge

# 6. ADVANCED - Multi-agent (for complex features)
/claude-harness:orchestrate feature-001  # Spawn specialized agent team

# 7. RELEASE
/claude-harness:merge                    # Merge all PRs, close issues
```

### What Happens Behind the Scenes

```
/setup           → One-time: Creates .claude-harness/ with memory architecture

/start           → Compiles working context from 4 memory layers
                   Shows status, syncs GitHub, displays learned rules

/flow            → END-TO-END WORKFLOW (NEW in v4.5):
                   1. Auto-compiles context (replaces /start)
                   2. Creates feature (GitHub issue + branch)
                   3. Plans implementation (checks past failures)
                   4. Agentic loop until verification passes
                   5. Auto-checkpoints when tests pass
                   6. Auto-merges when PR approved
                   Options: --no-merge, --quick, --inline, --autonomous
                   --autonomous: Batch loop through ALL features with TDD (v5.1)
                   OPTIMIZATIONS: Parallel memory reads, cached GitHub parsing

/do              → UNIFIED WORKFLOW (handles features AND fixes):
                   1. Creates feature/fix (GitHub issue + branch)
                   2. Creates worktree at ../project-feature-XXX/ (default)
                   3. Pauses with instructions to enter worktree
                   4. (In worktree) Plans implementation (checks past failures)
                   5. Agentic loop until verification passes
                   6. Auto-reflects on user corrections
                   7. Commits, pushes, creates PR
                   Options: --inline (skip worktree), --quick (skip planning)
                   Resume: /do feature-001 or /do resume

/worktree        → WORKTREE MANAGEMENT:
                   list - Show all worktrees and their status
                   create - Create worktree for existing feature
                   remove - Clean up worktree after merge
                   prune - Clean up stale worktree references

/do-tdd          → TDD WORKFLOW (tests first):
                   1. Creates feature/fix (same as /do)
                   2. Plans with TEST SPECS first
                   3. RED: Write failing tests (blocks until tests exist)
                   4. GREEN: Write minimal code to pass
                   5. REFACTOR: Improve while keeping tests green
                   6. Commits with [TDD] tag, creates PR

/checkpoint      → Manual commit + push + PR (when not using /do)
                   Auto-reflects on user corrections

/orchestrate     → Spawns specialized agent team for complex features

/merge           → Merges PRs in dependency order
                   Closes linked issues
                   Cleans up branches
```

### v3.0 Memory Architecture

```
.claude-harness/
├── memory/
│   ├── episodic/    → Rolling window of 50 recent decisions
│   ├── semantic/    → Persistent project architecture & patterns
│   ├── procedural/  → Append-only success/failure logs (never repeat mistakes)
│   └── learned/     → Rules from user corrections (self-improving)
├── features/        → Shared feature registry (active.json, archive.json)
├── worktrees/       → Worktree registry for parallel development
│   └── registry.json→ Tracks all active worktrees
└── sessions/        → Per-session state (gitignored, enables parallel work)
    └── {uuid}/      → Each Claude instance gets isolated loop/context state
```

### Git Worktree Support (v3.9+) & PRD Analysis (v4.0)

True parallel development: each feature gets its own isolated working directory.

```
~/dev/project/                    # Main repo (shared state)
~/dev/project-feature-014/        # Worktree for feature-014
~/dev/project-feature-015/        # Worktree for feature-015
```

**Why worktrees?**
- Multiple Claude instances can work on different features simultaneously
- No branch checkout conflicts (each worktree has its own branch)
- Shared .git database (space-efficient, no sync issues)
- Industry standard (used by incident.io, Cursor, etc.)

**Workflow:**
```bash
# In main repo: create feature (auto-creates worktree)
/claude-harness:do "Add authentication"
# → Creates worktree at ../project-feature-XXX/
# → Displays instructions to enter worktree

# Open new terminal, enter worktree
cd ../project-feature-XXX
claude
/claude-harness:do feature-XXX   # Resume implementation

# After merge, clean up
cd ../project
/claude-harness:worktree remove feature-XXX
```

### Session Cleanup (Automatic)

Session directories are automatically cleaned up when Claude exits. The `SessionEnd` hook detects inactive sessions by checking their PID:

- **Active sessions** (PID still running) are preserved
- **Inactive sessions** (PID no longer running) are deleted
- **Current session** is never deleted during its own exit

This ensures parallel Claude instances don't interfere with each other while preventing disk bloat from accumulated sessions.

## Session Start Hook

When you start Claude Code in a harness-enabled project:

```
┌─────────────────────────────────────────────────────────────────┐
│                  CLAUDE HARNESS v5.1.1 (Opus 4.6 Optimized)      │
├─────────────────────────────────────────────────────────────────┤
│  P:2 WIP:1 Tests:1 Fixes:1 | Active: feature-001                │
│  Memory: 12 decisions | 3 failures | 8 successes                │
│  GitHub: owner/repo (cached)                                    │
├─────────────────────────────────────────────────────────────────┤
│  /claude-harness:setup          Initialize harness (one-time)   │
│  /claude-harness:start          Compile context + GitHub sync   │
│  /claude-harness:flow           End-to-end (start→do→merge)     │
│  /claude-harness:prd-breakdown  Analyze PRD → extract features  │
│  /claude-harness:do             Unified workflow (auto-worktree)│
│  /claude-harness:do-tdd         TDD workflow (tests first)      │
│  /claude-harness:checkpoint     Commit + persist memory         │
│  /claude-harness:worktree       Manage worktrees (list/remove)  │
│  /claude-harness:orchestrate    Spawn multi-agent team          │
│  /claude-harness:merge          Merge PRs + close issues        │
└─────────────────────────────────────────────────────────────────┘
```

When in a worktree:
```
┌─────────────────────────────────────────────────────────────────┐
│  🌳 WORKTREE MODE                                               │
├─────────────────────────────────────────────────────────────────┤
│  Branch: feature/feature-014                                    │
│  Main repo: ../project/                                         │
│  Shared state: features, memory (from main repo)                │
│  Local state: sessions (this worktree)                          │
└─────────────────────────────────────────────────────────────────┘
```

Shows:
- **Feature status**: P (Pending) / WIP (Work-in-progress) / Tests (Needs tests)
- **Memory stats**: Decisions recorded, failures to avoid, successes to reuse
- **Failure prevention**: If failures exist, warns before implementing
- **Worktree mode**: If running in worktree, shows main repo location

## v3.0 Memory Architecture

### Four Layers

```
.claude-harness/memory/
├── working/context.json      # Rebuilt each session (computed)
├── episodic/decisions.json   # Rolling window of recent decisions
├── semantic/                 # Persistent project knowledge
│   ├── architecture.json
│   ├── entities.json
│   └── constraints.json
└── procedural/               # Success/failure patterns (append-only)
    ├── failures.json
    ├── successes.json
    └── patterns.json
```

| Layer | Purpose | Lifecycle |
|-------|---------|-----------|
| **Working** | Current task only | Rebuilt each session |
| **Episodic** | Recent decisions, context | Rolling window (50 max) |
| **Semantic** | Project architecture, patterns | Persistent |
| **Procedural** | What worked, what failed | Append-only |

### Context Compilation

Each session compiles **fresh working context** by pulling relevant information from memory layers:

```
/claude-harness:start

→ Compile working context:
  • Pull recent decisions from episodic (last 10 relevant)
  • Pull project patterns from semantic
  • Pull failures to avoid from procedural
  • Pull successful approaches from procedural

→ Result: Clean, relevant context without accumulation
```

## Failure Prevention System

Never repeat the same mistakes. When you try an approach that fails, it's recorded:

```json
// .claude-harness/memory/procedural/failures.json
{
  "entries": [
    {
      "id": "uuid",
      "timestamp": "2025-01-20T10:30:00Z",
      "feature": "feature-001",
      "approach": "Used direct DOM manipulation for state",
      "files": ["src/components/Auth.tsx"],
      "errors": ["React hydration mismatch"],
      "rootCause": "SSR incompatibility with direct DOM access",
      "prevention": "Use useState and useEffect instead"
    }
  ]
}
```

Before each implementation attempt, `/do` automatically checks past failures:

```
/claude-harness:do feature-002

⚠️  SIMILAR APPROACH FAILED BEFORE

Failure: Used direct DOM manipulation for state
When: 2025-01-20
Files: src/components/Auth.tsx
Error: React hydration mismatch
Root Cause: SSR incompatibility with direct DOM access

Prevention Tip: Use useState and useEffect instead

✅ SUCCESSFUL ALTERNATIVE
Approach: React hooks with conditional rendering
Files: src/components/User.tsx
Why it worked: Proper SSR hydration
```

## Test-Driven Features

The `/do` command can generate tests **before** implementation during planning:

```
/claude-harness:do "Add user authentication"

→ Creates feature entry with status: "pending"
→ Creates GitHub issue (if MCP configured)
→ Creates feature branch
→ Plans implementation (generates tests if needed)
→ Implements until all verification passes
```

### Test Cases Schema

```json
// .claude-harness/features/tests/feature-001.json
{
  "featureId": "feature-001",
  "generatedAt": "2025-01-20T10:30:00Z",
  "framework": "jest",
  "cases": [
    {
      "id": "test-001",
      "type": "unit",
      "description": "Should authenticate user with valid credentials",
      "file": "tests/auth/login.test.ts",
      "status": "pending",
      "code": "test('authenticates with valid credentials', async () => {...})"
    }
  ],
  "coverage": {
    "target": 80,
    "current": 0
  }
}
```

## Two-Phase Pattern

The `/do` command separates planning from implementation internally:

### Phase 1: Plan (automatic in /do)

```
/claude-harness:do "Add authentication"

→ Planning Phase:
  → Analyzes requirements
  → Identifies files to create/modify
  → Runs impact analysis
  → Checks failure patterns
  → Generates tests (if needed)
  → Creates implementation plan
```

Output:
```
Implementation Plan for feature-001:

Steps:
1. Create auth service (src/services/auth.ts)
2. Add login API route (src/app/api/auth/login/route.ts)
3. Create login form component (src/components/LoginForm.tsx)
4. Add protected route wrapper (src/components/ProtectedRoute.tsx)

Impact Analysis:
- High: src/app/layout.tsx (15 dependents)
- Medium: src/lib/api.ts (8 dependents)

Failures to Avoid:
- Don't use direct DOM manipulation (failed in feature-003)

Successful Patterns to Use:
- React hooks with conditional rendering
- Server-side session validation
```

### Phase 2: Implement (automatic in /do)

```
→ Implementation Phase:
  → Loads loop state (resume if active)
  → Checks failure patterns before each attempt
  → Verifies tests are generated
  → Implements to pass tests
  → Runs ALL verification commands
  → Records success/failure to procedural memory
```

Use `--quick` to skip planning, or `--plan-only` to stop after planning.

## Commands Reference (10 Total)

| Command | Purpose |
|---------|---------|
| `/claude-harness:setup` | Initialize harness in project (one-time) |
| `/claude-harness:start` | Compile context + GitHub sync + status |
| **`/claude-harness:flow`** | **End-to-end workflow**: start→do→checkpoint→merge in one command (v4.5) |
| **`/claude-harness:prd-breakdown`** | **PRD Analysis**: Decompose PRD into atomic features |
| **`/claude-harness:do`** | **Unified workflow**: features AND fixes (auto-worktree) |
| **`/claude-harness:do-tdd`** | **TDD workflow**: tests first, then implement |
| `/claude-harness:checkpoint` | Manual commit + push + PR |
| `/claude-harness:worktree` | Manage worktrees (list, create, remove, prune) |
| `/claude-harness:orchestrate <id>` | Spawn multi-agent team (advanced) |
| `/claude-harness:merge` | Merge all PRs, close issues |

### `/flow` Command Options (v4.5)

| Syntax | Behavior |
|--------|----------|
| `/flow "Add feature"` | Complete lifecycle: start→do→checkpoint→merge |
| `/flow feature-001` | Resume existing feature from current phase |
| `/flow --no-merge "Add feature"` | Stop at checkpoint (don't auto-merge) |
| `/flow --quick "Simple change"` | Skip planning phase |
| `/flow --inline "Tiny fix"` | Skip worktree, work in current directory |
| `/flow --fix feature-001 "Bug"` | Complete lifecycle for a bug fix |
| `/flow --autonomous` | **Batch loop**: process all active features with TDD, checkpoint, merge, repeat (v5.1) |
| `/flow --autonomous --no-merge` | Batch loop but stop each feature at checkpoint (PRs created, not merged) |

**Key Optimizations in /flow**:
- Memory layers read in parallel (30-40% faster startup)
- GitHub repo parsed once and cached for entire flow
- Streaming memory updates after each verification attempt
- Prompt-based Stop hook detects completion automatically

### `/do` Command Options

| Syntax | Behavior |
|--------|----------|
| `/do "Add feature"` | Full workflow with worktree (default) |
| `/do --inline "Quick fix"` | Skip worktree, work in current directory |
| `/do --fix feature-001 "Bug"` | Create bug fix linked to feature |
| `/do feature-001` | Resume existing feature |
| `/do fix-feature-001-001` | Resume existing fix |
| `/do resume` | Resume last active workflow |
| `/do --quick "Simple change"` | Skip planning phase |
| `/do --auto "Add Y"` | No prompts, full automation |
| `/do --plan-only "Big feature"` | Plan only, implement later |

### `/worktree` Command Options

| Syntax | Behavior |
|--------|----------|
| `/worktree list` | Show all worktrees and their status |
| `/worktree create feature-XXX` | Create worktree for existing feature |
| `/worktree remove feature-XXX` | Remove worktree after merge |
| `/worktree remove feature-XXX --force` | Force remove even with uncommitted changes |
| `/worktree prune` | Clean up stale worktree references |

### `/do-tdd` Command Options

| Syntax | Behavior |
|--------|----------|
| `/do-tdd "Add feature"` | TDD workflow: write tests first |
| `/do-tdd --fix feature-001 "Bug"` | TDD bug fix linked to feature |
| `/do-tdd feature-001` | Resume TDD feature |
| `/do-tdd resume` | Resume last TDD workflow |
| `/do-tdd --quick "Simple"` | Skip planning, **tests still required** |
| `/do-tdd --auto "Add Y"` | No prompts, TDD enforced |
| `/do-tdd --plan-only "Big"` | Plan with test specs only |

**TDD Workflow Phases:**
```
🔴 RED     → Write failing tests (BLOCKS until tests exist)
🟢 GREEN   → Write minimal code to pass tests
🔄 REFACTOR → Improve code while keeping tests green
```

### `/prd-breakdown` Command Options

| Syntax | Behavior |
|--------|----------|
| `/prd-breakdown "Your PRD markdown..."` | Analyze inline PRD |
| `/prd-breakdown @./docs/prd.md` | Read PRD from file (@ syntax - preferred) |
| `/prd-breakdown --file ./docs/prd.md` | Read PRD from file (--flag syntax) |
| `/prd-breakdown --url https://github.com/org/repo/issues/42` | Fetch PRD from GitHub issue |
| `/prd-breakdown --analyze-only` | Run analysis without creating features |
| `/prd-breakdown --auto` | No prompts, create all features |
| `/prd-breakdown --max-features 10` | Limit to 10 highest-priority features |
| `/prd-breakdown @./prd.md --create-issues` | Create GitHub issues for each feature |
| `/prd-breakdown @./prd.md --create-issues --auto` | Full automation: analyze, create features AND GitHub issues |

**PRD Breakdown Workflow:**
```
📄 Input         → Read PRD from inline, file, or GitHub
🔍 Analyze       → 3 parallel subagents analyze requirements
  • Product Analyst: Extracts business goals, requirements, personas
  • Architect: Assesses feasibility, tech stack, dependencies, risks
  • QA Lead: Defines acceptance criteria, test scenarios, verification
🎯 Decompose     → Transform requirements into atomic features
  • Resolve dependencies (topological sort)
  • Assign priorities (MVP first)
  • Generate acceptance criteria
📋 Review        → Preview breakdown, select features to create
✅ Create        → Add features to active.json with PRD metadata
🔗 Issues (opt)  → Create GitHub issues for tracking (--create-issues flag)
```

#### Auto-Creating GitHub Issues from PRD

When using the `--create-issues` flag, the `/prd-breakdown` command will automatically create one GitHub issue per generated feature:

```bash
/prd-breakdown @./prd.md --create-issues              # Manual review then create issues
/prd-breakdown @./prd.md --create-issues --auto       # Fully automated
```

Each issue will:
- Contain the feature description and acceptance criteria
- Be labeled with `feature` and `prd-generated` tags
- Be linked to the feature in `.claude-harness/features/active.json` (stored in `github.issueNumber`)
- Be assigned the PRD breakdown ID for traceability across sessions

This is useful when you want to:
- Create a complete GitHub-tracked backlog from a PRD
- Ensure every generated feature has an issue for team visibility
- Maintain bidirectional links between PRD decomposition and issue tracking

**Note**: Requires GitHub MCP integration to be configured in Claude Code.

## v3.0 Directory Structure

```
.claude-harness/
├── memory/
│   ├── working/
│   │   └── context.json          # Rebuilt each session
│   ├── episodic/
│   │   └── decisions.json        # Rolling window (50 max)
│   ├── semantic/
│   │   ├── architecture.json     # Project structure
│   │   ├── entities.json         # Key components
│   │   └── constraints.json      # Rules & conventions
│   ├── procedural/
│   │   ├── failures.json         # Append-only failure log
│   │   ├── successes.json        # Append-only success log
│   │   └── patterns.json         # Learned patterns
│   └── learned/
│       └── rules.json            # Rules from user corrections
├── impact/
│   ├── dependency-graph.json     # File dependencies
│   └── change-log.json           # Recent changes
├── features/
│   ├── active.json               # Current features
│   ├── archive.json              # Completed features
│   └── tests/
│       └── {feature-id}.json     # Test cases per feature
├── agents/
│   ├── context.json              # Orchestration state
│   └── handoffs.json             # Agent handoff queue
├── worktrees/
│   └── registry.json             # Worktree tracking for parallel dev
├── prd/                          # PRD analysis and decomposition
│   ├── input.md                  # Original PRD document
│   ├── metadata.json             # PRD metadata and hash
│   ├── analysis.json             # Subagent analysis results
│   ├── breakdown.json            # Decomposed features
│   └── subagent-prompts.json     # Reusable subagent prompts
├── loops/
│   └── state.json                # Agentic loop state
├── sessions/                     # Per-session state (gitignored)
│   └── {uuid}/                   # Isolated loop/context per session
├── config.json                   # Plugin configuration
└── claude-progress.json          # Session summary
```

## Feature Schema (v3.0)

```json
{
  "id": "feature-001",
  "name": "User Authentication",
  "description": "Add login/logout with session management",
  "priority": 1,
  "status": "pending|needs_tests|in_progress|passing|failing|blocked|escalated",
  "phase": "planning|test_generation|implementation|verification",
  "tests": {
    "generated": true,
    "file": "features/tests/feature-001.json",
    "passing": 0,
    "total": 15
  },
  "verification": {
    "build": "npm run build",
    "tests": "npm run test",
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit",
    "custom": []
  },
  "attempts": 0,
  "maxAttempts": 15,
  "relatedFiles": [],
  "github": {
    "issueNumber": 42,
    "prNumber": null,
    "branch": "feature/feature-001"
  },
  "createdAt": "2025-01-20T10:30:00Z",
  "updatedAt": "2025-01-20T10:30:00Z"
}
```

## Fix Schema (v3.1)

Bug fixes are linked to their original features:

```json
{
  "id": "fix-feature-001-001",
  "name": "Token expiry not handled",
  "description": "User gets stuck on expired token",
  "linkedTo": {
    "featureId": "feature-001",
    "featureName": "User Authentication",
    "issueNumber": 42
  },
  "type": "bugfix",
  "status": "pending|in_progress|passing|escalated",
  "verification": {
    "build": "npm run build",
    "tests": "npm run test",
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit",
    "custom": [],
    "inherited": true
  },
  "attempts": 0,
  "maxAttempts": 15,
  "relatedFiles": [],
  "github": {
    "issueNumber": 55,
    "prNumber": null,
    "branch": "fix/feature-001-token-expiry"
  },
  "createdAt": "2025-01-20T11:00:00Z",
  "updatedAt": "2025-01-20T11:00:00Z"
}
```

Key differences from features:
- `linkedTo` - References the original feature
- `type: "bugfix"` - Distinguishes from features
- `verification.inherited` - Indicates commands came from original feature
- Branch format: `fix/{feature-id}-{slug}` instead of `feature/`
- Commits use `fix:` prefix (triggers PATCH version bump)

## Agentic Loops

The `/do` command runs autonomous implementation loops that continue until ALL tests pass:

```
/claude-harness:do feature-001

┌─────────────────────────────────────────────────────────────────┐
│  AGENTIC LOOP: User Authentication                              │
├─────────────────────────────────────────────────────────────────┤
│  Attempt 3/10                                                   │
│  ├─ Failure Prevention: Checked 3 past failures                 │
│  ├─ Implementation: Using React hooks pattern                   │
│  ├─ Verification:                                               │
│  │   ├─ Build:     ✅ PASSED                                    │
│  │   ├─ Tests:     ✅ PASSED (15/15)                            │
│  │   ├─ Lint:      ✅ PASSED                                    │
│  │   └─ Typecheck: ✅ PASSED                                    │
│  └─ Result: ✅ SUCCESS                                          │
├─────────────────────────────────────────────────────────────────┤
│  ✅ Feature complete! Approach saved to successes.json          │
└─────────────────────────────────────────────────────────────────┘
```

On failure:
- Records approach to `failures.json` with root cause analysis
- Analyzes errors and tries different approach
- Consults `successes.json` for working patterns
- Up to 10 attempts before escalation

## Multi-Agent Orchestration

For complex features, spawn specialized agents:

```
/claude-harness:orchestrate feature-001

→ Phase 1: Task Analysis
  - Identifies domains: frontend, backend, database
  - Checks impact analysis

→ Phase 2: Failure Prevention Check
  - Queries procedural/failures.json
  - Warns agents about approaches to avoid

→ Phase 3: Agent Selection
  - react-specialist (frontend components)
  - backend-developer (API routes)
  - database-administrator (schema)
  - code-reviewer (mandatory)

→ Phase 4: Parallel Execution
  - Independent tasks run simultaneously
  - Handoffs managed via agents/handoffs.json

→ Phase 5: Verification Loop
  - All commands must pass
  - Re-spawns agents on failure (max 3 cycles)

→ Phase 6: Memory Persistence
  - Records successes/failures
  - Updates patterns
```

## Impact Analysis

Track how changes affect other components:

```json
// .claude-harness/impact/dependency-graph.json
{
  "nodes": {
    "src/lib/auth.ts": {
      "imports": ["src/lib/api.ts", "src/types/user.ts"],
      "importedBy": ["src/app/api/auth/login/route.ts", "src/components/LoginForm.tsx"],
      "tests": ["tests/lib/auth.test.ts"],
      "type": "module"
    }
  },
  "hotspots": ["src/lib/api.ts"],
  "criticalPaths": ["src/app/layout.tsx"]
}
```

When modifying files:
- Identifies dependent files
- Warns about high-impact changes
- Suggests running related tests

## Migration from v2.x

```bash
# In your project with existing harness
./setup.sh --migrate

# Creates backup: .claude-harness-backup-{timestamp}/
# Migrates:
#   feature-list.json → features/active.json
#   agent-memory.json → memory/procedural/
#   working-context.json → memory/working/context.json
#   loop-state.json → loops/state.json
```

Or let it auto-migrate on first run of a harness command.

## GitHub MCP Integration

```bash
# Setup
claude mcp add github -s user

# Workflow (all in one command!)
/claude-harness:do "Add dark mode"      # Creates issue + branch, implements, commits, creates PR

# Or step by step
/claude-harness:do --plan-only "Add dark mode"  # Create + plan only
/claude-harness:do feature-001                  # Resume and implement
/claude-harness:checkpoint                      # Manual commit + PR if needed
/claude-harness:merge                           # Merge all PRs, auto-version
```

## Configuration

```json
// .claude-harness/config.json
{
  "version": 3,
  "verification": {
    "build": "npm run build",
    "tests": "npm run test",
    "lint": "npm run lint",
    "typecheck": "npx tsc --noEmit"
  },
  "memory": {
    "episodicMaxEntries": 50,
    "contextCompilationEnabled": true
  },
  "failurePrevention": {
    "enabled": true,
    "similarityThreshold": 0.7
  },
  "impactAnalysis": {
    "enabled": true,
    "warnOnHighImpact": true
  },
  "testDriven": {
    "enabled": true,
    "generateTestsBeforeImplementation": true
  }
}
```

## Changelog

> **v4.1.0 Release Notes**: See [RELEASES/v4.1.0.md](./RELEASES/v4.1.0.md) for full details on auto-issue creation and GitHub integration.
> **v3.0.0 Release Notes**: See [RELEASE-NOTES-v3.0.0.md](./RELEASE-NOTES-v3.0.0.md) for full details with architecture diagrams.

| Version | Changes |
|---------|---------|
| **5.1.1** | **Fix Setup Auto-Update**: `setup.sh` now auto-detects version upgrades by comparing installed `.plugin-version` against `plugin.json`. When a version change is detected, command files are automatically updated (equivalent to `--force-commands`) without requiring the flag. Fixes issue where running setup on existing projects only bumped the version file but skipped command updates. |
| **5.1.0** | **Autonomous Multi-Feature Processing**: New `--autonomous` flag on `/flow` command enables unattended batch processing of the entire feature backlog. Iterates through all active features with strict TDD enforcement (Red-Green-Refactor), automatic checkpoint (commit, push, PR), merge to main, context reset, and loop back. Git rebase conflict detection auto-skips conflicting features. Configurable termination: max iterations (20), consecutive failure threshold (3), or all features complete. Autonomous state persisted to `autonomous-state.json` for crash recovery and resume. Compatible with `--no-merge` (stop at checkpoint) and `--quick` (skip planning). Forces `--inline` mode. TDD-specific task chain (7 tasks) with visual progress tracking. |
| **5.0.0** | **Opus 4.6 Optimizations**: Effort controls per workflow phase (low for mechanical operations, max for planning/debugging) across `/flow`, `/do`, `/do-tdd`, and `/orchestrate`. Agent Teams integration as preferred parallel agent spawning mechanism with Task tool fallback. 128K output token utilization for richer PRD analysis (exhaustive subagent output, PRD size limit increased to 100KB). Increased maxAttempts from 10 to 15 for better agentic loop sustaining. Adaptive loop strategy with progressive effort escalation on retries. Native context compaction awareness in PreCompact hook. Effort-per-agent-role table in orchestration. Session banner now displays Opus 4.6 capabilities. All changes backward compatible with pre-Opus 4.6 models. |
| **4.5.1** | **Fix Version Tracking & Stale State Detection**: Removed hardcoded version from `setup.md` — now reads dynamically from `plugin.json`. Fixed `setup.sh` to use `$PLUGIN_VERSION` variable everywhere instead of hardcoded strings. Added active.json validation to `user-prompt-submit.sh` to prevent stale loop-state from falsely reporting archived features as active. Cleaned up stale legacy `loops/state.json`. |
| **4.5.0** | **Native Claude Code Tasks Integration**: Features now create a 5-task chain using Claude Code's native Tasks system (TaskCreate, TaskUpdate, TaskList). Tasks provide visual progress tracking (`[✓] Research [✓] Plan [→] Implement [ ] Verify [ ] Checkpoint`), persist across sessions, and have built-in dependency management. Loop-state schema updated to v4 with task references. Backward compatible with v3 loop-state. Graceful fallback if TaskCreate fails. |
| **4.4.2** | **Fix Stop Hook Command-Type**: Converted Stop hook from prompt-type (unreliable JSON validation) to command-type shell script for reliable completion detection. |
| **4.4.1** | **Fix Stop Hook Schema**: Fixed prompt-based Stop hook schema validation error. The hook response must include `ok` boolean field for Claude Code to process it correctly. |
| **4.4.0** | **Automated End-to-End Flow**: New `/claude-harness:flow` command combines start→do→checkpoint→merge into single automated workflow. Added prompt-based `Stop` hook (Haiku LLM) for intelligent completion detection. Added `UserPromptSubmit` hook for smart routing to active loops. GitHub repo now cached in SessionStart hook (eliminates 4 redundant parses). Memory layers read in parallel for 30-40% faster startup. Streaming memory updates after each verification attempt. Commands updated to use cached GitHub repo. |
| **4.3.0** | **Enforce GitHub Issue Creation**: Made GitHub issue creation MANDATORY (not optional) for all features and fixes. Added explicit issue body templates with required sections (Problem, Solution, Acceptance Criteria, Verification). Added "MANDATORY REQUIREMENTS" section at top of `/do` command. Issues now MUST be created before any code work - failure blocks progression. Fixes context loss when issues were sometimes skipped. |
| **4.2.3** | **Remove Legacy State Files**: Removed creation of unused legacy files (`loop-state.json`, `working-context.json`, `loops/state.json`, `memory/working/`). All workflow state is now session-scoped under `sessions/{session-id}/`. Updated setup.md and start.md to reflect current architecture. Cleaned up .gitignore patterns. |
| **4.2.2** | **Fix Session Cleanup on WSL**: Moved stale session cleanup from SessionEnd hook to SessionStart hook for reliability. SessionEnd may not trigger on `/clear` or crashes, so cleanup now happens proactively when a new session starts. Removed `jq` dependency from both hooks (uses grep/sed instead). Fixes fix-feature-013-001. |
| **4.2.1** | **Removed Obsolete File References**: Cleaned up all references to legacy `feature-list.json` and `feature-archive.json` files. Fresh setups now only create `features/active.json` and `features/archive.json`. Updated migration instructions to properly move old files to new locations. |
| **4.2.0** | **Simplified /merge Command**: Removed version tagging and GitHub release creation from `/merge` command since git tag operations are not directly supported by GitHub MCP. The command now focuses on merging PRs, closing issues, and cleaning up branches. Version tagging should be done manually using git commands or GitHub's release UI. |
| **4.1.0** | **Auto-Create GitHub Issues from PRD**: New `--create-issues` flag on `/prd-breakdown` command automatically creates one GitHub issue per generated feature. Designed for explicit opt-in (not automatic) with full automation once flag is used. Issues include feature description, acceptance criteria, and priority metadata. Labeled with `feature` and `prd-generated` tags. Gracefully degrades if GitHub MCP unavailable. Enables teams to go from PRD → features → tracked backlog in one command. See [RELEASES/v4.1.0.md](./RELEASES/v4.1.0.md). |
| **4.0.0** | **PRD Analysis & Decomposition**: New `/claude-harness:prd-breakdown` command analyzes Product Requirements Documents using 3 parallel subagents (Product Analyst, Architect, QA Lead). Automatically decomposes PRDs into atomic features with dependencies, priorities, and acceptance criteria. Supports inline PRD, file-based, GitHub issues, or interactive input. Essential for bootstrapping feature lists in new projects. Version bumped across all files (setup.sh, plugin.json, hooks, README). See [RELEASES/v4.0.0.md](./RELEASES/v4.0.0.md). |
| **3.9.6** | **Remote Branch Cleanup in Merge**: `/merge` command now explicitly deletes remote branches after PR merge using `git push origin --delete {branch}`. Phase 4 clarified to include both remote and local deletion, Phase 7 adds verification step, Phase 8 reports both local and remote deletions. |
| **3.9.2** | **Fix Multi-Select in Interactive Menu**: Made `multiSelect: true` requirement more explicit in `/do` Phase 0 documentation. Added CRITICAL marker and "DO NOT use multiSelect: false" warning to ensure parallel feature selection works correctly. |
| **3.9.1** | **Interactive Feature Selection**: Running `/do` without arguments now shows an interactive menu of pending features with multi-select checkboxes. Select one to resume, select multiple to create worktrees for parallel development, or choose "Other" to create a new feature. |
| **3.9.0** | **Git Worktree Support**: True parallel development with isolated working directories. `/do` now auto-creates worktrees by default (use `--inline` to skip). New `/worktree` command for managing worktrees (list, create, remove, prune). All commands are worktree-aware, reading shared state (features, memory) from main repo while keeping session state local. Industry-standard approach used by incident.io and others. |
| **3.8.6** | **Fix SessionEnd Hook for Plugin Installations**: SessionEnd hook now uses `hooks/hooks.json` (plugin configuration) instead of `.claude/settings.json` (project configuration). This ensures automatic session cleanup works in all projects where the plugin is installed, not just the plugin's own repo. |
| **3.8.5** | **Automatic Session Cleanup**: Added `SessionEnd` hook that automatically cleans up inactive session directories when Claude exits. Uses PID-based detection to preserve active parallel sessions while removing stale ones. Prevents disk bloat from accumulated sessions. |
| **3.8.4** | **Enforce Gitignore in /setup**: Made Phase 3 (gitignore update) MANDATORY with explicit instructions. Marked as CRITICAL with "DO NOT SKIP" to ensure ephemeral patterns are always added. |
| **3.8.3** | **Add Gitignore to /setup Command**: The `/claude-harness:setup` command now includes Phase 3 to update project `.gitignore` with harness ephemeral patterns (sessions/, compaction-backups/, working/). |
| **3.8.2** | **Fix setup.sh Syntax Error**: Fixed heredoc quoting issue that prevented `setup.sh` from running. The init.sh content now uses proper quoted heredoc (`<<'EOF'`) to preserve special characters. |
| **3.8.1** | **Fix Uncommitted Harness Files**: `setup.sh` now automatically adds gitignore patterns to target projects. Prevents ephemeral files (sessions/, compaction-backups/, working/) from appearing as uncommitted after checkpoint. |
| **3.8.0** | **Parallel Work Streams**: Session-scoped state enables multiple Claude instances to work on different features simultaneously without conflicts. Each session gets unique ID and isolated state directory (`.claude-harness/sessions/{id}/`). Sessions are gitignored, shared state (features, memory) remains committed. |
| **3.7.1** | **Fix Missing Learned Rules**: Fixed error when reading `.claude-harness/memory/learned/rules.json` on installations from pre-v3.6. `/start` Phase 0 now creates the file if missing. |
| **3.7.0** | **TDD Enforcement Command**: New `/claude-harness:do-tdd` command for test-driven development. Enforces RED-GREEN-REFACTOR workflow, blocks implementation until tests exist. Keeps `/do` unchanged for backward compatibility. |
| **3.6.7** | **Fix GitHub Repo Detection**: Added explicit `git remote get-url origin` parsing instructions to all commands that use GitHub MCP. Prevents Claude from guessing or caching wrong owner/repo values from previous sessions. |
| **3.6.6** | **Full Command Prefixes**: All command references now use full `/claude-harness:` prefix for clarity and to avoid conflicts with other plugins. |
| **3.6.5** | **Context Management**: Added `/clear` recommendation after checkpoint to prevent context rot. Added PreCompact hook as safety net to backup state before automatic compaction. |
| **3.6.4** | **Fix Argument Hints**: Use correct `argument-hint` field (with hyphen) instead of `argumentsPrompt`. Now displays input suggestions like ralph-loop. |
| **3.6.3** | **Improved Argument Hints**: Updated command hints to use CLI-style bracket notation (e.g., `"DESC" \| ID [--quick] [--auto]`) for better scannability. Added hints to `/checkpoint`. |
| **3.6.2** | **Branch Safety**: Fixed `/do` to enforce GitHub issue and branch creation BEFORE any code work. Added branch verification safety check that stops if on main/master. Explicit step-by-step instructions with "DO NOT PROCEED" markers. |
| **3.6.1** | **Hooks Fix**: Removed duplicate `hooks` reference from plugin.json - `hooks/hooks.json` is auto-loaded by convention. |
| **3.6.0** | **Command Consolidation**: Reduced from 13 to 6 commands. `/do` now handles fixes via `--fix` flag. Removed redundant commands (`/feature`, `/plan-feature`, `/implement`, `/fix`, `/reflect`, `/generate-tests`, `/check-approach`). Renamed `/merge-all` to `/merge`. Auto-reflect always enabled at checkpoint. |
| **3.5.0** | **Unified Workflow**: `/do` command - chains feature creation, planning, implementation, and checkpoint in one command with interactive prompts. Options: `--quick` (skip planning), `--auto` (no prompts), `--plan-only`. Resumable with `/do resume` or `/do feature-XXX` |
| **3.4.0** | **Safe Permissions**: Comprehensive permission configuration to avoid `--dangerously-skip-permissions` - deny list for dangerous commands, ask list for destructive ops, allow list for safe harness operations |
| **3.3.2** | **Chore**: Fixed legacy file path references in command docs - all commands now reference correct v3.0+ paths (`agents/context.json`, `memory/procedural/`, `loops/state.json`) |
| **3.3.1** | **Bug Fix**: Fixed inconsistent file path references - all commands now consistently use `features/active.json` instead of legacy `feature-list.json` |
| **3.3.0** | **Self-Improving Skills**: `/reflect` command - Extract rules from user corrections, auto-reflect at checkpoint, display learned rules at session start |
| **3.2.0** | **Memory System Utilization**: Commands now actually use the 4-layer memory system - `/start` compiles context, `/implement` queries failures before attempting, `/checkpoint` persists to memory |
| **3.1.0** | **Bug Fix Command**: `/fix` - Create bug fixes linked to original features with shared memory context, GitHub issue linkage, and PATCH versioning |
| **3.0.0** | **Memory Architecture Release** - See release notes above |
| 2.6.0 | Agentic Loops: `/implement` runs until verification passes |
| 2.5.1 | Full command paths in session output |
| 2.5.0 | Box-drawn UI in session start |
| 2.4.0 | Fixed hooks loading |
| 2.3.0 | SessionStart hook, auto-setup detection |
| 2.2.0 | Moved files to `.claude-harness/` |
| 2.1.0 | Added `working-context.json` |
| 2.0.0 | Shortened command names |
| 1.1.0 | Multi-agent orchestration |
| 1.0.0 | Initial release |

## Safe Permissions (Avoiding --dangerously-skip-permissions)

The harness includes a comprehensive permission configuration that allows Claude Code to run without the dangerous `--dangerously-skip-permissions` flag while maintaining full functionality.

### Configuration Location

```
.claude/settings.local.json    # Personal settings (gitignored)
.claude/settings.json          # Team-shared settings (committed)
```

### Permission Model

| Category | Behavior | Examples |
|----------|----------|----------|
| **Allow** | Auto-approved | `git add`, `npm run`, `ls`, `cat` |
| **Ask** | Prompts user | `rm`, `git push`, `npm install` |
| **Deny** | Always blocked | `curl`, `sudo`, `rm -rf /` |

### Safe Operations (Auto-Allowed)

```json
{
  "allow": [
    "Bash(git status:*)", "Bash(git add:*)", "Bash(git commit:*)",
    "Bash(git checkout:*)", "Bash(git branch:*)", "Bash(git log:*)",
    "Bash(npm run:*)", "Bash(npx tsc:*)", "Bash(npx jest:*)",
    "Bash(mkdir:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(grep:*)",
    "Bash(./hooks/*)", "Bash(./.claude-harness/*)"
  ]
}
```

### User Confirmation Required

```json
{
  "ask": [
    "Bash(rm:*)",           // All file deletion
    "Bash(rmdir:*)",        // All directory deletion
    "Bash(git push:*)",     // Remote operations
    "Bash(git reset:*)",    // Destructive git
    "Bash(npm install:*)",  // Package installation
    "Bash(chmod:*)"         // Permission changes
  ]
}
```

### Dangerous Operations (Always Blocked)

```json
{
  "deny": [
    // Network (data exfiltration risk)
    "Bash(curl:*)", "Bash(wget:*)", "Bash(nc:*)", "Bash(ssh:*)",

    // Privilege escalation
    "Bash(sudo:*)", "Bash(su:*)", "Bash(doas:*)",

    // Destructive filesystem operations
    "Bash(rm -rf /)", "Bash(rm -rf ~)", "Bash(rm -rf /home:*)",
    "Bash(rm -rf /etc:*)", "Bash(rm -rf /usr:*)", "Bash(rm -rf /var:*)",

    // Low-level system operations
    "Bash(dd:*)", "Bash(mkfs:*)", "Bash(fdisk:*)",
    "Bash(systemctl:*)", "Bash(shutdown:*)", "Bash(reboot:*)",

    // User/group management
    "Bash(useradd:*)", "Bash(userdel:*)", "Bash(passwd:*)",

    // Code execution (potential RCE)
    "Bash(python -c:*)", "Bash(node -e:*)", "Bash(eval:*)",

    // Secrets protection
    "Read(.env)", "Read(.env.*)", "Read(**/credentials*)", "Read(**/*.pem)"
  ]
}
```

### How Precedence Works

1. **Deny rules checked first** - If matched, command is blocked
2. **Ask rules checked second** - If matched, user is prompted
3. **Allow rules checked last** - If matched, command runs

This means dangerous patterns like `rm -rf /home/*` are blocked even though `rm:*` is in the ask list.

### Using the Configuration

```bash
# Run Claude Code normally (no dangerous flag needed)
cd your-project
claude

# The harness commands work with auto-approved safe operations
/claude-harness:start       # ✅ Uses git status, cat, grep
/claude-harness:checkpoint  # ✅ Uses git add, commit (push prompts)
/claude-harness:do          # ✅ Uses npm run, npx tsc
```

### Extending for Your Project

Add project-specific safe commands to `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(docker compose up:*)",
      "Bash(make build:*)",
      "Bash(cargo test:*)"
    ]
  }
}
```

## Key Principles

1. **Never Trust Self-Assessment** - All verification is mandatory via commands
2. **Learn From Mistakes** - Failure prevention system records and warns
3. **Test First** - Generate tests before implementation
4. **Computed Context** - Fresh, relevant context each session (no accumulation)
5. **Memory Persistence** - Knowledge survives context windows
6. **Single Feature Focus** - One feature at a time prevents scope creep

## Sources

- [Anthropic: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Context-Engine](https://github.com/zeddy89/Context-Engine) - Memory architecture inspiration
- [Agent-Foreman](https://github.com/mylukin/agent-foreman) - Task management patterns
- [Autonomous-Coding](https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding) - Test-driven approach
