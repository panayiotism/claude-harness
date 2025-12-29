---
description: Initialize harness in current project - creates tracking files
---

Initialize the claude-harness in the current project directory.

## Phase 0: Migration Check (for upgrades from v2.1.0 or earlier)

Before creating any files, check for legacy root-level harness files:

1. Check if ANY of these files exist in the project root:
   - `feature-list.json`
   - `feature-archive.json`
   - `claude-progress.json`
   - `working-context.json`
   - `agent-context.json`
   - `agent-memory.json`

2. If legacy files exist AND `.claude-harness/` directory does NOT exist:
   - Create `.claude-harness/` directory
   - Move each existing file to `.claude-harness/`:
     - `mv feature-list.json .claude-harness/` (if exists)
     - `mv feature-archive.json .claude-harness/` (if exists)
     - `mv claude-progress.json .claude-harness/` (if exists)
     - `mv working-context.json .claude-harness/` (if exists)
     - `mv agent-context.json .claude-harness/` (if exists)
     - `mv agent-memory.json .claude-harness/` (if exists)
   - Report: "Migrated X existing harness files to .claude-harness/"

3. If legacy files exist AND `.claude-harness/` directory ALREADY exists:
   - DO NOT overwrite - the `.claude-harness/` files take precedence
   - Warn user: "Found legacy files in root that were not migrated. Please manually review and delete if no longer needed: [list files]"

4. Check if `init.sh` exists and contains old root-level paths:
   - If `init.sh` references `claude-progress.json` or `feature-list.json` (without `.claude-harness/` prefix):
     - Update `init.sh` to use `.claude-harness/` paths
     - Report: "Updated init.sh to use new .claude-harness/ paths"

5. Continue with Phase 1 (create missing files)

## Phase 1: Create Harness Files

Create the `.claude-harness/` directory if it does not exist.

Create the following files if they don't exist:

1. **.claude-harness/feature-list.json** - Feature tracking
```json
{
  "version": 1,
  "features": []
}
```

2. **.claude-harness/feature-archive.json** - Completed feature archive (auto-populated by /claude-harness:checkpoint when features have passes=true)
```json
{
  "version": 1,
  "archived": []
}
```

3. **.claude-harness/claude-progress.json** - Session continuity
```json
{
  "lastUpdated": "<current ISO timestamp>",
  "currentProject": "<directory name>",
  "lastSession": {
    "summary": "Initial harness setup",
    "completedTasks": [],
    "blockers": [],
    "nextSteps": ["Add features with /claude-harness:feature", "Use /claude-harness:orchestrate for complex features", "Use /claude-harness:checkpoint to save progress"]
  },
  "recentChanges": [],
  "knownIssues": [],
  "environmentState": {
    "devServerRunning": false,
    "lastSuccessfulBuild": null,
    "lastTypeCheck": null
  }
}
```

4. **.claude-harness/agent-context.json** - Multi-agent orchestration shared context
```json
{
  "version": 1,
  "lastUpdated": "<current ISO timestamp>",
  "currentSession": null,
  "projectContext": {
    "name": "<directory name>",
    "techStack": ["<detected tech stack>"],
    "testingFramework": null,
    "buildCommand": null,
    "testCommand": null
  },
  "architecturalDecisions": [],
  "activeConstraints": [],
  "sharedState": {
    "discoveredPatterns": {},
    "fileIndex": {
      "components": [],
      "apiRoutes": [],
      "tests": [],
      "configs": []
    }
  },
  "agentResults": [],
  "pendingHandoffs": []
}
```

5. **.claude-harness/agent-memory.json** - Multi-agent orchestration persistent memory
```json
{
  "version": 1,
  "lastUpdated": "<current ISO timestamp>",
  "learnedPatterns": {
    "codePatterns": [],
    "namingConventions": {},
    "projectSpecificRules": []
  },
  "successfulApproaches": [],
  "failedApproaches": [],
  "agentPerformance": {},
  "codebaseInsights": {
    "hotspots": [],
    "technicalDebt": []
  }
}
```

6. **.claude-harness/working-context.json** - Active working state for session continuity
```json
{
  "version": 1,
  "lastUpdated": null,
  "activeFeature": null,
  "summary": null,
  "workingFiles": {},
  "decisions": [],
  "codebaseUnderstanding": {},
  "nextSteps": []
}
```

7. **CLAUDE.md** - Project context (only if it doesn't exist)
   - Detect tech stack from package.json, requirements.txt, Cargo.toml, go.mod, etc.
   - Include session startup protocol referencing harness commands
   - Include common commands for the detected stack

8. **init.sh** - Environment startup script
```bash
#!/bin/bash
echo "=== Dev Environment Setup ==="
echo "Working directory: $(pwd)"
# Show git history, progress, pending features, orchestration state
```

After creating files, report:
- Files created vs skipped (already exist)
- Detected tech stack
- Next steps:
  1. Use /claude-harness:feature to add features to track
  2. Use /claude-harness:orchestrate to spawn multi-agent teams for complex features
  3. Use /claude-harness:checkpoint to save progress and persist agent memory

Note: This command will NOT overwrite existing files. To update commands, reinstall the plugin.
