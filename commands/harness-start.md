---
description: Start a harness session - shows status, progress, and pending features
---

Run the initialization script and prepare for a new coding session:

1. Execute `./init.sh` to see environment status (if it exists)
2. Read `claude-progress.json` for session context
3. Read `feature-list.json` to identify next priority
   - If the file is too large to read (>25000 tokens), use: `grep -A 5 "passes.*false" feature-list.json` to see pending features
   - Run `/harness-checkpoint` to auto-archive completed features and reduce file size
4. Optionally check `feature-archive.json` to see completed feature count/history
5. Report: current state, blockers, recommended next action
