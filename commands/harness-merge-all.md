---
description: Merge all PRs, close issues, delete branches (dependency order)
---

Merge all open PRs, close related issues, and delete branches in dependency order:

Requires GitHub MCP to be configured.

1. Gather state:
   - List all open PRs for this repository
   - List all open issues with "feature" label
   - Read feature-list.json for linked issue/PR numbers

2. Build dependency graph:
   - For each PR, check if its base branch is another feature branch (not main/master)
   - Order PRs so that dependent PRs are merged after their base PRs
   - If PR A base is PR B head branch, merge B first

3. Pre-merge validation for each PR:
   - CI status passes
   - No merge conflicts
   - Has required approvals (if any)
   - Report any PRs that cannot be merged and why

4. Execute merges in dependency order:
   - Merge the PR (squash merge preferred)
   - Wait for merge to complete
   - Find and close any linked issues (from PR body or feature-list.json)
   - Delete the source branch
   - Update feature-list.json: set passes=true for related feature

5. Cleanup:
   - Prune local branches: `git fetch --prune`
   - Delete local feature branches that were merged
   - Switch to main/master branch

6. Report summary:
   - PRs merged (with commit hashes)
   - Issues closed
   - Branches deleted
   - Any failures or skipped items
