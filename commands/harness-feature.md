---
description: Add a new feature - creates GitHub issue + branch (if MCP configured)
argumentsPrompt: Feature description
---

Add a new feature to feature-list.json and create GitHub Issue:

Arguments: $ARGUMENTS

1. Parse the feature description from arguments
2. Generate unique feature ID (feature-XXX based on existing IDs)
3. If GitHub MCP is available:
   - Create GitHub issue with:
     - Title: Feature name
     - Body: Description + verification steps checklist
     - Labels: ["feature", "claude-harness"]
   - Create feature branch: `feature/feature-XXX`
   - Checkout the feature branch
4. Add to feature-list.json with:
   - id, name, description, priority (default 1)
   - passes: false
   - verification: Generate reasonable verification steps
   - relatedFiles: []
   - github: { issueNumber, prNumber: null, branch }
5. Confirm creation with:
   - Feature ID
   - GitHub issue URL (if created)
   - Branch name (if created)
   - Next steps

6. Initialize orchestration context (if agent-context.json exists):
   - Read `agent-context.json`
   - Add the new feature to `sharedState.fileIndex` if relatedFiles are known
   - If the feature is complex (multi-domain, multiple files):
     - Recommend: "Run `/harness-orchestrate {feature-id}` to spawn specialized agents"
   - Update `lastUpdated` timestamp
   - Write updated `agent-context.json`
