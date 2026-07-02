---
name: merge
description: Merge all open pull requests, close linked issues, delete feature branches, and clean up local and remote refs. Use when completing features, merging PRs after review, or finalizing a release cycle.
allowed-tools: "Bash(git *), Bash(gh *)"
disable-model-invocation: true
---

# Merge - Merge PRs, Close Issues, Clean Up Branches

Merge all open PRs and close related issues. Requires the `gh` CLI to be authenticated (`gh auth status`).

## Phase 0: Get Repository Info

0. **Get GitHub owner/repo**: use the cached values from the session context (injected at SessionStart). Only if absent, parse once from `git remote get-url origin` (SSH: `git@github.com:owner/repo.git`, HTTPS: `https://github.com/owner/repo.git`). Use the owner/repo for ALL GitHub calls in this command.

## Phase 1: Gather State

1. Gather state:
   - List all open PRs: `gh pr list --json number,title,headRefName,baseRefName,url,body`
   - List all open issues with "feature" or "bugfix" labels: `gh issue list --label feature --label bugfix --json number,title`
   - Read `.claude-harness/features/active.json`:
     - Check `features` array for linked issue/PR numbers
     - Check `fixes` array for linked issue/PR numbers

## Phase 2: Build Dependency Graph

2. Build dependency graph:
   - For each PR, check if its base branch is another feature branch (not main/master)
   - Order PRs so that dependent PRs are merged after their base PRs
   - If PR A base is PR B head branch, merge B first

## Phase 3: Pre-merge Validation

3. Pre-merge validation for each PR (`gh pr view {number} --json state,mergeable,reviewDecision,statusCheckRollup`):
   - CI status passes
   - No merge conflicts
   - Has required approvals (if any)
   - Report any PRs that cannot be merged and why

## Phase 4: Execute Merges

4. Execute merges in dependency order:
   - Merge the PR: `gh pr merge {number} --squash --delete-branch`
     (`--delete-branch` removes the remote branch and, when the repo is checked out on it, moves you back to the default branch)
   - Find and close any linked issues:
     - Check PR body for "Closes #XX" or "Fixes #XX" (these auto-close on merge)
     - Check `.claude-harness/features/active.json` for linked issues; close stragglers with `gh issue close {number}`
   - For fix PRs:
     - Close the fix issue
     - Add comment to original feature issue: `gh issue comment {number} --body "Related fix merged: #{fix-issue} - {description}"`
   - Delete the local branch if it remains: `git branch -d {branch}` (safe delete)
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
