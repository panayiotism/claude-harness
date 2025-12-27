---
description: Save session progress - commits, pushes, creates/updates PR, archives completed features
---

Create a checkpoint of the current session:

1. Update `claude-progress.json` with:
   - Summary of what was accomplished this session
   - Any blockers encountered
   - Recommended next steps
   - Update lastUpdated timestamp

2. Run build/test commands appropriate for the project

3. ALWAYS commit changes:
   - Stage all modified files (except secrets/env files)
   - Write descriptive commit message summarizing the work
   - Push to remote

4. If on a feature branch and GitHub MCP is available:
   - Check if PR exists for this branch
   - If no PR: Create PR with title, body linking to issue
   - If PR exists: Update PR description with latest progress
   - Update feature-list.json with prNumber

5. Report final status:
   - Build/test results
   - Commit hash and push status
   - PR URL (if created/updated)
   - Remaining work

6. Archive completed features (to prevent feature-list.json from growing too large):
   - Read feature-list.json
   - Find all features with passes=true
   - If any completed features exist:
     - Read feature-archive.json (create if it does not exist with {"version":1,"archived":[]})
     - Add archivedAt timestamp to each completed feature
     - Append completed features to the archived[] array
     - Write updated feature-archive.json
     - Remove completed features from feature-list.json and save
   - Report: "Archived X completed features"

7. Persist orchestration memory (if agent-context.json exists):
   - Read `agent-context.json`
   - Read `agent-memory.json` (create if missing)

   - For each entry in `agentResults`:
     - If status is "completed":
       - Add to `agent-memory.json.successfulApproaches` with:
         - task: the task description
         - approach: summary of what the agent did
         - agents: [agent name]
         - successRate: 1.0
       - Update `agent-memory.json.agentPerformance[agent]`:
         - Increment tasksCompleted
         - Update successRate
     - If status is "failed":
       - Add to `agent-memory.json.failedApproaches` with:
         - task: the task description
         - reason: failure reason
         - recordedAt: timestamp

   - If `sharedState.discoveredPatterns` has new entries:
     - Merge into `agent-memory.json.learnedPatterns`

   - If `architecturalDecisions` has entries:
     - Keep in agent-context.json (these persist across sessions)

   - Clear `agentResults` array (already persisted to memory)
   - Clear `pendingHandoffs` if all work is complete
   - Set `currentSession` to null
   - Update `lastUpdated` timestamp

   - Write updated `agent-context.json` and `agent-memory.json`
   - Report: "Persisted X agent results to memory"
