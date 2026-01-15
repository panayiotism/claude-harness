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
   mkdir -p .claude-harness/memory/working
   mkdir -p .claude-harness/memory/episodic
   mkdir -p .claude-harness/memory/semantic
   mkdir -p .claude-harness/memory/procedural
   mkdir -p .claude-harness/features
   mkdir -p .claude-harness/impact
   mkdir -p .claude-harness/agents
   mkdir -p .claude-harness/loops
   ```

   **Migrate existing files:**
   - If `agent-memory.json` exists: Extract `failedApproaches` → `memory/procedural/failures.json`, `successfulApproaches` → `memory/procedural/successes.json`
   - If `working-context.json` exists: Move to `memory/working/context.json`
   - If `agent-context.json` exists: Move to `agents/context.json`
   - If `loop-state.json` exists: Move to `loops/state.json`
   - Keep `feature-list.json`, `feature-archive.json`, `claude-progress.json` in place (backward compatible)

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
│   ├── working/context.json
│   ├── episodic/decisions.json
│   ├── semantic/architecture.json
│   └── procedural/
│       ├── failures.json
│       ├── successes.json
│       └── patterns.json
├── features/
│   └── active.json
├── impact/
│   └── dependency-graph.json
├── agents/
│   └── context.json
├── loops/
│   └── state.json
├── feature-list.json (backward compat)
├── feature-archive.json
├── claude-progress.json
└── init.sh
```

**File contents - see schemas below**

## Phase 3: Update Plugin Version

Always update the plugin version tracking:
1. Read current plugin version from the installed plugin
2. Write to `.claude-harness/.plugin-version`
3. Report version recorded

## File Schemas

### memory/working/context.json
```json
{
  "computedAt": null,
  "sessionId": null,
  "activeFeature": null,
  "relevantMemory": {
    "recentDecisions": [],
    "projectPatterns": [],
    "avoidApproaches": []
  },
  "currentTask": null,
  "compilationLog": []
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

### loops/state.json
```json
{
  "version": 1,
  "feature": null,
  "status": "idle",
  "attempt": 0,
  "maxAttempts": 10,
  "history": []
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

### feature-list.json (backward compatible)
```json
{
  "version": 1,
  "features": []
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
  2. Use `/claude-harness:do "description"` to create and implement features
  3. Use `/claude-harness:do --fix feature-XXX "bug"` to create bug fixes
