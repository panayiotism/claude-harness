# Claude Harness Plugin

## Project Overview
Claude Code plugin for automated, context-preserving coding sessions with 5-layer memory architecture, failure prevention, self-improving skills, feature tracking, and GitHub integration.

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
- `claude-harness/` - Plugin directory (what gets installed by users)
  - `commands/` - Harness command definitions (markdown, served from plugin cache)
  - `hooks/` - Session hooks (6 registrations: safety, quality gates)
  - `setup.sh` - Project initialization script (memory dirs, CLAUDE.md, migrations)
  - `.claude-plugin/plugin.json` - Plugin manifest
- `.claude-plugin/marketplace.json` - Marketplace catalog (points to `./claude-harness`)

## Development Rules
- Work on ONE feature at a time
- Always update `.claude-harness/claude-progress.json` after completing work
- Update version in both `.claude-plugin/plugin.json` and `claude-harness/.claude-plugin/plugin.json` for every change (these are the only version sources — `.plugin-version` is derived by setup.sh)
- Update changelog in `README.md`
- Do NOT add version numbers to hook `.sh` file comments — version lives only in plugin.json
- Commit with descriptive messages
- Leave codebase in clean, working state

## Available Commands (5 total)
- `/claude-harness:setup` - Initialize harness in project
- `/claude-harness:start` - Start session, compile context
- `/claude-harness:flow` - **Unified workflow** (recommended)
  - Flags: `--no-merge` `--plan-only` `--autonomous` `--quick` `--fix`
- `/claude-harness:checkpoint` - Manual commit + push + PR
- `/claude-harness:merge` - Merge all PRs, auto-version, release

## Schema Versioning Convention
- The `"version"` field in JSON state files refers to the **data schema version**, not the plugin version
- Increment schema version only when the shape of the data changes in a breaking way
- Canonical schemas live in `claude-harness/schemas/*.schema.json` — reference these, don't embed inline examples

## Progress Tracking
See: `.claude-harness/claude-progress.json` and `.claude-harness/features/active.json`

ALWAYS bump the version in all occurances after code change according to significanse following the semver

https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
