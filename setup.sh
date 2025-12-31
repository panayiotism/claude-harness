#!/bin/bash
# Claude Code Long-Running Agent Harness Setup
# Based on: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
#
# Usage:
#   curl -sL <url> | bash                    # New repo (interactive)
#   ./setup.sh                  # Run locally (skip existing files)
#   ./setup.sh --force          # Overwrite ALL files (use with caution)
#   ./setup.sh --force-commands # Update commands only, preserve project files

set -e

FORCE=false
FORCE_COMMANDS=false

case "$1" in
    --force)
        FORCE=true
        ;;
    --force-commands)
        FORCE_COMMANDS=true
        ;;
esac

echo "=== Claude Code Agent Harness Setup ==="
echo ""

# Detect project info
detect_project_info() {
    PROJECT_NAME=$(basename "$(pwd)")
    TECH_STACK=""
    SCRIPTS=""

    # Detect tech stack
    if [ -f "package.json" ]; then
        if grep -q "next" package.json 2>/dev/null; then
            TECH_STACK="Next.js"
        elif grep -q "react" package.json 2>/dev/null; then
            TECH_STACK="React"
        elif grep -q "vue" package.json 2>/dev/null; then
            TECH_STACK="Vue"
        else
            TECH_STACK="Node.js"
        fi

        # Extract scripts
        SCRIPTS=$(grep -A 20 '"scripts"' package.json 2>/dev/null | grep -E '^\s+"[^"]+":' | head -5 | sed 's/.*"\([^"]*\)".*/- npm run \1/' || echo "")
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        TECH_STACK="Python"
        if [ -f "manage.py" ]; then
            TECH_STACK="Django"
            SCRIPTS="- python manage.py runserver\n- python manage.py test"
        elif [ -f "app.py" ] || [ -f "main.py" ]; then
            TECH_STACK="Flask/FastAPI"
            SCRIPTS="- python app.py\n- pytest"
        fi
    elif [ -f "Cargo.toml" ]; then
        TECH_STACK="Rust"
        SCRIPTS="- cargo build\n- cargo run\n- cargo test"
    elif [ -f "go.mod" ]; then
        TECH_STACK="Go"
        SCRIPTS="- go build\n- go run .\n- go test ./..."
    elif [ -f "Gemfile" ]; then
        TECH_STACK="Ruby"
        if [ -f "config/routes.rb" ]; then
            TECH_STACK="Rails"
            SCRIPTS="- rails server\n- rails test"
        fi
    else
        TECH_STACK="Unknown"
        SCRIPTS="# Add your build/run commands here"
    fi

    echo "Detected: $PROJECT_NAME ($TECH_STACK)"
}

# Create file if it doesn't exist (or force is set)
# Usage: create_file <filepath> <content> [command]
# If third arg is "command", file is updated with --force-commands
create_file() {
    local filepath=$1
    local content=$2
    local filetype=${3:-"project"}  # "project" or "command"

    # Check if we should skip this file
    if [ -f "$filepath" ]; then
        if [ "$FORCE" = true ]; then
            : # Always overwrite with --force
        elif [ "$FORCE_COMMANDS" = true ] && [ "$filetype" = "command" ]; then
            : # Overwrite commands with --force-commands
        else
            echo "  [SKIP] $filepath already exists"
            return
        fi
    fi

    mkdir -p "$(dirname "$filepath")"
    echo "$content" > "$filepath"
    echo "  [CREATE] $filepath"
}

detect_project_info

echo ""

# Phase 0: Migration from legacy root-level files
migrate_file() {
    local filename=$1
    if [ -f "$filename" ] && [ ! -f ".claude-harness/$filename" ]; then
        mkdir -p .claude-harness
        mv "$filename" ".claude-harness/$filename"
        echo "  [MIGRATE] $filename -> .claude-harness/$filename"
    fi
}

MIGRATED=0
for legacy_file in feature-list.json feature-archive.json claude-progress.json working-context.json agent-context.json agent-memory.json init.sh; do
    if [ -f "$legacy_file" ] && [ ! -f ".claude-harness/$legacy_file" ]; then
        migrate_file "$legacy_file"
        MIGRATED=$((MIGRATED + 1))
    fi
done

if [ $MIGRATED -gt 0 ]; then
    echo ""
    echo "Migrated $MIGRATED legacy file(s) to .claude-harness/"
    echo ""
fi

echo "Creating harness files..."
echo ""

# Create .claude-harness directory for state files
mkdir -p .claude-harness

# 1. CLAUDE.md
create_file "CLAUDE.md" "# $PROJECT_NAME

## Project Overview
<!-- Describe what this project does -->

## Tech Stack
- $TECH_STACK

## Common Commands
$SCRIPTS

## Session Startup Protocol
On every session start:
1. Run \`pwd\` to confirm working directory
2. Read \`.claude-harness/claude-progress.json\` for context
3. Run \`git log --oneline -5\` to see recent changes
4. Check \`.claude-harness/feature-list.json\` for current priorities
   - If file is too large, use: \`grep -A 5 '\"passes\": false' .claude-harness/feature-list.json\`
   - Completed features are auto-archived to \`.claude-harness/feature-archive.json\` on /checkpoint

## Development Rules
- Work on ONE feature at a time
- Always update \`.claude-harness/claude-progress.json\` after completing work
- Run tests before marking features complete
- Commit with descriptive messages
- Leave codebase in clean, working state

## Testing Requirements
<!-- Add your test commands -->
- Build: \`npm run build\` (or equivalent)
- Lint: \`npm run lint\` (or equivalent)
- Test: \`npm test\` (or equivalent)

## Progress Tracking
See: \`.claude-harness/claude-progress.json\` and \`.claude-harness/feature-list.json\`
"

# 2. claude-progress.json
create_file ".claude-harness/claude-progress.json" '{
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "currentProject": "'$PROJECT_NAME'",
  "lastSession": {
    "summary": "Initial harness setup",
    "completedTasks": [],
    "blockers": [],
    "nextSteps": ["Review CLAUDE.md and customize", "Add features to feature-list.json"]
  },
  "recentChanges": [],
  "knownIssues": [],
  "environmentState": {
    "devServerRunning": false,
    "lastSuccessfulBuild": null,
    "lastTypeCheck": null
  }
}'

# 3. feature-list.json
create_file ".claude-harness/feature-list.json" '{
  "version": 1,
  "features": []
}'

# 3b. feature-archive.json (for archiving completed features)
create_file ".claude-harness/feature-archive.json" '{
  "version": 1,
  "archived": []
}'

# 3c. agent-context.json (multi-agent orchestration shared context)
create_file ".claude-harness/agent-context.json" '{
  "version": 1,
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "currentSession": null,
  "projectContext": {
    "name": "'$PROJECT_NAME'",
    "techStack": ["'$TECH_STACK'"],
    "testingFramework": null,
    "buildCommand": null,
    "testCommand": null
  },
  "architecturalDecisions": [],
  "activeConstraints": [],
  "sharedState": {
    "discoveredPatterns": {},
    "fileIndex": {
      "components": [],
      "apiRoutes": [],
      "tests": [],
      "configs": []
    }
  },
  "agentResults": [],
  "pendingHandoffs": []
}'

# 3d. agent-memory.json (multi-agent orchestration persistent memory)
create_file ".claude-harness/agent-memory.json" '{
  "version": 1,
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "learnedPatterns": {
    "codePatterns": [],
    "namingConventions": {},
    "projectSpecificRules": []
  },
  "successfulApproaches": [],
  "failedApproaches": [],
  "agentPerformance": {},
  "codebaseInsights": {
    "hotspots": [],
    "technicalDebt": []
  }
}'

# 3e. loop-state.json (agentic loop state tracking)
create_file ".claude-harness/loop-state.json" '{
  "version": 1,
  "feature": null,
  "featureName": null,
  "status": "idle",
  "attempt": 0,
  "maxAttempts": 10,
  "startedAt": null,
  "lastAttemptAt": null,
  "verification": {
    "build": null,
    "tests": null,
    "lint": null,
    "typecheck": null,
    "custom": []
  },
  "history": [],
  "lastCheckpoint": null,
  "escalationRequested": false
}'

# 4. init.sh (inside .claude-harness for organization)
create_file ".claude-harness/init.sh" '#!/bin/bash
# Development Environment Initializer

echo "=== Dev Environment Setup ==="
echo "Working directory: $(pwd)"

# Check we are in the right place
if [ ! -f "CLAUDE.md" ]; then
    echo "ERROR: Not in project root directory"
    exit 1
fi

# Show recent git history
echo ""
echo "=== Recent Git History ==="
git log --oneline -5 2>/dev/null || echo "Not a git repo yet"

# Show current progress
echo ""
echo "=== Current Progress ==="
if [ -f ".claude-harness/claude-progress.json" ]; then
    cat .claude-harness/claude-progress.json | head -30
else
    echo "No progress file found"
fi

# Check feature status
echo ""
echo "=== Pending Features ==="
if [ -f ".claude-harness/feature-list.json" ]; then
    grep -A 3 "passes.*false" .claude-harness/feature-list.json 2>/dev/null || echo "No pending features"
else
    echo "No feature list found"
fi

# Check archived features
echo ""
echo "=== Archived Features ==="
if [ -f ".claude-harness/feature-archive.json" ]; then
    count=$(grep -c "\"id\":" .claude-harness/feature-archive.json 2>/dev/null || echo "0")
    echo "$count completed features archived"
else
    echo "No archive yet"
fi

echo ""
echo "=== GitHub Integration ==="
echo "Run /claude-harness:start for GitHub issues, PRs, and CI status"

echo ""
echo "=== Orchestration State ==="
if [ -f ".claude-harness/agent-context.json" ]; then
    session=$(grep -o "\"activeFeature\":[^,}]*" .claude-harness/agent-context.json 2>/dev/null | head -1)
    if [ -n "$session" ] && [ "$session" != "\"activeFeature\": null" ]; then
        echo "Active orchestration: $session"
        echo "Run /claude-harness:orchestrate to resume"
    else
        echo "No active orchestration"
    fi
    handoffs=$(grep -c "\"from\":" .claude-harness/agent-context.json 2>/dev/null || echo "0")
    if [ "$handoffs" != "0" ]; then
        echo "Pending handoffs: $handoffs"
    fi
else
    echo "No orchestration context yet"
fi

echo ""
echo "=== Environment Ready ==="
echo "Next: Review .claude-harness/claude-progress.json and pick a feature to work on"
echo "Commands: /claude-harness:start, /claude-harness:feature, /claude-harness:orchestrate, /claude-harness:checkpoint, /claude-harness:merge-all"
'
chmod +x .claude-harness/init.sh 2>/dev/null || true

# 5. .claude directory structure
mkdir -p .claude/commands

# 6. .claude/settings.local.json
create_file ".claude/settings.local.json" '{
  "permissions": {
    "allow": [
      "Bash(./.claude-harness/init.sh)",
      "Bash(git:*)",
      "WebSearch"
    ],
    "deny": [],
    "ask": []
  }
}'

# 7. /start command
create_file ".claude/commands/start.md" 'Run the initialization script and prepare for a new coding session:

## Phase 0: Auto-Migration (Legacy Files)
Check if legacy root-level files exist and migrate them:
1. If `.claude-harness/` directory does NOT exist AND any of these files exist in root:
   - claude-progress.json, feature-list.json, feature-archive.json
   - agent-context.json, agent-memory.json, working-context.json
2. Create `.claude-harness/` directory
3. Move each legacy file to `.claude-harness/`
4. Report: "Migrated X files to .claude-harness/"

## Phase 1: Local Status
1. Execute `./.claude-harness/init.sh` to see environment status
2. Read `.claude-harness/claude-progress.json` for session context
3. Read `.claude-harness/feature-list.json` to identify next priority

## Phase 2: Orchestration State
4. Read `.claude-harness/agent-context.json` if exists - check for pending handoffs
5. Read `.claude-harness/agent-memory.json` if exists - check for codebase insights

## Phase 3: GitHub Integration (if MCP configured)
6. Fetch GitHub dashboard: open issues, PRs, CI status
7. Sync GitHub Issues with .claude-harness/feature-list.json (import new, close completed)

## Phase 4: Recommendations
8. Report: current state, blockers, GitHub sync results, recommended next action
' "command"

# 8. /checkpoint command
create_file ".claude/commands/checkpoint.md" 'Create a checkpoint of the current session:

1. Update `.claude-harness/claude-progress.json` with:
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
   - Update .claude-harness/feature-list.json with prNumber

5. Report final status:
   - Build/test results
   - Commit hash and push status
   - PR URL (if created/updated)
   - Remaining work

6. Archive completed features (to prevent feature-list.json from growing too large):
   - Read .claude-harness/feature-list.json
   - Find all features with passes=true
   - If any completed features exist:
     - Read .claude-harness/feature-archive.json (create if it does not exist with {"version":1,"archived":[]})
     - Add archivedAt timestamp to each completed feature
     - Append completed features to the archived[] array
     - Write updated .claude-harness/feature-archive.json
     - Remove completed features from .claude-harness/feature-list.json and save
   - Report: "Archived X completed features"
' "command"

# 9. /feature command for adding features
create_file ".claude/commands/feature.md" 'Add a new feature to .claude-harness/feature-list.json and create GitHub Issue:

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
4. Add to .claude-harness/feature-list.json with:
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
' "command"

# 10. /merge-all command
create_file ".claude/commands/merge-all.md" 'Merge all open PRs, close related issues, and delete branches in dependency order:

Requires GitHub MCP to be configured.

1. Gather state:
   - List all open PRs for this repository
   - List all open issues with "feature" label
   - Read .claude-harness/feature-list.json for linked issue/PR numbers

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
   - Find and close any linked issues (from PR body or .claude-harness/feature-list.json)
   - Delete the source branch
   - Update .claude-harness/feature-list.json: set passes=true for related feature

5. Cleanup:
   - Prune local branches: `git fetch --prune`
   - Delete local feature branches that were merged
   - Switch to main/master branch

6. Report summary:
   - PRs merged (with commit hashes)
   - Issues closed
   - Branches deleted
   - Any failures or skipped items
' "command"

# 11. /implement command (agentic loop execution)
create_file ".claude/commands/implement.md" '---
description: Start or resume an agentic loop to implement a feature until verification passes
argumentsPrompt: Feature ID to implement (e.g., feature-001)
---

Implement a feature using a persistent agentic loop that continues until verification passes:

Arguments: $ARGUMENTS

## Core Principle
"Claude marked features complete without proper testing" - NEVER trust self-assessment.
Always run actual verification commands.

## Loop Cycle

1. **Load State**: Read .claude-harness/loop-state.json - resume or start new
2. **Health Check**: Verify environment works (build succeeds)
3. **Attempt**: Execute implementation with planned approach
4. **Verify (MANDATORY)**: Run ALL verification commands (build, tests, lint, typecheck)
5. **On Success**: Git commit, mark feature complete, report
6. **On Failure**: Analyze errors, increment attempt, retry with different approach
7. **On Max Attempts**: Escalate to user with full history

## Session Continuity

Loop state persists in .claude-harness/loop-state.json across context windows.
SessionStart hook shows active loops and prompts to resume.

## Commands

- Start/resume: `/claude-harness:implement feature-001`
- With more attempts: `/claude-harness:implement feature-001 --max-attempts 20`

See full documentation in plugin commands/implement.md
' "command"

# 12. /orchestrate command (multi-agent orchestration)
create_file ".claude/commands/orchestrate.md" '---
description: Orchestrate multi-agent teams for complex features
argumentsPrompt: Feature ID or description to orchestrate
---

Orchestrate specialized agents to implement a feature or task:

Arguments: $ARGUMENTS

## Phase 1: Task Analysis

1. Identify the target:
   - If $ARGUMENTS matches a feature ID (e.g., "feature-001"), read from .claude-harness/feature-list.json
   - Otherwise, treat $ARGUMENTS as a task description

2. Read orchestration context:
   - Read `.claude-harness/agent-context.json` for current state (create if missing)
   - Read `.claude-harness/agent-memory.json` for learned patterns (create if missing)
   - Read `.claude-harness/feature-list.json` if working on a tracked feature

3. Analyze the task:
   - Identify file types that will be modified
   - Detect domains involved (frontend, backend, database, testing)
   - Check for security-sensitive operations
   - Estimate complexity and required agents

## Phase 2: Agent Selection

4. Map task requirements to specialized agents:

   **Implementation Agents:**
   | Domain | Agent (subagent_type) | Triggers |
   |--------|----------------------|----------|
   | React/Frontend | react-specialist | .tsx, .jsx, component |
   | Backend/API | backend-developer | route.ts, api/, endpoint |
   | Next.js | nextjs-developer | app/, pages/ |
   | Database | database-administrator | prisma, schema, SQL |
   | Python | python-pro | .py files |
   | TypeScript | typescript-pro | complex types |

   **Quality Agents (mandatory for code):**
   | Type | Agent | When |
   |------|-------|------|
   | Review | code-reviewer | Always for code changes |
   | Security | security-auditor | Auth, tokens, encryption |
   | Testing | qa-expert | New features, bug fixes |

5. Build execution plan:
   - Group 1: Analysis agents (research if needed)
   - Group 2: Implementation agents (parallel if independent)
   - Group 3: Quality agents (code-reviewer, security-auditor)
   - Group 4: Documentation agents

## Phase 3: Agent Spawning

6. Update `.claude-harness/agent-context.json` with session info

7. For each agent, use Task tool with:
   - Shared context from .claude-harness/agent-context.json
   - Learned patterns from .claude-harness/agent-memory.json
   - Specific task assignment
   - Files to work on

8. Execute in dependency order:
   - Parallel execution for independent tasks
   - Sequential for dependent tasks

## Phase 4: Coordination

9. After each agent:
   - Update .claude-harness/agent-context.json with results
   - Record patterns discovered
   - Handle failures (retry or fallback)

10. Manage handoffs between agents

## Phase 5: Aggregation

11. Aggregate all results
12. Update .claude-harness/agent-memory.json with learnings
13. Update .claude-harness/feature-list.json if applicable

## Phase 6: Report

14. Report summary:
    - Agents invoked and status
    - Files created/modified
    - Decisions made
    - Issues found
    - Next steps

Run `/claude-harness:checkpoint` after to commit changes.
' "command"

# 12. Record plugin version for update detection
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_VERSION=$(grep '"version"' "$SCRIPT_DIR/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "unknown")
echo "$PLUGIN_VERSION" > .claude-harness/.plugin-version
echo "  [CREATE] .claude-harness/.plugin-version (v$PLUGIN_VERSION)"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Files created:"
echo "  - CLAUDE.md                                  (main context file)"
echo "  - .claude-harness/claude-progress.json       (session continuity)"
echo "  - .claude-harness/feature-list.json          (feature tracking)"
echo "  - .claude-harness/feature-archive.json       (completed feature archive)"
echo "  - .claude-harness/agent-context.json         (multi-agent shared context)"
echo "  - .claude-harness/agent-memory.json          (multi-agent persistent memory)"
echo "  - .claude-harness/loop-state.json            (agentic loop state)"
echo "  - .claude-harness/.plugin-version            (plugin version tracking)"
echo "  - .claude-harness/init.sh                    (startup script)"
echo "  - .claude/settings.local.json"
echo "  - .claude/commands/start.md"
echo "  - .claude/commands/checkpoint.md"
echo "  - .claude/commands/feature.md"
echo "  - .claude/commands/implement.md"
echo "  - .claude/commands/merge-all.md"
echo "  - .claude/commands/orchestrate.md"
echo ""
echo "=== GitHub MCP Setup (Optional) ==="
echo ""
echo "To enable GitHub integration, run:"
echo "  claude mcp add github -s user"
echo ""
echo "Or manually with your token:"
echo "  export GITHUB_TOKEN=ghp_xxxx"
echo '  claude mcp add-json github '"'"'{"command":"npx","args":["-y","@modelcontextprotocol/server-github"],"env":{"GITHUB_PERSONAL_ACCESS_TOKEN":"'"'"'"$GITHUB_TOKEN"'"'"'"}}'"'"''
echo ""
echo "Verify with: claude mcp list"
echo ""
echo "=== Frontend Design Skill (Optional) ==="
echo ""
echo "For high-quality UI/frontend work, install the frontend-design skill:"
echo "  claude skill add @anthropics/claude-code/frontend-design"
echo ""
echo "This skill helps Claude generate distinctive, production-grade interfaces"
echo "with bold typography, cohesive colors, and polished animations."
echo "Avoids generic 'AI aesthetics' (Inter font, purple gradients, etc.)"
echo ""
echo "=== Next Steps ==="
echo ""
echo "  1. Edit CLAUDE.md to describe your project"
echo "  2. (Optional) Setup GitHub MCP for issue/PR integration"
echo "  3. Use /start to start a session"
echo "  4. Use /feature to add features to work on"
echo "  5. Use /orchestrate to spawn multi-agent teams for complex features"
echo "  6. Use /checkpoint to save progress and persist agent memory"
echo ""
echo "Available commands:"
echo "  /start       - Start session (shows status, GitHub dashboard, syncs issues)"
echo "  /feature     - Add a feature (creates GitHub issue if MCP configured)"
echo "  /implement   - Start agentic loop (runs until verification passes)"
echo "  /orchestrate - Spawn multi-agent team for complex features"
echo "  /checkpoint  - Save progress (commits, creates/updates PR)"
echo "  /merge-all   - Merge all PRs, close issues, delete branches"
echo ""
echo "Tip: Add this to .gitignore if you don't want to commit state files:"
echo "  .claude-harness/"
echo "  .claude/settings.local.json"
