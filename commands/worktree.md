---
description: Manage git worktrees for parallel feature development
argument-hint: create|list|remove [FEATURE-ID]
---

Manage git worktrees for parallel Claude Code sessions. Each feature can have its own isolated working directory.

## Subcommands

### `/claude-harness:worktree create FEATURE-ID [--setup]`

Create a worktree for an existing feature.

**Arguments**:
- `FEATURE-ID`: The feature ID (e.g., `feature-014`)
- `--setup`: Run environment setup after creation (default: true)

**Workflow**:

```
Phase 1: Validation
1. Read .claude-harness/features/active.json
2. Find feature by ID - error if not found
3. Get branch name from feature.github.branch (or construct as feature/{id})
4. Run: git worktree list --porcelain
5. Verify branch not already checked out in another worktree
6. Calculate worktree path:
   - Get repo name from current directory (basename of $(pwd))
   - Path: ../{repo-name}-{feature-id}/
7. Verify path doesn't already exist

Phase 2: Create Worktree
8. Determine if branch exists:
   - Run: git branch --list {branch}
   - If exists: git worktree add <path> <branch>
   - If not exists: git worktree add -b <branch> <path> origin/main
9. If command fails, report error and abort

Phase 3: Initialize Harness in Worktree
10. Create .claude-harness/ directory in worktree (if not exists)
11. Create sessions/ directory for session-scoped state
12. DO NOT copy features/ or memory/ - these are read from main repo

Phase 4: Environment Setup (unless --no-setup)
13. Copy environment files from main repo to worktree:
    - .env (if exists)
    - .env.local (if exists)
    - .env.development.local (if exists)
    - .claude/settings.local.json (if exists)
14. Detect project type and run package manager:
    - If package.json exists: npm install
    - If requirements.txt exists: pip install -r requirements.txt
    - If Cargo.toml exists: cargo build
    - If go.mod exists: go mod download
15. Report setup progress

Phase 5: Register Worktree
16. Read .claude-harness/worktrees/registry.json (create if missing):
    ```json
    {
      "version": 1,
      "worktrees": []
    }
    ```
17. Add entry:
    ```json
    {
      "featureId": "{feature-id}",
      "branch": "{branch-name}",
      "path": "{relative-path}",
      "createdAt": "{ISO timestamp}",
      "status": "active"
    }
    ```
18. Write updated registry

Phase 6: Report Success
19. Display:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ WORKTREE CREATED                                            │
    ├─────────────────────────────────────────────────────────────────┤
    │  Feature: {feature-id}                                          │
    │  Name: {feature name}                                           │
    │  Branch: {branch}                                               │
    │  Path: {path}                                                   │
    ├─────────────────────────────────────────────────────────────────┤
    │  Environment: {setup status}                                    │
    ├─────────────────────────────────────────────────────────────────┤
    │  🎯 NEXT STEPS:                                                 │
    │                                                                 │
    │  1. Open new terminal                                           │
    │  2. cd {path}                                                   │
    │  3. claude                                                      │
    │  4. /claude-harness:do {feature-id}                             │
    └─────────────────────────────────────────────────────────────────┘
    ```
```

### `/claude-harness:worktree list`

Show all worktrees and their status.

**Workflow**:

```
Phase 1: Get Git Worktree Info
1. Run: git worktree list --porcelain
2. Parse output to get all worktrees with paths and branches

Phase 2: Get Registry Info
3. Read .claude-harness/worktrees/registry.json
4. Cross-reference with git worktree list

Phase 3: Check Status
5. For each registered worktree:
   - Verify path still exists
   - Check if branch is merged to main
   - Mark as "active", "stale", or "merged"

Phase 4: Display
6. Show formatted table:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  GIT WORKTREES                                                  │
    ├─────────────────────────────────────────────────────────────────┤
    │  Feature       Branch                   Path            Status  │
    │  ─────────────────────────────────────────────────────────────  │
    │  (main)        main                     .               active  │
    │  feature-014   feature/feature-014      ../proj-014     active  │
    │  feature-015   feature/feature-015      ../proj-015     merged  │
    ├─────────────────────────────────────────────────────────────────┤
    │  Merged worktrees can be removed:                               │
    │  /claude-harness:worktree remove feature-015                    │
    └─────────────────────────────────────────────────────────────────┘
    ```
```

### `/claude-harness:worktree remove FEATURE-ID [--force]`

Remove a worktree and clean up.

**Arguments**:
- `FEATURE-ID`: The feature ID to remove
- `--force`: Remove even if branch not merged or has uncommitted changes

**Workflow**:

```
Phase 1: Validation
1. Read .claude-harness/worktrees/registry.json
2. Find entry by feature ID - error if not found
3. Verify we're NOT currently in that worktree (can't remove self)
4. Get worktree path from registry

Phase 2: Safety Checks (unless --force)
5. Check for uncommitted changes in worktree:
   - Run: git -C <path> status --porcelain
   - If changes exist, warn and abort (suggest --force)
6. Check if branch is merged:
   - Run: git branch --merged main | grep {branch}
   - If not merged, warn user (but allow with confirmation)

Phase 3: Remove Worktree
7. Run: git worktree remove <path>
8. If fails and --force specified: git worktree remove --force <path>

Phase 4: Clean Up Branch (optional)
9. If branch was merged to main:
   - Prompt: "Delete local branch {branch}? [y/N]"
   - If yes: git branch -d {branch}

Phase 5: Update Registry
10. Remove entry from worktrees/registry.json
11. Write updated file

Phase 6: Report
12. Display success:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ WORKTREE REMOVED                                            │
    ├─────────────────────────────────────────────────────────────────┤
    │  Feature: {feature-id}                                          │
    │  Path: {path} (deleted)                                         │
    │  Branch: {branch} (kept/deleted)                                │
    └─────────────────────────────────────────────────────────────────┘
    ```
```

### `/claude-harness:worktree prune`

Clean up stale worktree references.

**Workflow**:

```
1. Run: git worktree prune
2. Read registry and remove entries where path no longer exists
3. Report cleaned entries
```

## Worktree State Strategy

**Main repo contains (shared)**:
- `.claude-harness/features/active.json` - Feature registry
- `.claude-harness/features/archive.json` - Archived features
- `.claude-harness/memory/` - All memory layers
- `.claude-harness/worktrees/registry.json` - Worktree tracking

**Worktree contains (isolated)**:
- `.claude-harness/sessions/{uuid}/` - Session-specific state
- `.claude-harness/loops/state.json` - Current loop state (if not using sessions/)

**Reading shared state from worktree**:
When running in a worktree, commands should:
1. Detect worktree mode: `git rev-parse --git-common-dir`
2. Find main repo: Extract path from git-common-dir
3. Read shared state from main repo's `.claude-harness/`
4. Write session state locally

## Environment Setup Details

### Files to Copy
These files are typically gitignored but needed for development:
- `.env` - Environment variables
- `.env.local` - Local overrides
- `.env.development.local` - Development-specific
- `.claude/settings.local.json` - Personal Claude settings

### Package Managers
Detect and run appropriate installer:

| Indicator | Command |
|-----------|---------|
| `package.json` | `npm install` |
| `yarn.lock` | `yarn install` |
| `pnpm-lock.yaml` | `pnpm install` |
| `requirements.txt` | `pip install -r requirements.txt` |
| `Pipfile` | `pipenv install` |
| `pyproject.toml` | `pip install -e .` or `poetry install` |
| `Cargo.toml` | `cargo build` |
| `go.mod` | `go mod download` |
| `Gemfile` | `bundle install` |

## Error Handling

### Branch Already Checked Out
```
Error: Branch 'feature/feature-014' is already checked out at '/path/to/worktree'
Either remove that worktree first or work in it directly.
```

### Path Already Exists
```
Error: Path '../project-feature-014' already exists.
Remove it manually or choose a different feature.
```

### Not in a Git Repository
```
Error: Not in a git repository. Worktrees require git.
```
