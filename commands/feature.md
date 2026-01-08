---
description: Add a new feature - creates GitHub issue + branch (if MCP configured)
argumentsPrompt: Feature description
---

Add a new feature to .claude-harness/features/active.json and create GitHub Issue:

Arguments: $ARGUMENTS

1. Parse the feature description from arguments
2. Generate unique feature ID (feature-XXX based on existing IDs)
3. If GitHub MCP is available:
   - Create GitHub issue with:
     - Title: Feature name
     - Body: Description + verification steps checklist
     - Labels: ["feature", "claude-harness", priority label]
     - Milestone: Current or next version milestone (if exists)
   - Create feature branch: `feature/feature-XXX`
   - Checkout the feature branch

   **Labeling Standards:**
   - Priority: `priority:high`, `priority:medium`, `priority:low`
   - Type: `feature`, `enhancement`, `bugfix`, `refactor`, `docs`
   - Status: `status:in-progress`, `status:blocked`, `status:ready-for-review`
4. Add to .claude-harness/features/active.json with:
   - id, name, description, priority (default 1)
   - passes: false
   - verification: Generate reasonable verification steps (human-readable)
   - verificationCommands: Auto-detect or ask user for verification commands:
     ```json
     {
       "build": "npm run build",      // or null if not applicable
       "tests": "npm run test",       // or null
       "lint": "npm run lint",        // or null
       "typecheck": "npx tsc --noEmit", // or null
       "custom": []                   // additional verification commands
     }
     ```
   - maxAttempts: 10 (default, adjustable)
   - relatedFiles: []
   - github: { issueNumber, prNumber: null, branch }

   **Auto-Detection of Verification Commands:**
   - Check for package.json and detect available scripts (build, test, lint)
   - Check for tsconfig.json → add typecheck
   - Check for pytest.ini/.py files → use pytest
   - Check for Makefile → use make targets
   - If unknown, ask user what commands verify the feature is complete
5. Confirm creation with:
   - Feature ID
   - GitHub issue URL (if created)
   - Branch name (if created)
   - Next steps

6. Initialize orchestration context (if .claude-harness/agents/context.json exists):
   - Read `.claude-harness/agents/context.json`
   - Add the new feature to `sharedState.fileIndex` if relatedFiles are known
   - If the feature is complex (multi-domain, multiple files):
     - Recommend: "Run `/claude-harness:orchestrate {feature-id}` to spawn specialized agents"
   - Update `lastUpdated` timestamp
   - Write updated `.claude-harness/agents/context.json`
