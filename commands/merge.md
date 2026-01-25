---
description: Merge all open PRs and close related issues
argument-hint: ""
---

Merge all open PRs and close related issues:

Requires GitHub MCP to be configured.

## Phase 0: Get Repository Info

0. **Get GitHub owner/repo** (prefer cached from SessionStart):
   - First check SessionStart hook output for cached `github.owner` and `github.repo`
   - If cached values available, use them (faster, already parsed)
   - If not cached, parse from git remote:
     ```bash
     REMOTE_URL=$(git remote get-url origin 2>/dev/null)
     # SSH: git@github.com:owner/repo.git → owner, repo
     # HTTPS: https://github.com/owner/repo.git → owner, repo
     ```
   Use the owner/repo for ALL GitHub API calls in this command.

## Phase 1: Gather State

1. Gather state (using parsed owner/repo):
   - List all open PRs for this repository (includes both feature and fix PRs)
   - List all open issues with "feature" or "bugfix" labels
   - Read `.claude-harness/features/active.json`:
     - Check `features` array for linked issue/PR numbers
     - Check `fixes` array for linked issue/PR numbers

## Phase 2: Build Dependency Graph

2. Build dependency graph:
   - For each PR, check if its base branch is another feature branch (not main/master)
   - Order PRs so that dependent PRs are merged after their base PRs
   - If PR A base is PR B head branch, merge B first

## Phase 3: Pre-merge Validation

3. Pre-merge validation for each PR:
   - CI status passes
   - No merge conflicts
   - Has required approvals (if any)
   - Report any PRs that cannot be merged and why

## Phase 4: Execute Merges

4. Execute merges in dependency order:
   - Merge the PR (squash merge preferred)
   - Wait for merge to complete
   - Find and close any linked issues:
     - Check PR body for "Closes #XX" or "Fixes #XX"
     - Check `.claude-harness/features/active.json` for linked issues
   - For fix PRs:
     - Close the fix issue
     - Add comment to original feature issue: "Related fix merged: #{fix-issue} - {description}"
   - Delete the source branch (both remote and local):
     - Remote: `git push origin --delete {branch}`
     - Local: `git branch -D {branch}` (if exists)
   - Update `.claude-harness/features/active.json`:
     - For features: Set status="passing" in features array
     - For fixes: Set status="passing" in fixes array

## Phase 5: Cleanup

5. Cleanup:
   - Prune local branches: `git fetch --prune`
   - Delete local feature branches that were merged
   - Verify remote branches were deleted (list any that remain)
   - Switch to main/master branch
   - Pull latest: `git pull`

## Phase 6: Report Summary

6. Report summary:
   - PRs merged (with commit hashes)
   - Issues closed
   - Branches deleted (local and remote)
   - Any failures or skipped items

**Note**: Version tagging and GitHub releases should be managed separately using git commands or GitHub's release UI directly.
