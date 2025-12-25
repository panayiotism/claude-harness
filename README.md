# Claude Code Long-Running Agent Harness

A Claude Code plugin for automated, context-preserving coding sessions with feature tracking and GitHub integration.

Based on [Anthropic's engineering article](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

## Installation

### As a Plugin (Recommended)

```bash
# Add this repo as a marketplace
claude plugin marketplace add /path/to/claude-harness

# Install the plugin
claude plugin install claude-harness@claude-harness
```

Or in Claude Code:
```
/plugin marketplace add /path/to/claude-harness
/plugin install claude-harness@claude-harness
```

### Alternative: Setup Script

```bash
cd ~/your-project
/path/to/claude-harness/setup.sh
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

# Save progress (commits, pushes, creates PR)
/harness-checkpoint
```

## Commands

| Command | Purpose |
|---------|---------|
| `/harness-setup` | Initialize harness in current project |
| `/harness-start` | Start a session - shows status, progress, pending features |
| `/harness-feature <desc>` | Add feature - creates GitHub issue + branch (if MCP configured) |
| `/harness-checkpoint` | Save progress - commits, pushes, creates/updates PR, archives completed features |
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

## Sources

- [Claude Code Plugins](https://code.claude.com/docs/en/plugins)
- [GitHub MCP Server](https://github.com/github/github-mcp-server)
- [Anthropic: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
