---
description: Initialize harness in current project - creates tracking files
---

Initialize or upgrade claude-harness in the current project directory.

## Auto-Detection

This command automatically detects what needs to be done:
- **Fresh install**: Creates v3.0 structure from scratch
- **v2.x upgrade**: Migrates existing files to v3.0 memory architecture
- **Cleanup**: Removes legacy command copies from `.claude/commands/` (commands are now served from plugin cache)

**Note**: Commands and hooks are served from the plugin cache. `setup.sh` only initializes project-level state (memory directories, CLAUDE.md, .gitignore, migrations).

## Phase 0: Run setup.sh (Handles ALL Cases)

`setup.sh` handles fresh installs, v2.x migrations, and cleanup in a single script. **Always run it.**

**Steps:**
1. Find the plugin root path from the session context (look for "Plugin Root:" in the session start context)
2. Run: `bash {plugin-root}/setup.sh`
   - **Fresh install**: Creates v3.0 structure, `.gitignore` patterns, CLAUDE.md
   - **v2.x migration**: Detects legacy files, migrates to v3.0 structure, then creates missing files
   - **Cleanup**: Removes stale command copies from `.claude/commands/` and legacy hooks
   - Existing project files are **NEVER overwritten** (skipped automatically)
   - `.gitignore` patterns are added if missing
   - `.plugin-version` is written from `plugin.json`
3. Report what was created vs what was skipped
4. **Skip Phase 3 and Phase 4** — `setup.sh` handles both

**Fallback**: If the plugin root path is not available in the session context, fall through to Phase 1 → Phase 4 (manual setup).

**Plugin updates**: Run `claude plugin update claude-harness` to update the plugin itself.

## Phase 3: Update Project .gitignore (FALLBACK — only if setup.sh unavailable)

**CRITICAL**: You MUST update the project's `.gitignore` to exclude harness ephemeral files. This prevents uncommitted file clutter after `/checkpoint`.

**Execute these steps:**

1. Read the current `.gitignore` file (create if missing)

2. Check if `.claude-harness/sessions/` pattern exists in the file

3. If the pattern is NOT present, append these lines to `.gitignore`:
   ```

   # Claude Harness - Ephemeral/Per-Session State
   .claude-harness/sessions/
   .claude-harness/memory/compaction-backups/

   # Claude Code - Local settings
   .claude/settings.local.json
   ```

4. Use the Edit tool to append these patterns to `.gitignore`

5. Report: "✓ Updated .gitignore with harness ephemeral patterns"

**DO NOT SKIP THIS PHASE** - it is required for proper harness operation.

## Phase 4: Verify Plugin Version (FALLBACK — only if setup.sh unavailable)

**CRITICAL**: The SessionStart hook has ALREADY written the correct plugin version to `.claude-harness/.plugin-version`. Do NOT overwrite this file with any hardcoded version.

**Steps:**
1. Read `.claude-harness/.plugin-version`
2. If the file exists and is non-empty: Report the version. **Do NOT modify it.**
3. If the file does NOT exist (fresh install only): Leave it — the next session start will write it automatically.

**WARNING**: This command definition may be cached by Claude Code. The `.plugin-version` file is always written by the SessionStart hook directly from the plugin's `plugin.json`, so it is the authoritative source. NEVER overwrite it with a version number from these instructions.

## File Schemas

Canonical schemas are defined in the plugin's `schemas/` directory (JSON Schema format). Key state files:

| File | Schema | Created By |
|------|--------|------------|
| `sessions/{id}/context.json` | `schemas/context.schema.json` (v3) | Phase 1 context compilation |
| `sessions/{id}/loop-state.json` | `schemas/loop-state.schema.json` (v8) | Phase 4 implementation |
| `sessions/{id}/autonomous-state.json` | `schemas/autonomous-state.schema.json` (v3) | `--autonomous` mode |
| `features/active.json` | `schemas/active-features.schema.json` (v3) | Phase 2 feature creation |
| `memory/procedural/failures.json` | `schemas/memory-entries.schema.json` (v3) | Verification failures |
| `memory/procedural/successes.json` | `schemas/memory-entries.schema.json` (v3) | Verification passes |

All other memory files (episodic, semantic, learned) use v3 schemas as created by `setup.sh`.

## After Setup

Report:
- What was done (fresh install / migration / version update)
- Files created or migrated
- Current plugin version
- Next steps:
  1. Run `/claude-harness:start` to compile context and sync GitHub
  2. For new projects: Run `/claude-harness:prd-breakdown @./prd.md` to analyze PRD and extract features
  3. Use `/claude-harness:flow "description"` for end-to-end automated workflow (recommended)
  4. Use `/claude-harness:flow --no-merge "description"` for step-by-step control
  5. Use `/claude-harness:flow --fix feature-XXX "bug"` to create bug fixes
