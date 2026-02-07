---
description: Initialize harness in current project - creates tracking files
---

Initialize or upgrade claude-harness in the current project directory.

## Auto-Detection

This command automatically detects what needs to be done:
- **Fresh install**: Creates v3.0 structure from scratch
- **v2.x upgrade**: Migrates existing files to v3.0 memory architecture
- **Update**: Refreshes plugin version tracking

## Phase 0: Run setup.sh (Handles ALL Cases)

`setup.sh` handles fresh installs, v2.x migrations, and upgrades in a single script. **Always run it.**

**Steps:**
1. Find the plugin root path from the session context (look for "Plugin Root:" in the session start context)
2. Run: `bash {plugin-root}/setup.sh`
   - **Fresh install**: Creates full v3.0 structure, `.claude/commands/`, `.gitignore` patterns, CLAUDE.md, everything
   - **v2.x migration**: Detects legacy files, migrates to v3.0 structure, then creates missing files
   - **Upgrade**: Detects version change, updates command files, creates any new files from current version
   - Existing project files are **NEVER overwritten** (skipped automatically)
   - `.gitignore` patterns are added if missing
   - `.plugin-version` is written from `plugin.json`
3. Report what was created vs what was skipped
4. **Skip Phase 3 and Phase 4** — `setup.sh` handles both

**Fallback**: If the plugin root path is not available in the session context, fall through to Phase 1 → Phase 4 (manual setup).

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

### sessions/{session-id}/context.json (created at runtime)
```json
{
  "version": 3,
  "computedAt": null,
  "sessionId": null,
  "activeFeature": null,
  "relevantMemory": {
    "recentDecisions": [],
    "projectPatterns": [],
    "avoidApproaches": [],
    "learnedRules": []
  },
  "currentTask": null,
  "compilationLog": []
}
```

### sessions/{session-id}/loop-state.json (created at runtime)
```json
{
  "version": 3,
  "feature": null,
  "featureName": null,
  "type": "feature",
  "linkedTo": null,
  "status": "idle",
  "attempt": 0,
  "maxAttempts": 15,
  "startedAt": null,
  "lastAttemptAt": null,
  "verification": {},
  "history": []
}
```

### memory/episodic/decisions.json
```json
{
  "maxEntries": 50,
  "entries": []
}
```

### memory/semantic/architecture.json
```json
{
  "projectType": null,
  "techStack": {},
  "structure": {
    "entryPoints": [],
    "components": [],
    "api": [],
    "tests": []
  },
  "patterns": {},
  "discoveredAt": "<current timestamp>",
  "lastUpdated": "<current timestamp>"
}
```

### memory/procedural/failures.json
```json
{
  "entries": []
}
```

### memory/procedural/successes.json
```json
{
  "entries": []
}
```

### features/active.json
```json
{
  "features": []
}
```


### agents/context.json
```json
{
  "version": 1,
  "currentSession": null,
  "agentResults": []
}
```

### claude-progress.json
```json
{
  "lastUpdated": "<current timestamp>",
  "currentProject": "<directory name>",
  "lastSession": {
    "summary": "Initial harness setup",
    "completedTasks": [],
    "blockers": [],
    "nextSteps": ["Run /claude-harness:start to begin"]
  }
}
```

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
