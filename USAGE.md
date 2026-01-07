# Using Claude Harness with Existing Repos

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/panayiotism/claude-harness.git
cd claude-harness

# 2. Install claude-harness plugin (if not already installed)
# This happens automatically when you have the plugin in your Claude Code setup

# 3. Initialize harness in the repo
/claude-harness:setup

# 4. Start a session (compiles context + syncs GitHub if configured)
/claude-harness:start
```

---

## Typical Workflow for Making Changes

### 1. **Add a Feature**

```bash
/claude-harness:feature "Add user authentication to API"
```

**What this does:**
- Creates GitHub issue (if MCP configured)
- Creates feature branch `feature-XXX`
- Adds entry to `.claude-harness/feature-list.json`
- Switches to the new branch

### 2. **Plan the Feature (Optional but Recommended)**

```bash
/claude-harness:plan-feature
```

**What this does:**
- Explores codebase to understand architecture
- Creates implementation plan
- Identifies files to modify
- Gets your approval before coding

### 3. **Generate Test Cases (Before Implementation)**

```bash
/claude-harness:generate-tests
```

**What this does:**
- Creates test specifications based on feature description
- Defines success criteria
- Stored for verification later

### 4. **Implement the Feature**

```bash
/claude-harness:implement
```

**What this does:**
- Starts agentic loop that autonomously:
  - Writes code
  - Runs verification (tests, build, lint)
  - Fixes errors
  - Retries until all checks pass
- Maximum 10 attempts with automatic recovery
- Checks procedural memory to avoid failed approaches

### 5. **Checkpoint Progress**

```bash
/claude-harness:checkpoint "Completed auth middleware and tests"
```

**What this does:**
- Commits all changes with descriptive message
- Pushes branch to remote (if MCP configured)
- Creates/updates Pull Request
- Archives completed feature
- Updates progress tracking

### 6. **Merge When Ready**

```bash
/claude-harness:merge-all
```

**What this does:**
- Merges all PRs in dependency order
- Closes GitHub issues
- Deletes feature branches
- Auto-increments version

---

## Commands Reference

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/setup` | Initialize harness | First time in repo |
| `/start` | Start session | Every session start |
| `/feature` | Add new feature | Before starting work |
| `/plan-feature` | Plan implementation | Complex/unclear features |
| `/generate-tests` | Create test specs | Before coding |
| `/implement` | Auto-implement with verification | Ready to code |
| `/checkpoint` | Save progress + create PR | Work complete |
| `/fix` | Create bug fix for existing feature | Found a bug |
| `/check-approach` | Verify approach isn't known to fail | Before trying risky approach |
| `/orchestrate` | Multi-agent teams | Large/complex features |
| `/merge-all` | Merge all PRs | Ready to ship |

---

## GitHub Integration (Optional)

**Requires MCP server for GitHub:**
- Auto-creates issues for features
- Auto-creates branches
- Auto-creates/updates PRs
- Auto-merges with dependency ordering

**Without GitHub MCP:**
- Still works locally
- Manual git operations
- Feature tracking in local files
- You create PRs manually

---

## Memory System (v3.0)

The harness learns as you work:

**4 Memory Layers:**
1. **Working** - Current session context
2. **Episodic** - Decision history with timestamps
3. **Semantic** - Project architecture understanding
4. **Procedural** - What works/fails for this codebase

**Benefits:**
- Avoids repeating failed approaches
- Remembers project patterns
- Preserves context across sessions
- Faster implementation over time

---

## Example: Making Revisions

```bash
# For making revisions to an existing repo:

cd /path/to/your/clone

# Initialize (first time only)
/claude-harness:setup

# Start session
/claude-harness:start

# Add your revision as a feature
/claude-harness:feature "Update documentation for v3.0 features"

# Let it implement autonomously
/claude-harness:implement

# When done, checkpoint
/claude-harness:checkpoint "Updated docs with v3.0 memory architecture"

# Review the PR, then merge
/claude-harness:merge-all
```

---

## Key Principles

1. **One feature at a time** - Focus ensures quality
2. **Let /implement handle verification** - Don't manually test
3. **Checkpoint frequently** - Safe recovery points
4. **Check procedural memory** - Learn from past attempts
5. **Use /plan-feature for complex work** - Get alignment first

---

## Files Created

```
your-repo/
└── .claude-harness/
    ├── memory/
    │   ├── working/context.json      # Current session
    │   ├── episodic/decisions.json   # Decision history
    │   ├── semantic/architecture.json # Project structure
    │   └── procedural/               # Success/failure patterns
    ├── features/active.json          # Active features
    ├── feature-list.json             # All features
    ├── feature-archive.json          # Completed features
    └── loops/state.json              # Implementation loop state
```

---

**Ready to start?** Run `/claude-harness:start` to begin your session with the repo.
