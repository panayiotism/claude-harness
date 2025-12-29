---
description: Initialize harness in current project - creates tracking files
---

Initialize the claude-harness in the current project directory.

Create the following files if they don't exist:

1. **feature-list.json** - Feature tracking
```json
{
  "version": 1,
  "features": []
}
```

2. **feature-archive.json** - Completed feature archive (auto-populated by /claude-harness:checkpoint when features have passes=true)
```json
{
  "version": 1,
  "archived": []
}
```

3. **claude-progress.json** - Session continuity
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

4. **agent-context.json** - Multi-agent orchestration shared context
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

5. **agent-memory.json** - Multi-agent orchestration persistent memory
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

6. **CLAUDE.md** - Project context (only if it doesn't exist)
   - Detect tech stack from package.json, requirements.txt, Cargo.toml, go.mod, etc.
   - Include session startup protocol referencing harness commands
   - Include common commands for the detected stack

7. **init.sh** - Environment startup script
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
