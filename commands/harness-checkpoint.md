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
