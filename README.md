# Claude Code Long-Running Agent Harness

A Claude Code plugin for automated, context-preserving coding sessions with feature tracking, GitHub integration, and **multi-agent orchestration**.

Based on [Anthropic's engineering article](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

## TL;DR - How It Works

```
/harness-feature "Add user dashboard with analytics"
```
Creates feature + GitHub issue + branch

```
/harness-orchestrate feature-001
```
Spawns specialized agents as a coordinated team:

```
┌─────────────────────────────────────────────────────────┐
│                    ORCHESTRATOR                         │
│  Analyzes task → Selects agents → Coordinates work      │
└─────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        ▼                 ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ react-        │ │ backend-      │ │ database-     │
│ specialist    │ │ developer     │ │ administrator │
│ (frontend)    │ │ (API routes)  │ │ (schema)      │
└───────────────┘ └───────────────┘ └───────────────┘
        │                 │                 │
        └─────────────────┼─────────────────┘
                          ▼
              ┌───────────────────────┐
              │    code-reviewer      │
              │  (mandatory review)   │
              └───────────────────────┘
```

**Shared Context:** `agent-context.json` - decisions, patterns, handoffs
**Persistent Memory:** `agent-memory.json` - learnings across sessions

```
/harness-checkpoint
```
Commits, pushes, creates PR, persists agent learnings to memory

## Installation

### As a Plugin (Recommended)

```bash
# Add the marketplace
claude plugin marketplace add panayiotism/claude-harness

# Install the plugin
claude plugin install claude-harness@claude-harness
```

Or in Claude Code:
```
/plugin marketplace add panayiotism/claude-harness
/plugin install claude-harness@claude-harness
```

### Alternative: Direct Install

```bash
claude plugin install claude-harness github:panayiotism/claude-harness
```

### Alternative: Local Setup Script

Clone the repo and run setup directly:

```bash
git clone https://github.com/panayiotism/claude-harness.git
cd ~/your-project
/path/to/claude-harness/setup.sh
```

### Updating

```bash
# Update plugin to latest version
claude plugin update claude-harness@claude-harness

# Re-run setup in your project to get new files (if needed)
/harness-setup
```

Note: Restart Claude Code after updating for changes to take effect.

### Uninstalling

```bash
claude plugin uninstall claude-harness@claude-harness
```

## Quick Start

After installing the plugin:

```bash
# In your project directory
claude

# Initialize harness files
/harness-setup

# Add a feature to work on
/harness-feature Add user authentication

# For complex features, spawn a multi-agent team
/harness-orchestrate feature-001

# Save progress (commits, pushes, creates PR, persists agent memory)
/harness-checkpoint
```

## Commands

| Command | Purpose |
|---------|---------|
| `/harness-setup` | Initialize harness in current project |
| `/harness-start` | Start a session - shows status, progress, pending features |
| `/harness-feature <desc>` | Add feature - creates GitHub issue + branch (if MCP configured) |
| `/harness-orchestrate <id>` | Spawn multi-agent team for complex features |
| `/harness-checkpoint` | Save progress - commits, pushes, creates/updates PR, persists agent memory |
| `/harness-pr <action>` | Manage PRs (create/update/status/merge) |
| `/harness-sync-issues` | Sync feature-list.json with GitHub Issues |
| `/harness-gh-status` | Show GitHub integration dashboard |
| `/harness-merge-all` | Merge all PRs, close issues, delete branches (dependency order) |

## What It Creates

When you run `/harness-setup`, the following files are created in your project:

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Main context file (auto-read by Claude Code) |
| `claude-progress.json` | Session continuity tracking |
| `feature-list.json` | Feature tracking with pass/fail status |
| `feature-archive.json` | Archive for completed features (auto-populated) |
| `agent-context.json` | Multi-agent shared context (decisions, handoffs) |
| `agent-memory.json` | Persistent agent memory (patterns, performance) |
| `init.sh` | Environment startup script |

## GitHub MCP Integration (Optional)

### Setup

```bash
# Easy way (interactive)
claude mcp add github -s user

# Manual way
export GITHUB_TOKEN=ghp_xxxx
claude mcp add-json github '{"command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"'$GITHUB_TOKEN'"}}'

# Verify
claude mcp list
```

### Workflow with GitHub

```
/harness-feature Add dark mode support
```
Creates:
- GitHub Issue #42 with description
- Branch `feature/feature-001`
- Entry in feature-list.json with links

```
/harness-checkpoint
```
- Commits and pushes to feature branch
- Creates/updates PR linked to issue
- Updates progress tracking
- Archives any completed features

```
/harness-pr merge
```
- Merges PR if CI passes
- Closes linked issue
- Marks feature as `passes: true`

## Multi-Agent Orchestration

For complex features, spawn a team of specialized agents that work together:

```
/harness-orchestrate feature-001
```

### How It Works

1. **Task Analysis** - Identifies domains (frontend, backend, database, etc.)
2. **Agent Selection** - Auto-picks specialists based on file types and task requirements
3. **Parallel Execution** - Independent tasks run simultaneously via Task tool
4. **Coordinated Handoffs** - Sequential tasks pass context between agents
5. **Quality Gates** - Code reviewer and security auditor run after implementation
6. **Memory Persistence** - Learnings saved for future sessions

### Available Agent Types

| Domain | Agent | Triggers |
|--------|-------|----------|
| React/Frontend | `react-specialist` | .tsx, .jsx, component |
| Backend/API | `backend-developer` | route.ts, api/, endpoint |
| Next.js | `nextjs-developer` | app/, pages/ |
| Database | `database-administrator` | prisma, schema, SQL |
| Review | `code-reviewer` | Always for code changes |
| Security | `security-auditor` | Auth, tokens, encryption |
| Testing | `qa-expert` | New features, bug fixes |

### Shared Context Schema

`agent-context.json`:
```json
{
  "currentSession": { "activeFeature": "feature-001", "activeAgents": [...] },
  "architecturalDecisions": [{ "decision": "...", "madeBy": "agent" }],
  "sharedState": { "discoveredPatterns": {...} },
  "agentResults": [{ "agent": "...", "status": "completed", "filesModified": [...] }],
  "pendingHandoffs": [{ "from": "agent-a", "to": "agent-b", "context": "..." }]
}
```

`agent-memory.json`:
```json
{
  "learnedPatterns": { "codePatterns": [...], "namingConventions": {...} },
  "successfulApproaches": [{ "task": "...", "approach": "...", "agents": [...] }],
  "agentPerformance": { "react-specialist": { "tasksCompleted": 12, "successRate": 0.95 } }
}
```

## Feature Schema

```json
{
  "id": "feature-001",
  "name": "Dark mode support",
  "description": "Add dark mode toggle to settings",
  "priority": 1,
  "passes": false,
  "verification": [
    "Toggle appears in settings",
    "Theme persists on reload",
    "All components respect theme"
  ],
  "relatedFiles": ["src/theme.ts"],
  "github": {
    "issueNumber": 42,
    "prNumber": 43,
    "branch": "feature/feature-001"
  }
}
```

## Key Principles

1. **JSON over Markdown** - Models are less likely to corrupt JSON files
2. **Single Feature Focus** - One feature per session prevents scope creep
3. **Clean Handoffs** - Every session ends in deployable state
4. **Explicit Verification** - Clear criteria for "done"
5. **Progress Persistence** - Context survives session boundaries
6. **Auto-Archiving** - Completed features archived to prevent file bloat
7. **GitHub Integration** - Issues and PRs as source of truth

## Customization

After running `/harness-setup`, edit:
- `CLAUDE.md` - Add project-specific context
- `feature-list.json` - Add your features

## .gitignore Suggestions

Add if you don't want to commit session state:
```
claude-progress.json
```

Keep committed for team sharing:
```
CLAUDE.md
feature-list.json
init.sh
```

## Contributing / Development

### Version Updates

**Always update the version when making changes to this plugin.**

1. Edit `.claude-plugin/plugin.json`:
   ```json
   {
     "version": "X.Y.Z"
   }
   ```

2. Follow semantic versioning:
   - **MAJOR (X)**: Breaking changes
   - **MINOR (Y)**: New features (e.g., adding `/orchestrate`)
   - **PATCH (Z)**: Bug fixes, documentation updates

3. Update the description if adding major features

**Current version: 1.1.1**

### Changelog

| Version | Changes |
|---------|---------|
| 1.1.1 | Fixed `/harness-setup` to create orchestration files |
| 1.1.0 | Added multi-agent orchestration (`/orchestrate`, `agent-context.json`, `agent-memory.json`) |
| 1.0.0 | Initial release with feature tracking and GitHub integration |

## Demo

See a working example: [claude-harness-demo](https://github.com/panayiotism/claude-harness-demo)

## Sources

- [Claude Code Plugins](https://code.claude.com/docs/en/plugins)
- [GitHub MCP Server](https://github.com/github/github-mcp-server)
- [Anthropic: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
