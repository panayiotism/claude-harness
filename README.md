# Claude Code Long-Running Agent Harness

A reusable setup for automated, context-preserving coding sessions with Claude Code, featuring full GitHub integration.

Based on [Anthropic's engineering article](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

## Quick Start

```bash
# Run directly in any repo
cd ~/your-project
/path/to/claude-harness/setup.sh

# Or copy and run
cp /path/to/claude-harness/setup.sh ~/your-project/
./setup.sh
```

## What It Creates

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Main context file (auto-read by Claude Code) |
| `claude-progress.json` | Session continuity tracking |
| `feature-list.json` | Feature tracking with pass/fail status |
| `init.sh` | Environment startup script |
| `.claude/settings.local.json` | Permissions for automation |
| `.claude/commands/*.md` | Slash commands (see below) |

## Commands

| Command | Purpose |
|---------|---------|
| `/start` | Start a session - shows status, progress, pending features |
| `/feature <desc>` | Add feature - creates GitHub issue + branch (if MCP configured) |
| `/checkpoint` | Save progress - commits, pushes, creates/updates PR |
| `/pr <action>` | Manage PRs (create/update/status/merge) |
| `/sync-issues` | Sync feature-list.json with GitHub Issues |
| `/gh-status` | Show GitHub integration dashboard |

## GitHub MCP Integration

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
/feature Add dark mode support
```
Creates:
- GitHub Issue #42 with description
- Branch `feature/feature-001`
- Entry in feature-list.json with links

```
/checkpoint
```
- Commits and pushes to feature branch
- Creates/updates PR linked to issue
- Updates progress tracking

```
/pr merge
```
- Merges PR if CI passes
- Closes linked issue
- Marks feature as `passes: true`

```
/sync-issues
```
- Imports issues created by teammates
- Updates status of existing features

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
6. **GitHub Integration** - Issues and PRs as source of truth

## Customization

After running setup, edit:
- `CLAUDE.md` - Add project-specific context
- `.claude/settings.local.json` - Add tool permissions
- `feature-list.json` - Add your features

## .gitignore Suggestions

Add if you don't want to commit session state:
```
claude-progress.json
.claude/settings.local.json
```

Keep committed for team sharing:
```
CLAUDE.md
feature-list.json
init.sh
.claude/commands/
```

## Sources

- [GitHub MCP Server](https://github.com/github/github-mcp-server)
- [Anthropic: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Adding MCP Servers to Claude Code](https://mcpcat.io/guides/adding-an-mcp-server-to-claude-code/)
