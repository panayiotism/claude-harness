---
description: Start a harness session - shows status, GitHub integration, and syncs issues
---

Run the initialization script and prepare for a new coding session:

## Phase 1: Local Status

1. **Load working context** (if exists):
   - Read `working-context.json`
   - If `activeFeature` is set, display prominently:
     ```
     === Resuming Work ===
     Feature: {activeFeature} - {summary}
     Working files: {list workingFiles with roles}
     Key decisions: {list decisions}
     Next steps: {list nextSteps}
     ```
   - This orients the session before other status info

2. Execute `./init.sh` to see environment status (if it exists)

3. Read `claude-progress.json` for session context

4. Read `feature-list.json` to identify next priority
   - If the file is too large to read (>25000 tokens), use: `grep -A 5 "passes.*false" feature-list.json` to see pending features
   - Run `/claude-harness:checkpoint` to auto-archive completed features and reduce file size

5. Optionally check `feature-archive.json` to see completed feature count/history

## Phase 2: Orchestration State

6. Check orchestration state:
   - Read `agent-context.json` if it exists
   - Check for `currentSession.activeFeature` - indicates incomplete orchestration
   - Check `pendingHandoffs` array for work waiting to be continued
   - Check `agentResults` for recently completed agent work
   - If active orchestration exists, recommend: "Run `/claude-harness:orchestrate {feature-id}` to resume"

7. Check agent memory:
   - Read `agent-memory.json` if it exists
   - Report any `codebaseInsights.hotspots` that may affect current work
   - Show `agentPerformance` summary if significant history exists

## Phase 3: GitHub Integration (if MCP configured)

8. Check GitHub MCP connection status

9. Fetch and display GitHub dashboard:
   - Open issues with "feature" label
   - Open PRs from feature branches
   - CI/CD status for open PRs
   - Cross-reference with feature-list.json

10. Sync GitHub Issues with feature-list.json:
   - For each GitHub issue with "feature" label NOT in feature-list.json:
     - Add new entry with issueNumber linked
   - For each feature in feature-list.json with passes=true:
     - If linked GitHub issue is still open, close it
   - Report sync results

## Phase 4: Recommendations

11. Report session summary:
    - Current state and blockers
    - Pending features prioritized
    - GitHub sync results
    - Recommended next action:
      - If pending handoffs exist, prioritize resuming orchestration
      - If no orchestration active, recommend starting one for complex features
      - Suggest next feature to work on
