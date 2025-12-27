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

5. Check orchestration state:
   - Read `agent-context.json` if it exists
   - Check for `currentSession.activeFeature` - indicates incomplete orchestration
   - Check `pendingHandoffs` array for work waiting to be continued
   - Check `agentResults` for recently completed agent work
   - If active orchestration exists, recommend: "Run `/harness-orchestrate {feature-id}` to resume"

6. Check agent memory:
   - Read `agent-memory.json` if it exists
   - Report any `codebaseInsights.hotspots` that may affect current work
   - Show `agentPerformance` summary if significant history exists

7. Report: current state, blockers, recommended next action
   - If pending handoffs exist, prioritize resuming orchestration
   - If no orchestration active, recommend starting one for complex features
