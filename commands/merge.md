---
description: Merge all PRs, auto-version, create release
argumentsPrompt: Optional: specific version tag (e.g., v1.2.0). Defaults to auto-versioning.
---

Merge all open PRs, close related issues, create version tag and release:

Arguments: $ARGUMENTS (optional - specific version like v1.2.0, defaults to auto-versioning)

Requires GitHub MCP to be configured.

## Phase 1: Gather State

1. Gather state:
   - List all open PRs for this repository (includes both feature and fix PRs)
   - List all open issues with "feature" or "bugfix" labels
   - Read `.claude-harness/features/active.json`:
     - Check `features` array for linked issue/PR numbers
     - Check `fixes` array for linked issue/PR numbers
   - Get latest version tag from git: `git describe --tags --abbrev=0`

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
   - Delete the source branch
   - Update `.claude-harness/features/active.json`:
     - For features: Set status="passing" in features array
     - For fixes: Set status="passing" in fixes array

## Phase 5: Version Tagging

5. Create version tag (auto-versioning is the default):
   - If no arguments or 'auto': Calculate next version based on PR types:
     - Any PR with `feat:` or `feature` label → bump MINOR
     - Only `fix:` PRs → bump PATCH
     - Any PR with `BREAKING CHANGE` → bump MAJOR
   - If specific version provided: Use that version
   - Create annotated git tag: `git tag -a vX.Y.Z -m "Release vX.Y.Z"`
   - Push tag: `git push origin vX.Y.Z`

## Phase 6: Release Notes

6. Generate release notes (if version tagged):
   - Create GitHub release with:
     - Tag: vX.Y.Z
     - Title: "Release vX.Y.Z"
     - Body: Auto-generated from merged PRs:
       ```
       ## What's Changed

       ### Features
       - PR title (#XX) @author

       ### Bug Fixes
       - PR title (#XX) @author

       ### Other Changes
       - PR title (#XX) @author

       **Full Changelog**: compare link
       ```

## Phase 7: Cleanup

7. Cleanup:
   - Prune local branches: `git fetch --prune`
   - Delete local feature branches that were merged
   - Switch to main/master branch
   - Pull latest: `git pull`

## Phase 8: Report Summary

8. Report summary:
   - PRs merged (with commit hashes)
   - Issues closed
   - Branches deleted
   - Version tag created (if any)
   - Release URL (if created)
   - Any failures or skipped items

**Semantic Versioning:**
- MAJOR: Breaking changes (incompatible API changes)
- MINOR: New features (backward compatible)
- PATCH: Bug fixes (backward compatible)
