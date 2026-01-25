# Claude Harness Plugin

## Project Overview
Claude Code plugin for automated, context-preserving coding sessions with 5-layer memory architecture, failure prevention, self-improving skills, feature tracking, GitHub integration, and multi-agent orchestration.

## Tech Stack
- Shell/Bash (setup.sh, hooks/)
- Markdown (commands)
- JSON (configuration, state files)

## Session Startup Protocol
On every session start:
1. Run `pwd` to confirm working directory
2. Read `.claude-harness/sessions/{session-id}/context.json` for active working state (if exists)
3. Read `.claude-harness/claude-progress.json` for context
4. Run `git log --oneline -5` to see recent changes
5. Check `.claude-harness/features/active.json` for current priorities

## Project Structure
- `commands/` - Harness command definitions (markdown)
- `hooks/` - Session hooks (shell scripts)
- `.claude-plugin/` - Plugin configuration
- `setup.sh` - Installation script

## Development Rules
- Work on ONE feature at a time
- Always update `.claude-harness/claude-progress.json` after completing work
- Update version in `.claude-plugin/plugin.json` for every change
- Update changelog in `README.md`
- Commit with descriptive messages
- Leave codebase in clean, working state

## Available Commands (8 total)
- `/claude-harness:setup` - Initialize harness in project
- `/claude-harness:start` - Start session, compile context
- `/claude-harness:flow` - **End-to-end automated workflow** (recommended)
- `/claude-harness:do` - **Step-by-step workflow**: features and fixes (manual control)
- `/claude-harness:do-tdd` - **TDD workflow**: tests first, then implement
- `/claude-harness:checkpoint` - Manual commit + push + PR
- `/claude-harness:orchestrate` - Spawn multi-agent team (advanced)
- `/claude-harness:merge` - Merge all PRs, auto-version, release

## Progress Tracking
See: `.claude-harness/claude-progress.json` and `.claude-harness/features/active.json`

ALWAYS bump the version in all occurances after code change according to significanse following the semver 