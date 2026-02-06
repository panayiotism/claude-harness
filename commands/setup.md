---
description: Initialize harness in current project - creates tracking files
---

Initialize or upgrade claude-harness in the current project directory.

## Auto-Detection

This command automatically detects what needs to be done:
- **Fresh install**: Creates v3.0 structure from scratch
- **v2.x upgrade**: Migrates existing files to v3.0 memory architecture
- **Update**: Refreshes plugin version tracking

## Phase 0: Version Detection

1. Check if `.claude-harness/memory/` directory exists:
   - If YES: Already v3.0, skip to Phase 3 (update version)
   - If NO: Continue to Phase 1

## Phase 1: Migration from v2.x (if applicable)

Check for existing v2.x harness structure:

1. If `.claude-harness/` exists BUT `.claude-harness/memory/` does NOT exist:
   - This is a v2.x installation, migrate it:

   **Create v3.0 directory structure:**
   ```bash
   mkdir -p .claude-harness/memory/episodic
   mkdir -p .claude-harness/memory/semantic
   mkdir -p .claude-harness/memory/procedural
   mkdir -p .claude-harness/memory/learned
   mkdir -p .claude-harness/features
   mkdir -p .claude-harness/impact
   mkdir -p .claude-harness/agents
   mkdir -p .claude-harness/sessions
   ```

   **Migrate existing files:**
   - If `agent-memory.json` exists: Extract `failedApproaches` → `memory/procedural/failures.json`, `successfulApproaches` → `memory/procedural/successes.json`
   - If `agent-context.json` exists: Move to `agents/context.json`
   - If `feature-list.json` exists: Move to `features/active.json`
   - If `feature-archive.json` exists: Move to `features/archive.json`
   - Keep `claude-progress.json` in place (still used)
   - Delete legacy files (no longer used in v4.x): `working-context.json`, `loop-state.json`

   **Create memory layer files:**
   - `memory/episodic/decisions.json` with empty entries array
   - `memory/semantic/architecture.json` with project structure
   - `memory/procedural/patterns.json` with empty entries

   **Create marker file:**
   - Write `3.0.0` to `.claude-harness/.migrated-from-v2`

   Report: "Migrated v2.x to v3.0 Memory Architecture"

2. Check for legacy root-level files (v2.1.0 or earlier):
   - If `feature-list.json`, `claude-progress.json`, etc. exist in project root:
   - Move them to `.claude-harness/` first, then apply v3.0 migration

## Phase 2: Fresh v3.0 Installation

If no `.claude-harness/` directory exists, create full v3.0 structure:

**Directory structure:**
```
.claude-harness/
├── memory/
│   ├── episodic/decisions.json       (persistent - rolling window of decisions)
│   ├── semantic/
│   │   ├── architecture.json
│   │   ├── entities.json
│   │   └── constraints.json
│   ├── procedural/
│   │   ├── failures.json
│   │   ├── successes.json
│   │   └── patterns.json
│   ├── learned/
│   │   └── rules.json
│   └── compaction-backups/           (gitignored)
├── features/
│   ├── active.json                   (feature tracking)
│   └── archive.json                  (completed features)
├── agents/
│   └── context.json                  (orchestration state)
├── impact/
│   └── dependency-graph.json
├── prd/
│   └── subagent-prompts.json
├── sessions/                         (gitignored - per-session state)
├── .plugin-version
├── claude-progress.json
└── init.sh
```

## Session-Scoped State (Created at Runtime)

The following files are **session-specific** and **created at runtime** by the SessionStart hook when you run `/claude-harness:start`. They are **gitignored** and ephemeral:

- `.claude-harness/sessions/{session-id}/`
  - `session.json` - Session metadata (start time, branch, context)
  - `context.json` - Working context (no longer in `memory/working/`)
  - `loop-state.json` - Agentic loop state (no longer in `loops/`)

These files enable **parallel development**: multiple `/start` commands in different worktrees each get their own isolated session state without conflicts.

## Phase 3: Update Project .gitignore (MANDATORY)

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

## Phase 4: Update Plugin Version

**CRITICAL**: Write the correct plugin version - do NOT use schema versions (like 3.0.0).

**The current plugin version is: 4.5.0**

Steps:
1. Write `4.5.0` to `.claude-harness/.plugin-version`
2. Report: "Plugin version: 4.5.0"

**Note for maintainers**: Update this version number in setup.md whenever plugin.json version changes.

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
  "maxAttempts": 10,
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
  "agentResults": [],
  "pendingHandoffs": []
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
  4. Use `/claude-harness:do "description"` for step-by-step control
  5. Use `/claude-harness:do --fix feature-XXX "bug"` to create bug fixes
