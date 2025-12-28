# Claude Harness Plugin

## Project Overview
Claude Code plugin for automated, context-preserving coding sessions with feature tracking, GitHub integration, and multi-agent orchestration.

## Tech Stack
- Shell/Bash (setup.sh, init.sh)
- Markdown (commands, templates)
- JSON (configuration, state files)

## Session Startup Protocol
On every session start:
1. Run `pwd` to confirm working directory
2. Read `claude-progress.json` for context
3. Run `git log --oneline -5` to see recent changes
4. Check `feature-list.json` for current priorities

## Project Structure
- `commands/` - Harness command definitions (markdown)
- `templates/` - Template files for harness setup
- `.claude-plugin/` - Plugin configuration
- `setup.sh` - Installation script

## Development Rules
- Work on ONE feature at a time
- Always update `claude-progress.json` after completing work
- Update version in `.claude-plugin/plugin.json` for every change
- Update changelog in `README.md`
- Commit with descriptive messages
- Leave codebase in clean, working state

## Available Commands
- `/claude-harness:harness-setup` - Initialize harness in project
- `/claude-harness:harness-start` - Start session with GitHub dashboard
- `/claude-harness:harness-feature` - Add new feature
- `/claude-harness:harness-orchestrate` - Spawn multi-agent team
- `/claude-harness:harness-checkpoint` - Save progress, create PR
- `/claude-harness:harness-merge-all` - Merge all PRs with auto-versioning

## Progress Tracking
See: `claude-progress.json` and `feature-list.json`
