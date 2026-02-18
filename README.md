# Claude Code Long-Running Agent Harness

A Claude Code plugin for automated, context-preserving coding sessions with **5-layer memory architecture**, failure prevention, test-driven features, and GitHub integration.

Based on [Anthropic's engineering article](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) and enhanced with patterns from:
- [Context-Engine](https://github.com/zeddy89/Context-Engine) - Memory architecture
- [Agent-Foreman](https://github.com/mylukin/agent-foreman) - Task management patterns
- [Autonomous-Coding](https://github.com/anthropics/claude-quickstarts/tree/main/autonomous-coding) - Test-driven approach

## TL;DR - End-to-End Workflow

### Quick Start

```bash
# Step 1: Add the marketplace (registers the catalog)
/plugin marketplace add panayiotism/claude-harness

# Step 2: Install the plugin
/plugin install claude-harness@panayiotism-claude-harness
```

Or from the terminal:

```bash
claude plugin marketplace add panayiotism/claude-harness
claude plugin install claude-harness@panayiotism-claude-harness
```

```bash
# Initialize in your project (one-time)
cd your-project && claude
/claude-harness:setup

# Single command for entire workflow (start → do → checkpoint → merge)
/claude-harness:flow "Add user authentication with JWT tokens"
# Auto-compiles context, creates issue/branch, implements, checkpoints, merges

# Or batch-process all active features autonomously with TDD
/claude-harness:flow --autonomous

# Or step-by-step without auto-merge
/claude-harness:flow --no-merge "Add user authentication with JWT tokens"
```

The **`/flow`** command handles the entire lifecycle automatically - from context compilation to PR merge. It enforces test-driven development practices with a RED-GREEN-REFACTOR cycle and acceptance testing. Use `--team` for ATDD with Agent Teams (tester + implementer + reviewer). Use `--autonomous` to batch-process all active features. Use `--no-merge` for step-by-step control, `--quick` to skip planning for simple tasks.

### Complete Workflow (5 Commands Total)

```bash
# 1. SETUP (one-time)
/claude-harness:setup                              # Initialize harness in project

# 2. START SESSION (or skip with /flow)
/claude-harness:start                              # Compile context, show status

# 3. DEVELOPMENT (unified /flow command)
/claude-harness:flow "Add dark mode"               # Complete lifecycle in one command
/claude-harness:flow --no-merge "Add feature"      # Stop at checkpoint (don't auto-merge)
/claude-harness:flow --autonomous                   # Batch-process all features
/claude-harness:flow --fix feature-001 "Token bug" # Bug fix linked to feature
/claude-harness:flow feature-001                   # Resume existing feature/fix

# 4. MANUAL CHECKPOINT (optional - /flow includes checkpoint)
/claude-harness:checkpoint               # Commit, push, create PR

# 5. RELEASE
/claude-harness:merge                    # Merge all PRs, close issues
```

### What Happens Behind the Scenes

```
/setup           → One-time: Creates .claude-harness/ with memory architecture

/start           → Compiles working context from 4 memory layers
                   Shows status, syncs GitHub, displays learned rules

/flow            → UNIFIED END-TO-END WORKFLOW:
                   1. Auto-compiles context (replaces /start)
                   2. Creates feature (GitHub issue + branch)
                   3. Plans implementation (checks past failures)
                   4. Implements feature with TDD enforcement
                   5. Verifies: RED → GREEN → REFACTOR
                   6. Auto-checkpoints when all tests pass
                   7. Auto-merges when PR approved
                   Options: --no-merge, --quick, --autonomous,
                            --plan-only, --fix, --team
                   --autonomous: Batch loop through ALL features
                   OPTIMIZATIONS: Parallel memory reads, cached GitHub parsing

/checkpoint      → Manual commit + push + PR (when not using /flow)
                   Auto-reflects on user corrections

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
└── sessions/        → Per-session state (gitignored, enables parallel work)
    └── {uuid}/      → Each Claude instance gets isolated loop/context state
```

### Session Cleanup (Automatic)

Session directories are automatically cleaned up at session start. The `SessionStart` hook detects stale sessions by checking their PID:

- **Active sessions** (PID still running) are preserved
- **Stale sessions** (PID no longer running) are deleted
- **Current session** gets a fresh state directory

This ensures parallel Claude instances don't interfere with each other while preventing disk bloat from accumulated sessions.

## Session Start Hook

When you start Claude Code in a harness-enabled project:

```
┌─────────────────────────────────────────────────────────────────┐
│                  CLAUDE HARNESS v8.0.0                            │
├─────────────────────────────────────────────────────────────────┤
│  P:2 WIP:1 Tests:1 Fixes:1 | Active: feature-001                │
│  Memory: 12 decisions | 3 failures | 8 successes                │
│  GitHub: owner/repo (cached)                                    │
├─────────────────────────────────────────────────────────────────┤
│  /claude-harness:setup          Initialize harness (one-time)   │
│  /claude-harness:start          Compile context + GitHub sync   │
│  /claude-harness:flow           Unified workflow (all flags)    │
│  /claude-harness:checkpoint     Commit + persist memory         │
│  /claude-harness:merge          Merge PRs + close issues        │
└─────────────────────────────────────────────────────────────────┘
```

Shows:
- **Feature status**: P (Pending) / WIP (Work-in-progress) / Tests (Needs tests)
- **Memory stats**: Decisions recorded, failures to avoid, successes to reuse
- **Failure prevention**: If failures exist, warns before implementing

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

Before each implementation attempt, `/flow` automatically checks past failures:

```
/claude-harness:flow feature-002

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

The `/flow` command enforces test-driven development practices. Every feature follows a RED-GREEN-REFACTOR cycle with acceptance testing:

```
/claude-harness:flow "Add user authentication"

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

The `/flow` command separates planning from implementation internally:

### Phase 1: Plan (automatic in /flow)

```
/claude-harness:flow "Add authentication"

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

### Phase 2: Implement (automatic in /flow)

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

## Commands Reference (5 Total)

| Command | Purpose |
|---------|---------|
| `/claude-harness:setup` | Initialize harness in project (one-time) |
| `/claude-harness:start` | Compile context + GitHub sync + status |
| **`/claude-harness:flow`** | **Unified workflow**: start→implement→checkpoint→merge (flags: `--no-merge`, `--plan-only`, `--autonomous`, `--quick`, `--fix`) |
| `/claude-harness:checkpoint` | Manual commit + push + PR |
| `/claude-harness:merge` | Merge all PRs, close issues |

### `/flow` Command Options

| Syntax | Behavior |
|--------|----------|
| `/flow "Add feature"` | Complete lifecycle: TDD (RED→GREEN→REFACTOR) → checkpoint → merge |
| `/flow feature-001` | Resume existing feature from current phase |
| `/flow --no-merge "Add feature"` | Stop at checkpoint (don't auto-merge) |
| `/flow --plan-only "Big feature"` | Plan only, implement later |
| `/flow --quick "Simple change"` | Skip planning phase |
| `/flow --fix feature-001 "Bug"` | Complete lifecycle for a bug fix |
| `/flow --autonomous` | **Batch loop**: process all active features, checkpoint, merge, repeat |
| `/flow --autonomous --no-merge` | Batch loop but stop each feature at checkpoint (PRs created, not merged) |

**Key Features in /flow**:
- **TDD enforcement**: RED→GREEN→REFACTOR cycle enforced by design
- **Acceptance testing**: Deterministic E2E tests run after refactoring
- Memory layers read in parallel (30-40% faster startup)
- GitHub repo parsed once and cached for entire flow
- Streaming memory updates after each verification attempt

**TDD Phases (always-on):**
```
RED      → Write failing tests
GREEN    → Write minimal code to pass tests
REFACTOR → Validate quality, fix issues
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
Input         → Read PRD from inline, file, or GitHub
Analyze       → Analyzes requirements from product, architecture, and QA perspectives
Decompose     → Transform requirements into atomic features
  • Resolve dependencies (topological sort)
  • Assign priorities (MVP first)
  • Generate acceptance criteria
Review        → Preview breakdown, select features to create
Create        → Add features to active.json with PRD metadata
Issues (opt)  → Create GitHub issues for tracking (--create-issues flag)
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
│   └── context.json              # Orchestration state
├── prd/                          # PRD analysis and decomposition
│   ├── input.md                  # Original PRD document
│   ├── metadata.json             # PRD metadata and hash
│   ├── analysis.json             # Analysis results
│   ├── breakdown.json            # Decomposed features
│   └── analyst-prompts.json      # Reusable analysis prompts
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

The `/flow` command runs autonomous implementation loops that continue until ALL tests pass:

```
/claude-harness:flow feature-001

┌─────────────────────────────────────────────────────────────────┐
│  AGENTIC LOOP: User Authentication                              │
├─────────────────────────────────────────────────────────────────┤
│  Attempt 3/10                                                   │
│  ├─ Failure Prevention: Checked 3 past failures                 │
│  ├─ Implementation: Using React hooks pattern                   │
│  ├─ Verification:                                               │
│  │   ├─ Build:     PASSED                                       │
│  │   ├─ Tests:     PASSED (15/15)                               │
│  │   ├─ Lint:      PASSED                                       │
│  │   └─ Typecheck: PASSED                                       │
│  └─ Result: SUCCESS                                             │
├─────────────────────────────────────────────────────────────────┤
│  Feature complete! Approach saved to successes.json             │
└─────────────────────────────────────────────────────────────────┘
```

On failure:
- Records approach to `failures.json` with root cause analysis
- Analyzes errors and tries different approach
- Consults `successes.json` for working patterns
- Up to 10 attempts before escalation

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
/claude-harness:flow "Add dark mode"      # Creates issue + branch, implements, commits, creates PR

# Or step by step
/claude-harness:flow --plan-only "Add dark mode"  # Create + plan only
/claude-harness:flow feature-001                  # Resume and implement
/claude-harness:checkpoint                        # Manual commit + PR if needed
/claude-harness:merge                             # Merge all PRs, auto-version
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

## Troubleshooting

### Stuck on Old Plugin Version

`claude plugin update` has a known bug where it doesn't re-download plugin files. Run this one-liner to fix it:

```bash
bash <(curl -sf https://raw.githubusercontent.com/panayiotism/claude-harness/main/fix-plugin-cache.sh)
```

This updates the marketplace cache, downloads the latest plugin, and updates the registry. Then restart Claude Code and run `/claude-harness:setup`.

**Note:** v8.1.0+ includes auto-update — the session-start hook automatically fixes stale caches on startup.

## Changelog

### v9.0.0 (2026-02-18) - Agent Teams with ATDD

- **Agent Teams**: Re-introduces Agent Teams with opt-in `--team` flag (previously removed in v8.0.0). Teams are no longer mandatory — direct implementation remains the default.
- **ATDD workflow**: Acceptance Test-Driven Development with Gherkin acceptance criteria (Given/When/Then). Tester writes acceptance tests FIRST (RED), implementer makes them pass (GREEN), reviewer validates.
- **3 new hooks** (6 to 9 total): `TeammateIdle` (quality gate), `TaskCompleted` (ATDD verification gate), `SubagentStart` (context injection)
- **Structured Gherkin**: `acceptanceCriteria` field on features uses `{ scenario, given, when, then }` objects — machine-readable for the tester teammate, human-readable in GitHub issues
- **Team task chain**: 6-task ATDD dependency chain (write tests -> plan -> implement -> review -> feedback -> verify)
- **Config sections**: `agentTeams` (enabled/roles/planApproval) and `atdd` (criteriaFormat/acceptanceTestFirst) in config.json
- **Schema changes**: loop-state v8 to v9 (adds `team` field), new agents-context schema v2 (adds `teamState`)
- **BREAKING**: Loop-state schema version 8 to 9. Existing loop-state files need version bump.
- Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` env var (auto-injected by setup.sh when `agentTeams.enabled` is true)

### v8.4.0 (2026-02-17) - Schema standardization

- Added `claude-harness/schemas/` directory with JSON Schema files for key state files (loop-state, active-features, context, autonomous-state, memory-entries)
- Fixed loop-state version drift: was referenced as v3 in setup.md, v4 in checkpoint.md, v8 in flow.md — now all reference canonical schema
- Removed hardcoded version comments from hook `.sh` files (version lives only in plugin.json)
- Added schema versioning convention to CLAUDE.md: `"version"` in JSON files = data schema version, not plugin version
- Updated procedural memory patterns to reflect simplified version bump process
- Command docs now reference schema files instead of embedding inline JSON examples

### v8.1.0 (2026-02-15) - Auto-update stale plugin cache

- session-start.sh auto-downloads latest plugin from GitHub when stale cache detected
- Updates cache directory and `installed_plugins.json` registry automatically
- Works around Claude Code `plugin update` bug (#19197, #14061, #13799, #15642)
- Added `fix-plugin-cache.sh` curl-able script for users stuck on older versions

### v8.0.0 (2026-02-15) - Remove Agent Teams

- **BREAKING**: Remove Agent Teams: Direct implementation model replaces 3-specialist team orchestration. Removed SubagentStart, TeammateIdle, TaskCompleted hooks. 9→6 hook registrations. No longer requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS.

### v7.0.0 (2026-02-14) - Restructure repo for marketplace compatibility

- **BREAKING**: Moved plugin files (`commands/`, `hooks/`, `setup.sh`) into `claude-harness/` subdirectory
- **Fixed**: Plugin install fails with "not found in marketplace" and GitHub self-reference causes infinite recursion
- Root cause: Claude Code requires plugins in subdirectories within a marketplace repo. Having `marketplace.json` and `plugin.json` in the same `.claude-plugin/` at root is unsupported — every working marketplace (Anthropic, gmickel, cbrake, EveryInc) uses `source: "./subdirectory"`
- Marketplace source now `"./claude-harness"` pointing to the plugin subdirectory
- Existing users: run `claude plugin update claude-harness` to get the new structure

### v6.0.6 (2026-02-14) - Fix installation instructions

- **Fixed**: README Quick Start used invalid `github:owner/repo` syntax for `claude plugin install`
- Root cause: There is no `github:` prefix in Claude Code's plugin install command. Plugins must be installed via the marketplace workflow (add marketplace first, then install from it)
- Replaced incorrect "Option B: Direct GitHub install" with correct two-step marketplace commands
- Added terminal CLI equivalent (`claude plugin marketplace add` / `claude plugin install`)

### v6.0.5 (2026-02-14) - Remove stale cache detection

- **Removed**: Custom stale cache detection system from `session-start.sh`
  - Removed `version_lt()`, `check_latest_version()`, GitHub API/curl version fetch, 24h TTL cache
  - Removed "STALE CACHE" user warning and "STALE PLUGIN CACHE DETECTED" AI context blocker
- **Rationale**: No other Claude Code plugin implements custom update detection. Claude Code's native `claude plugin update` is sufficient.
- **Kept**: Local plugin-vs-project version mismatch detection (`.plugin-version` comparison) for `/setup` migration prompts

### v6.0.4 (2026-02-14) - Fix stale SessionEnd hook in settings.local.json

- **Fixed**: `SessionEnd hook [session-end.sh] failed: not found` error on session exit
- Root cause: `settings.local.json` retained a stale `SessionEnd` hook from pre-v6.0.0, but the hook script was removed during the v6.0.0 consolidation (12 → 6 hooks)
- `setup.sh` skips existing `settings.local.json` files, so the stale entry was never cleaned up
- Added cleanup step to `setup.sh` that strips `SessionEnd` from existing `settings.local.json` files

### v6.0.3 (2026-02-14) - Fix false-positive stale cache warning

- **Fixed**: Stale cache warning showing even after plugin update (installed version newer than cached "latest")
- Root cause: version comparison used string `!=` instead of semver less-than — any version difference triggered the warning, including when installed > latest
- Added `version_lt()` using `sort -V` for proper semver comparison
- Auto-clears stale `.version-check` cache when installed version is already up-to-date

### v6.0.0 (2026-02-14) - Official Plugin Alignment + Hook Consolidation

**Major release**: Aligns plugin with official Claude Code plugin guidelines. Commands served from plugin cache, redundant hooks removed, setup.sh simplified.

#### Plugin Alignment
- Commands served from plugin cache (removed command-copying from `setup.sh`)
- Deprecated `--force-commands` flag (use `claude plugin update` instead)
- `setup.sh` now cleans up legacy command copies from target projects' `.claude/commands/`

#### Hook Consolidation (12 → 6 registrations)
- Removed `SessionEnd` hook (stale session cleanup already handled by SessionStart)
- Removed `UserPromptSubmit` hook (active loop context already injected by SessionStart)
- Removed `PostToolUse` hook (async test-on-edit duplicated verification gates)
- Removed `PostToolUseFailure` hook (low-value failure recording; gates handled elsewhere)
- Removed `SubagentStart` hook (no longer needed without team orchestration)
- Removed `TeammateIdle` hook (no longer needed without team orchestration)
- Removed `TaskCompleted` hook (no longer needed without team orchestration)
- Removed dead `session-start-compact.sh` script (not registered in hooks.json)
- Remaining hooks, 6 registrations: SessionStart, PreCompact, Stop, PreToolUse (Bash + Edit|Write), PermissionRequest

#### Upgrade
```bash
claude plugin update claude-harness
/claude-harness:setup
```

---

### v7.0.0 (2026-02-12) - Hook Compliance, Performance & Trim

**Major release**: 7 hook compliance fixes, performance optimization, and context trimming across hooks and commands.

#### Hook Compliance (feature-019)
- **SessionStart**: Added `matcher: "fresh"` to prevent double-fire on compaction
- **PreCompact**: Added `hookEventName` to hookSpecificOutput
- **Stop**: Replaced plain text echo with structured output
- **PreCompact**: Replaced emoji with text in user messages

#### Context Trimming
- **flow.md** (feature-020): 1434 → 514 lines (64% reduction). Deduplicated effort tables, loop-state schema, eliminated redundant ASCII boxes
- **session-start.sh** (feature-021): 633 → 377 lines (40% reduction). Added reusable `build_box()` function, removed Opus 4.6 capabilities section, condensed workflow listing

#### Metadata
- All hook version headers updated to v7.0.0
- Plugin version bumped to 7.0.0

---

### v6.5.1 (2026-02-10) - Performance Hotfix

**CRITICAL FIX**: Resolves 40+ minute agent hang issue in v6.5.0

#### Fixes
- **Performance**: Add 10-second timeout wrappers to all `eval` commands in hooks
  - Prevents indefinite blocking when test suites or verification commands take too long
  - Hook timeouts in hooks.json were not enforced on the actual eval commands
- **Performance**: Skip TDD validation for non-verification tasks
  - Only verify/checkpoint/review/accept tasks run TDD validation gate
  - Reduces redundant verification runs

#### Impact
- Hooks now complete in < 10 seconds (was 10+ minutes with slow test suites)
- Eliminates 40+ minute hangs reported in v6.5.0

#### Upgrade from v6.5.0
This is a critical hotfix. Users experiencing agent hangs should upgrade immediately:
```bash
/plugin update claude-harness
```

---

> **v4.1.0 Release Notes**: See [RELEASES/v4.1.0.md](./RELEASES/v4.1.0.md) for full details on auto-issue creation and GitHub integration.
> **v3.0.0 Release Notes**: See [RELEASE-NOTES-v3.0.0.md](./RELEASE-NOTES-v3.0.0.md) for full details with architecture diagrams.

| Version | Changes |
|---------|---------|
| **8.4.0** | **Schema Standardization**: Added `schemas/` directory with JSON Schema files for 5 key state files. Fixed loop-state version drift across commands. Removed hardcoded version comments from hooks. Added schema versioning convention to CLAUDE.md. |
| **8.0.0** | **Remove Agent Teams**: Direct implementation model replaces 3-specialist team orchestration. Removed SubagentStart, TeammateIdle, TaskCompleted hooks. 9→6 hook registrations. No longer requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS. |
| **7.0.0** | **Restructure repo for marketplace compatibility**: Moved plugin files into `claude-harness/` subdirectory. Fixes "not found in marketplace" install error and infinite recursion from self-referencing GitHub source. Marketplace source now `"./claude-harness"`. |
| **6.0.6** | **Fix installation instructions**: README Quick Start used invalid `github:owner/repo` syntax. Replaced with correct marketplace workflow (add marketplace → install plugin). Added terminal CLI equivalent. |
| **6.0.5** | **Remove stale cache detection**: Removed custom GitHub version-check system from `session-start.sh` (66 lines). No other Claude Code plugin does this — `claude plugin update` is sufficient. Eliminates network calls on session start and false-positive warnings. |
| **6.0.4** | **Fix stale SessionEnd hook in settings.local.json**: `SessionEnd hook [session-end.sh] failed: not found` on session exit. Stale hook entry in `settings.local.json` survived v6.0.0 consolidation because `setup.sh` skips existing files. Added cleanup step to strip stale `SessionEnd` from existing `settings.local.json`. |
| **6.0.0** | **Official Plugin Alignment + Hook Consolidation**: Commands served from plugin cache (removed command-copying from setup.sh). Deprecated `--force-commands` flag. Removed redundant hooks. Consolidated from 12 → 6 hook registrations. setup.sh now cleans up legacy command copies from target projects. Update via `claude plugin update claude-harness`. |
| **7.0.0** | **Hook Compliance, Performance & Trim**: Hook compliance fixes (SessionStart matcher, PreCompact hookEventName, stop structured output, emoji removal). Context trimming: flow.md 1434→514 lines (64%), session-start.sh 633→377 lines (40%). All hook version headers updated to v7.0.0. |
| **6.5.0** | **Acceptance Testing Phase (TDD Step 4: ACCEPT)**: Added end-to-end acceptance testing as the 4th step in the TDD cycle (RED → GREEN → REFACTOR → **ACCEPT**). After unit tests pass and code is refactored, deterministic acceptance tests verify the feature works from a user/production perspective. New `verification.acceptance` config field for project-specific E2E test commands (auto-detected for Playwright/Cypress/test:e2e/test:acceptance). Loop-state schema bumped to v7. Works in both standard and autonomous modes. `setup.sh` auto-detects E2E frameworks. |
| **6.4.1** | **Fix PreToolUse Blocking /flow State Writes**: The Edit/Write matcher in PreToolUse hook was blocking writes to `loop-state.json` and `active.json`, which `/flow` itself needs to write. Removed state file protection from the Edit/Write guard — the hook cannot distinguish between `/flow` managing its own state (legitimate) and random agent writes. Hooks self-modification prevention retained. |
| **6.4.0** | **Full Hook Coverage**: Expanded hook registrations covering all major Claude Code hook types. **NEW hooks**: (1) `PreToolUse` with dual matchers — Bash matcher blocks dangerous git commands (`push --force`, `reset --hard`, `checkout main`, `branch -D`, `clean -f`) and state destruction (`rm -rf .claude-harness`); Edit/Write matcher blocks writes to harness-managed files. (2) `PermissionRequest` — in autonomous mode, auto-approves safe operations (read-only git, feature branch commits, configured test/build/lint commands, package installs) and auto-denies destructive operations; no-op in standard mode. (3) `SessionStart` with `compact` matcher — re-injects active feature, TDD phase, and recent failures after context compaction. |
| **6.3.0** | **Interrupt Recovery**: Fixed agent getting stuck in infinite retry loop after user interrupt (Ctrl+C/Escape). The Stop hook does NOT fire on user interrupts, so interrupted sessions left `loop-state.json` in `"in_progress"` with stale references. On resume, the agent retried the same failing approach indefinitely. Fix adds 3-layer interrupt recovery: (1) `session-start.sh` detects stale sessions (dead PID) with active loops and writes a recovery marker. (2) `stop.sh` rewritten to also detect natural stops (output limits, premature stops) and write recovery markers. (3) `flow.md` resume behavior now checks for interrupt markers first, displays what was happening when interrupted, and offers 3 recovery options: FRESH APPROACH, RETRY SAME, or RESET. Autonomous mode auto-selects FRESH APPROACH. |
| **6.2.1** | **Fix Delegation Mode Loss After Context Compaction**: During `--autonomous` sessions with many features, context compaction could erase delegation instructions, causing the agent to implement features directly instead of following the intended workflow. Fix persists delegation mode to `autonomous-state.json` (schema v2) and `loop-state.json`. Backward compatible with v1 autonomous-state files (auto-migrated on resume). |
| **6.2.0** | **PRD Breakdown Analysis Migration**: Migrated `/prd-breakdown` command analysis to use parallel analysis perspectives (product, architecture, QA). Renamed `subagent-prompts.json` → `analyst-prompts.json`. |
| **6.1.0** | **Stale Plugin Cache Detection & Self-Healing**: `session-start.sh` now checks GitHub for the latest version (24h TTL cache) and shows a prominent warning if the plugin cache is outdated. New `fix-stale-cache.sh` bootstrap script downloads the latest version, replaces the stale cache, and updates `installed_plugins.json`. Fixes the self-referential version detection loop where both the cached plugin and project `.plugin-version` show the same stale version. |
| **6.0.1** | **v6 Upgrade Cleanup**: `setup.sh` now auto-cleans v5.x artifacts on upgrade — removes `worktrees/` directory, `agents/handoffs.json`, stale `worktree.md` command, and `pendingHandoffs` from context.json. Removed handoffs.json creation and all `pendingHandoffs` references from commands. |
| **5.2.0** | **Consolidated Workflow + Enforced TDD**: Merged /do, /do-tdd, and /orchestrate into unified /flow command with flags (--plan-only). TDD enforcement (Research → Implement → Review) is now part of every flow run. Auto-detects feature complexity (simple/standard/complex). Command count reduced from 8 to 5. |
| **5.1.4** | **Fix Autonomous Archive**: Passing features were not being archived during autonomous mode. Phase A.4.6 (Auto-Merge) updated status to "passing" but never moved the feature from `active.json` to `archive.json`. Added explicit archive step (new step 29) in Phase A.5 (Post-Feature Cleanup) that moves completed features to archive after merge. The normal flow Phase 6 already had this logic — autonomous mode was missing it. |
| **5.1.3** | **Dynamic Command Sync**: Replaced 5 hardcoded simplified command stubs in `setup.sh` with a dynamic copy loop that copies ALL `.md` files from the plugin's `commands/` directory. Previously 5 commands (flow, do-tdd, prd-breakdown, worktree, setup) were completely missing from target projects, and the 5 existing stubs were outdated simplified versions. Now all commands are auto-discovered, always full-version, and automatically synced on version upgrade. |
| **5.1.2** | **Fix Setup Auto-Update (v2)**: Session-start hook no longer writes `.plugin-version` on version mismatch — only `setup.sh` updates it now. This ensures `setup.sh` can detect the version gap and auto-force command file updates. Also tagged `hooks/session-end.sh` and `.claude-harness/init.sh` as updatable on version upgrade. |
| **5.1.1** | **Fix Setup Auto-Update**: `setup.sh` now auto-detects version upgrades by comparing installed `.plugin-version` against `plugin.json`. When a version change is detected, command files are automatically updated (equivalent to `--force-commands`) without requiring the flag. Fixes issue where running setup on existing projects only bumped the version file but skipped command updates. |
| **5.1.0** | **Autonomous Multi-Feature Processing**: New `--autonomous` flag on `/flow` command enables unattended batch processing of the entire feature backlog. Iterates through all active features with strict TDD enforcement (Red-Green-Refactor), automatic checkpoint (commit, push, PR), merge to main, context reset, and loop back. Git rebase conflict detection auto-skips conflicting features. Configurable termination: max iterations (20), consecutive failure threshold (3), or all features complete. Autonomous state persisted to `autonomous-state.json` for crash recovery and resume. Compatible with `--no-merge` (stop at checkpoint) and `--quick` (skip planning). Forces `--inline` mode. TDD-specific task chain (7 tasks) with visual progress tracking. |
| **5.0.0** | **Opus 4.6 Optimizations**: Effort controls per workflow phase (low for mechanical operations, max for planning/debugging) across `/flow`. 128K output token utilization for richer PRD analysis (exhaustive output, PRD size limit increased to 100KB). Increased maxAttempts from 10 to 15 for better agentic loop sustaining. Adaptive loop strategy with progressive effort escalation on retries. Native context compaction awareness in PreCompact hook. Session banner now displays Opus 4.6 capabilities. All changes backward compatible with pre-Opus 4.6 models. |
| **4.5.1** | **Fix Version Tracking & Stale State Detection**: Removed hardcoded version from `setup.md` — now reads dynamically from `plugin.json`. Fixed `setup.sh` to use `$PLUGIN_VERSION` variable everywhere instead of hardcoded strings. Added active.json validation to prevent stale loop-state from falsely reporting archived features as active. Cleaned up stale legacy `loops/state.json`. |
| **4.5.0** | **Native Claude Code Tasks Integration**: Features now create a 5-task chain using Claude Code's native Tasks system (TaskCreate, TaskUpdate, TaskList). Tasks provide visual progress tracking (`[x] Research [x] Plan [→] Implement [ ] Verify [ ] Checkpoint`), persist across sessions, and have built-in dependency management. Loop-state schema updated to v4 with task references. Backward compatible with v3 loop-state. Graceful fallback if TaskCreate fails. |
| **4.4.2** | **Fix Stop Hook Command-Type**: Converted Stop hook from prompt-type (unreliable JSON validation) to command-type shell script for reliable completion detection. |
| **4.4.1** | **Fix Stop Hook Schema**: Fixed prompt-based Stop hook schema validation error. The hook response must include `ok` boolean field for Claude Code to process it correctly. |
| **4.4.0** | **Automated End-to-End Flow**: New `/claude-harness:flow` command combines start→do→checkpoint→merge into single automated workflow. Added prompt-based `Stop` hook (Haiku LLM) for intelligent completion detection. Added `UserPromptSubmit` hook for smart routing to active loops. GitHub repo now cached in SessionStart hook (eliminates 4 redundant parses). Memory layers read in parallel for 30-40% faster startup. Streaming memory updates after each verification attempt. Commands updated to use cached GitHub repo. |
| **4.3.0** | **Enforce GitHub Issue Creation**: Made GitHub issue creation MANDATORY (not optional) for all features and fixes. Added explicit issue body templates with required sections (Problem, Solution, Acceptance Criteria, Verification). Added "MANDATORY REQUIREMENTS" section at top of `/do` command. Issues now MUST be created before any code work - failure blocks progression. Fixes context loss when issues were sometimes skipped. |
| **4.2.3** | **Remove Legacy State Files**: Removed creation of unused legacy files (`loop-state.json`, `working-context.json`, `loops/state.json`, `memory/working/`). All workflow state is now session-scoped under `sessions/{session-id}/`. Updated setup.md and start.md to reflect current architecture. Cleaned up .gitignore patterns. |
| **4.2.2** | **Fix Session Cleanup on WSL**: Moved stale session cleanup from SessionEnd hook to SessionStart hook for reliability. SessionEnd may not trigger on `/clear` or crashes, so cleanup now happens proactively when a new session starts. Removed `jq` dependency from both hooks (uses grep/sed instead). Fixes fix-feature-013-001. |
| **4.2.1** | **Removed Obsolete File References**: Cleaned up all references to legacy `feature-list.json` and `feature-archive.json` files. Fresh setups now only create `features/active.json` and `features/archive.json`. Updated migration instructions to properly move old files to new locations. |
| **4.2.0** | **Simplified /merge Command**: Removed version tagging and GitHub release creation from `/merge` command since git tag operations are not directly supported by GitHub MCP. The command now focuses on merging PRs, closing issues, and cleaning up branches. Version tagging should be done manually using git commands or GitHub's release UI. |
| **4.1.0** | **Auto-Create GitHub Issues from PRD**: New `--create-issues` flag on `/prd-breakdown` command automatically creates one GitHub issue per generated feature. Designed for explicit opt-in (not automatic) with full automation once flag is used. Issues include feature description, acceptance criteria, and priority metadata. Labeled with `feature` and `prd-generated` tags. Gracefully degrades if GitHub MCP unavailable. Enables teams to go from PRD → features → tracked backlog in one command. See [RELEASES/v4.1.0.md](./RELEASES/v4.1.0.md). |
| **4.0.0** | **PRD Analysis & Decomposition**: New `/claude-harness:prd-breakdown` command analyzes Product Requirements Documents using 3 parallel analysis perspectives (Product, Architecture, QA). Automatically decomposes PRDs into atomic features with dependencies, priorities, and acceptance criteria. Supports inline PRD, file-based, GitHub issues, or interactive input. Essential for bootstrapping feature lists in new projects. Version bumped across all files (setup.sh, plugin.json, hooks, README). See [RELEASES/v4.0.0.md](./RELEASES/v4.0.0.md). |
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
/claude-harness:start       # Uses git status, cat, grep
/claude-harness:checkpoint  # Uses git add, commit (push prompts)
/claude-harness:flow        # Uses npm run, npx tsc
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
