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

2. **feature-archive.json** - Completed feature archive (auto-populated by /harness-checkpoint when features have passes=true)
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
    "nextSteps": ["Add features with /harness-feature", "Use /harness-checkpoint to save progress"]
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

4. **CLAUDE.md** - Project context (only if it doesn't exist)
   - Detect tech stack from package.json, requirements.txt, Cargo.toml, go.mod, etc.
   - Include session startup protocol referencing harness commands
   - Include common commands for the detected stack

5. **init.sh** - Environment startup script
```bash
#!/bin/bash
echo "=== Dev Environment Setup ==="
echo "Working directory: $(pwd)"
# Show git history, progress, pending features
```

After creating files, report:
- Files created vs skipped (already exist)
- Detected tech stack
- Next steps: use /harness-feature to add features

Note: This command will NOT overwrite existing files. To update commands, reinstall the plugin.
