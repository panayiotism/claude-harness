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
echo "Creating harness files..."
echo ""

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
2. Read \`claude-progress.json\` for context
3. Run \`git log --oneline -5\` to see recent changes
4. Check \`feature-list.json\` for current priorities

## Development Rules
- Work on ONE feature at a time
- Always update \`claude-progress.json\` after completing work
- Run tests before marking features complete
- Commit with descriptive messages
- Leave codebase in clean, working state

## Testing Requirements
<!-- Add your test commands -->
- Build: \`npm run build\` (or equivalent)
- Lint: \`npm run lint\` (or equivalent)
- Test: \`npm test\` (or equivalent)

## Progress Tracking
See: \`claude-progress.json\` and \`feature-list.json\`
"

# 2. claude-progress.json
create_file "claude-progress.json" '{
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
create_file "feature-list.json" '{
  "version": 1,
  "features": []
}'

# 4. init.sh
create_file "init.sh" '#!/bin/bash
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
if [ -f "claude-progress.json" ]; then
    cat claude-progress.json | head -30
else
    echo "No progress file found"
fi

# Check feature status
echo ""
echo "=== Pending Features ==="
if [ -f "feature-list.json" ]; then
    grep -A 3 "passes.*false" feature-list.json 2>/dev/null || echo "No pending features"
else
    echo "No feature list found"
fi

echo ""
echo "=== GitHub Integration ==="
echo "Run /gh-status for GitHub issues, PRs, and CI status"

echo ""
echo "=== Environment Ready ==="
echo "Next: Review claude-progress.json and pick a feature to work on"
echo "Commands: /start, /feature, /checkpoint, /pr, /sync-issues, /gh-status"
'
chmod +x init.sh 2>/dev/null || true

# 5. .claude directory structure
mkdir -p .claude/commands

# 6. .claude/settings.local.json
create_file ".claude/settings.local.json" '{
  "permissions": {
    "allow": [
      "Bash(./init.sh)",
      "Bash(git:*)",
      "WebSearch"
    ],
    "deny": [],
    "ask": []
  }
}'

# 7. /start command
create_file ".claude/commands/start.md" 'Run the initialization script and prepare for a new coding session:

1. Execute `./init.sh` to see environment status
2. Read `claude-progress.json` for session context
3. Read `feature-list.json` to identify next priority
4. Report: current state, blockers, recommended next action
' "command"

# 8. /checkpoint command
create_file ".claude/commands/checkpoint.md" 'Create a checkpoint of the current session:

1. Update `claude-progress.json` with:
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
   - Update feature-list.json with prNumber

5. Report final status:
   - Build/test results
   - Commit hash and push status
   - PR URL (if created/updated)
   - Remaining work
' "command"

# 9. /feature command for adding features
create_file ".claude/commands/feature.md" 'Add a new feature to feature-list.json and create GitHub Issue:

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
' "command"

# 10. /sync-issues command
create_file ".claude/commands/sync-issues.md" 'Synchronize feature-list.json with GitHub Issues:

Requires GitHub MCP to be configured.

1. Use GitHub MCP to list open issues with label "feature"

2. For each GitHub issue NOT in feature-list.json:
   - Add new entry with issueNumber linked

3. For each feature in feature-list.json with passes=true:
   - If linked GitHub issue is still open, close it

4. Report sync results
' "command"

# 11. /pr command
create_file ".claude/commands/pr.md" 'Manage the current feature pull request:

Arguments: $ARGUMENTS (create|update|status|merge)

Requires GitHub MCP to be configured.

- create: Create PR from current branch to main
- update: Update PR description with latest progress
- status: Check PR status, reviews, CI
- merge: Merge PR if approved and CI passes, mark feature complete
' "command"

# 12. /gh-status command
create_file ".claude/commands/gh-status.md" 'Show GitHub integration status for current project:

Requires GitHub MCP to be configured.

1. Check GitHub MCP connection status

2. Fetch and display:
   - Open issues with "feature" label
   - Open PRs from feature branches
   - CI/CD status

3. Cross-reference with feature-list.json

4. Recommendations for next actions
' "command"

# 13. /merge-all command
create_file ".claude/commands/merge-all.md" 'Merge all open PRs, close related issues, and delete branches in dependency order:

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
' "command"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Files created:"
echo "  - CLAUDE.md             (main context file)"
echo "  - claude-progress.json  (session continuity)"
echo "  - feature-list.json     (feature tracking)"
echo "  - init.sh               (startup script)"
echo "  - .claude/settings.local.json"
echo "  - .claude/commands/start.md"
echo "  - .claude/commands/checkpoint.md"
echo "  - .claude/commands/feature.md"
echo "  - .claude/commands/sync-issues.md"
echo "  - .claude/commands/pr.md"
echo "  - .claude/commands/gh-status.md"
echo "  - .claude/commands/merge-all.md"
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
echo "  5. Use /checkpoint to save progress"
echo ""
echo "Available commands:"
echo "  /start       - Start a session"
echo "  /feature     - Add a feature (creates GitHub issue if MCP configured)"
echo "  /checkpoint  - Save progress (creates PR if MCP configured)"
echo "  /pr          - Manage pull requests"
echo "  /sync-issues - Sync with GitHub issues"
echo "  /gh-status   - Show GitHub integration status"
echo "  /merge-all   - Merge all PRs, close issues, delete branches"
echo ""
echo "Tip: Add these to .gitignore if you don't want to commit them:"
echo "  claude-progress.json"
echo "  .claude/settings.local.json"
