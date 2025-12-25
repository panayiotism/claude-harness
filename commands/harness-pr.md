---
description: Manage pull requests (create/update/status/merge)
argumentsPrompt: Action (create|update|status|merge)
---

Manage the current feature pull request:

Arguments: $ARGUMENTS (create|update|status|merge)

Requires GitHub MCP to be configured.

- create: Create PR from current branch to main
- update: Update PR description with latest progress
- status: Check PR status, reviews, CI
- merge: Merge PR if approved and CI passes, mark feature complete
