# Feature Plan: Safe Permissions Configuration

**Feature ID**: feature-011
**Status**: Planned
**Created**: 2026-01-10

## Summary

Configure Claude Code's permission system to avoid needing `--dangerously-skip-permissions` while maintaining harness functionality. This involves creating a comprehensive but safe allowlist in `settings.local.json`.

## Research Findings

### Claude Code Permission System

**Settings Scopes (precedence order):**
1. Managed (system-level, cannot be overridden)
2. Command line arguments
3. Local project (`.claude/settings.local.json` - gitignored)
4. Shared project (`.claude/settings.json` - checked in)
5. User (`~/.claude/settings.json`)

**Permission Syntax:**
```json
{
  "permissions": {
    "allow": ["Bash(npm run lint)", "Bash(git:*)"],
    "deny": ["Bash(curl:*)", "Read(.env)"],
    "ask": ["Bash(git push:*)"]
  }
}
```

**Pattern Matching:**
- `Bash(exact command)` - Exact match
- `Bash(prefix:*)` - Prefix match (wildcard at end only)
- `Bash(* suffix)` - Suffix match
- `Bash(start * end)` - Wildcards in middle
- `Read/Edit(path)` - Gitignore-style patterns

**Key Safety Features:**
- Deny rules have highest precedence
- `curl` and `wget` blocked by default
- Command injection detection enabled

### Harness Commands Analysis

Based on analyzing all command files, the harness needs these bash operations:

| Category | Commands | Used By |
|----------|----------|---------|
| **Git** | `git status`, `git add`, `git commit`, `git push`, `git checkout`, `git branch`, `git log`, `git diff`, `git stash`, `git rm` | All commands |
| **Node/NPM** | `npm run build`, `npm run test`, `npm run lint`, `npx tsc --noEmit` | implement, checkpoint, orchestrate |
| **File Ops** | `mkdir`, `mv`, `cat` (for reading JSON) | setup, start |
| **Directory** | `ls`, `pwd` | start, setup |
| **Shell Script** | Executing `./hooks/session-start.sh` | session hook |

### Safe vs Dangerous Commands

**SAFE (should allow):**
- Git operations (limited to repository)
- npm/npx for project scripts
- File operations within project
- Directory listing
- Shell scripts in `.claude-harness/`

**DANGEROUS (should deny):**
- `curl`, `wget` - Network requests (data exfiltration risk)
- `rm -rf /`, `rm -rf ~`, `rm -rf /home/*` - Destructive filesystem wipes
- `rm -r` with any system path - Recursive deletion of system directories
- `sudo` anything - Privilege escalation
- `dd`, `mkfs`, `fdisk` - Low-level disk operations
- `chmod 777 /`, `chown` on system paths - Permission changes
- Fork bombs and other DoS patterns
- Commands modifying `/etc`, `/usr`, `/var`, `/bin`, `/boot`

**ASK (prompt user):**
- `rm`, `rmdir` - Any file/directory deletion (safety net)
- `chmod`, `chown` - Permission changes
- `git push`, `git pull` - Remote operations
- `git reset`, `git revert`, `git clean` - Destructive git operations
- `npm install` - Installing new packages
- Generic `npx` - Running arbitrary packages

## Implementation Plan

### Step 1: Create Safe Allowlist

Update `.claude/settings.local.json` with:

```json
{
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git checkout:*)",
      "Bash(git branch:*)",
      "Bash(git log:*)",
      "Bash(git diff:*)",
      "Bash(git stash:*)",
      "Bash(git rm:*)",
      "Bash(git remote:*)",
      "Bash(npm run:*)",
      "Bash(npx tsc:*)",
      "Bash(npx jest:*)",
      "Bash(npx eslint:*)",
      "Bash(npx prettier:*)",
      "Bash(mkdir:*)",
      "Bash(ls:*)",
      "Bash(pwd)",
      "Bash(grep:*)",
      "Bash(cat:*)",
      "Bash(mv:*)",
      "Bash(cp:*)",
      "Bash(./hooks/*)",
      "Bash(./.claude-harness/*)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(git pull:*)",
      "Bash(git reset:*)",
      "Bash(git revert:*)",
      "Bash(git clean:*)",
      "Bash(npm install:*)",
      "Bash(npx:*)",
      "Bash(rm:*)",
      "Bash(rmdir:*)",
      "Bash(chmod:*)",
      "Bash(chown:*)"
    ],
    "deny": [
      "Bash(curl:*)",
      "Bash(wget:*)",
      "Bash(sudo:*)",
      "Bash(rm -rf /)",
      "Bash(rm -rf /*)",
      "Bash(rm -rf /home:*)",
      "Bash(rm -rf /etc:*)",
      "Bash(rm -rf /usr:*)",
      "Bash(rm -rf /var:*)",
      "Bash(rm -rf /bin:*)",
      "Bash(rm -rf /sbin:*)",
      "Bash(rm -rf /lib:*)",
      "Bash(rm -rf /boot:*)",
      "Bash(rm -rf /root:*)",
      "Bash(rm -rf /tmp:*)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf ~/:*)",
      "Bash(rm -r /)",
      "Bash(rm -r /*)",
      "Bash(rm -r /home:*)",
      "Bash(rm -r ~)",
      "Bash(rm -r ~/:*)",
      "Bash(rmdir /)",
      "Bash(rmdir /home:*)",
      "Bash(> /dev:*)",
      "Bash(dd if=:*)",
      "Bash(mkfs:*)",
      "Bash(fdisk:*)",
      "Bash(chmod 777 /:*)",
      "Bash(chown * /:*)",
      "Bash(:(){ :|:& };:)",
      "Read(.env)",
      "Read(.env.*)",
      "Read(./secrets/**)"
    ]
  }
}
```

### Step 2: Test Without --dangerously-skip-permissions

1. Run `claude` without the dangerous flag
2. Execute `/claude-harness:start`
3. Verify all harness operations work
4. Note any operations that still require permission

### Step 3: Refine Allowlist

Based on testing, add any missing safe operations to the allowlist.

### Step 4: Document in README

Add a section explaining:
- How to configure permissions safely
- What commands are auto-approved
- What commands require user confirmation
- How to extend for project-specific needs

## Files to Modify

1. `.claude/settings.local.json` - Primary allowlist
2. `README.md` - Documentation
3. `setup.sh` - Auto-configure permissions on setup

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Missing necessary command | `ask` permission prompts user |
| Overly permissive allowlist | Use specific patterns, not `*` wildcards |
| Bypass via command chaining | Claude's injection detection helps |
| User frustration with prompts | Balance safety with convenience |

## Verification Criteria

1. Harness runs without `--dangerously-skip-permissions`
2. All `/claude-harness:*` commands work
3. No dangerous commands can execute silently
4. User is prompted for potentially destructive operations
5. Documentation clearly explains the permission model

## Recommended Approach

**Conservative Start**: Begin with minimal allowlist and expand based on what fails. This ensures we don't accidentally allow dangerous operations.

**Per-Project Settings**: Use `.claude/settings.local.json` (gitignored) for personal preferences and `.claude/settings.json` (shared) for team-wide safe defaults.
