# Claude Harness Plugin

## Project Overview
Claude Code plugin for automated, context-preserving coding sessions with 5-layer memory architecture, failure prevention, self-improving skills, feature tracking, GitHub integration, Agent Teams with ATDD (Acceptance Test-Driven Development), and quality gate hooks.

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
- `commands/` - Harness command definitions (markdown, served from plugin cache)
- `hooks/` - Session hooks (9 registrations, extensionless scripts with `run-hook.cmd` polyglot wrapper)
- `schemas/` - Canonical JSON Schema files for state file validation
- `setup.sh` - Project initialization script (memory dirs, CLAUDE.md, migrations)
- `.claude-plugin/plugin.json` - Plugin manifest
- Marketplace lives in separate repo: `panayiotism/claude-harness-marketplace`
- Updates tracked by git commit SHA (no semver in plugin.json) — GitHub Actions syncs to marketplace on every push

## Development Rules
- Work on ONE feature at a time
- Always update `.claude-harness/claude-progress.json` after completing work
- Update changelog in `README.md`
- Commit with descriptive messages
- Leave codebase in clean, working state

## Available Commands (6 total)
- `/claude-harness:setup` - Initialize harness in project
- `/claude-harness:start` - Start session, compile context
- `/claude-harness:flow` - **Unified workflow** (recommended)
  - Flags: `--no-merge` `--plan-only` `--autonomous` `--quick` `--fix` `--team`
- `/claude-harness:checkpoint` - Manual commit + push + PR
- `/claude-harness:merge` - Merge all PRs, auto-version, release
- `/claude-harness:prd-breakdown` - Analyze PRD and break down into features with Gherkin acceptance criteria

## Schema Versioning Convention
- The `"version"` field in JSON state files refers to the **data schema version**, not the plugin version
- Increment schema version only when the shape of the data changes in a breaking way
- Canonical schemas live in `schemas/*.schema.json` — reference these, don't embed inline examples

## Progress Tracking
See: `.claude-harness/claude-progress.json` and `.claude-harness/features/active.json`

https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
