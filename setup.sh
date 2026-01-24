#!/bin/bash
# Claude Code Long-Running Agent Harness Setup v4.0
# Based on: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
# Enhanced with: Context-Engine memory architecture, Agent-Foreman patterns, Anthropic autonomous-coding
#
# Usage:
#   curl -sL <url> | bash                    # New repo (interactive)
#   ./setup.sh                  # Run locally (skip existing files)
#   ./setup.sh --force          # Overwrite ALL files (use with caution)
#   ./setup.sh --force-commands # Update commands only, preserve project files
#   ./setup.sh --migrate        # Force migration from v2.x to v3.0

set -e

FORCE=false
FORCE_COMMANDS=false
FORCE_MIGRATE=false

case "$1" in
    --force)
        FORCE=true
        ;;
    --force-commands)
        FORCE_COMMANDS=true
        ;;
    --migrate)
        FORCE_MIGRATE=true
        ;;
esac

echo "=== Claude Code Agent Harness Setup v4.2.3 ==="
echo ""

# Detect project info
detect_project_info() {
    PROJECT_NAME=$(basename "$(pwd)")
    TECH_STACK=""
    SCRIPTS=""
    FRAMEWORK=""
    LANGUAGE=""
    DATABASE=""
    TEST_FRAMEWORK=""
    BUILD_CMD=""
    TEST_CMD=""
    LINT_CMD=""
    TYPECHECK_CMD=""

    # Detect tech stack
    if [ -f "package.json" ]; then
        LANGUAGE="TypeScript/JavaScript"

        # Detect framework
        if grep -q "next" package.json 2>/dev/null; then
            TECH_STACK="Next.js"
            FRAMEWORK="nextjs"
        elif grep -q "react" package.json 2>/dev/null; then
            TECH_STACK="React"
            FRAMEWORK="react"
        elif grep -q "vue" package.json 2>/dev/null; then
            TECH_STACK="Vue"
            FRAMEWORK="vue"
        elif grep -q "express" package.json 2>/dev/null; then
            TECH_STACK="Express"
            FRAMEWORK="express"
        else
            TECH_STACK="Node.js"
            FRAMEWORK="node"
        fi

        # Detect test framework
        if grep -q "jest" package.json 2>/dev/null; then
            TEST_FRAMEWORK="jest"
        elif grep -q "vitest" package.json 2>/dev/null; then
            TEST_FRAMEWORK="vitest"
        elif grep -q "mocha" package.json 2>/dev/null; then
            TEST_FRAMEWORK="mocha"
        fi

        # Detect database
        if grep -q "prisma" package.json 2>/dev/null; then
            DATABASE="prisma"
        elif grep -q "mongoose" package.json 2>/dev/null; then
            DATABASE="mongodb"
        elif grep -q "pg" package.json 2>/dev/null; then
            DATABASE="postgresql"
        fi

        # Extract common scripts
        if grep -q '"build"' package.json 2>/dev/null; then
            BUILD_CMD="npm run build"
        fi
        if grep -q '"test"' package.json 2>/dev/null; then
            TEST_CMD="npm run test"
        fi
        if grep -q '"lint"' package.json 2>/dev/null; then
            LINT_CMD="npm run lint"
        fi
        if [ -f "tsconfig.json" ]; then
            TYPECHECK_CMD="npx tsc --noEmit"
            LANGUAGE="TypeScript"
        fi

        SCRIPTS=$(grep -A 20 '"scripts"' package.json 2>/dev/null | grep -E '^\s+"[^"]+":' | head -5 | sed 's/.*"\([^"]*\)".*/- npm run \1/' || echo "")

    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
        LANGUAGE="Python"
        TECH_STACK="Python"
        TEST_FRAMEWORK="pytest"
        TEST_CMD="pytest"

        if [ -f "manage.py" ]; then
            TECH_STACK="Django"
            FRAMEWORK="django"
            SCRIPTS="- python manage.py runserver\n- python manage.py test"
        elif [ -f "app.py" ] || [ -f "main.py" ]; then
            TECH_STACK="Flask/FastAPI"
            FRAMEWORK="fastapi"
            SCRIPTS="- python app.py\n- pytest"
        fi

    elif [ -f "Cargo.toml" ]; then
        TECH_STACK="Rust"
        LANGUAGE="Rust"
        FRAMEWORK="rust"
        BUILD_CMD="cargo build"
        TEST_CMD="cargo test"
        SCRIPTS="- cargo build\n- cargo run\n- cargo test"

    elif [ -f "go.mod" ]; then
        TECH_STACK="Go"
        LANGUAGE="Go"
        FRAMEWORK="go"
        BUILD_CMD="go build"
        TEST_CMD="go test ./..."
        SCRIPTS="- go build\n- go run .\n- go test ./..."

    elif [ -f "Gemfile" ]; then
        LANGUAGE="Ruby"
        TECH_STACK="Ruby"
        if [ -f "config/routes.rb" ]; then
            TECH_STACK="Rails"
            FRAMEWORK="rails"
            TEST_CMD="rails test"
            SCRIPTS="- rails server\n- rails test"
        fi
    else
        TECH_STACK="Unknown"
        LANGUAGE="Unknown"
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

# ============================================================================
# PHASE 0: MIGRATION FROM v2.x TO v3.0
# ============================================================================

migrate_v2_to_v3() {
    echo "=== Migrating v2.x to v3.0 ==="

    # Create backup
    if [ -d ".claude-harness" ]; then
        BACKUP_DIR=".claude-harness-backup-$(date +%Y%m%d%H%M%S)"
        cp -r .claude-harness "$BACKUP_DIR"
        echo "  [BACKUP] Created $BACKUP_DIR"
    fi

    # Create new directory structure
    mkdir -p .claude-harness/memory/working
    mkdir -p .claude-harness/memory/episodic
    mkdir -p .claude-harness/memory/semantic
    mkdir -p .claude-harness/memory/procedural
    mkdir -p .claude-harness/impact
    mkdir -p .claude-harness/features/tests
    mkdir -p .claude-harness/agents
    mkdir -p .claude-harness/loops

    # Migrate feature-list.json -> features/active.json
    if [ -f ".claude-harness/feature-list.json" ]; then
        # Transform old format to new format with additional fields
        if command -v jq &> /dev/null; then
            jq '.features = [.features[] | . + {
                "status": (if .passes == true then "passing" else "pending" end),
                "phase": "implementation",
                "tests": {"generated": false, "file": null, "passing": 0, "total": 0},
                "attempts": 0,
                "createdAt": (.createdAt // now | todate),
                "updatedAt": (now | todate)
            }] | {version: 3, features: .features}' .claude-harness/feature-list.json > .claude-harness/features/active.json 2>/dev/null || \
            cp .claude-harness/feature-list.json .claude-harness/features/active.json
        else
            cp .claude-harness/feature-list.json .claude-harness/features/active.json
        fi
        echo "  [MIGRATE] feature-list.json -> features/active.json"
    fi

    # Migrate feature-archive.json -> features/archive.json
    if [ -f ".claude-harness/feature-archive.json" ]; then
        cp .claude-harness/feature-archive.json .claude-harness/features/archive.json
        echo "  [MIGRATE] feature-archive.json -> features/archive.json"
    fi

    # Migrate agent-context.json -> agents/context.json
    if [ -f ".claude-harness/agent-context.json" ]; then
        cp .claude-harness/agent-context.json .claude-harness/agents/context.json
        echo "  [MIGRATE] agent-context.json -> agents/context.json"
    fi

    # Migrate agent-memory.json -> memory/procedural/ (split into successes and failures)
    if [ -f ".claude-harness/agent-memory.json" ]; then
        if command -v jq &> /dev/null; then
            # Extract successful approaches
            jq '{entries: .successfulApproaches // []}' .claude-harness/agent-memory.json > .claude-harness/memory/procedural/successes.json 2>/dev/null || echo '{"entries": []}' > .claude-harness/memory/procedural/successes.json
            # Extract failed approaches
            jq '{entries: .failedApproaches // []}' .claude-harness/agent-memory.json > .claude-harness/memory/procedural/failures.json 2>/dev/null || echo '{"entries": []}' > .claude-harness/memory/procedural/failures.json
            # Extract patterns
            jq '{patterns: .learnedPatterns // {}}' .claude-harness/agent-memory.json > .claude-harness/memory/procedural/patterns.json 2>/dev/null || echo '{"patterns": {}}' > .claude-harness/memory/procedural/patterns.json
        else
            echo '{"entries": []}' > .claude-harness/memory/procedural/successes.json
            echo '{"entries": []}' > .claude-harness/memory/procedural/failures.json
            echo '{"patterns": {}}' > .claude-harness/memory/procedural/patterns.json
        fi
        echo "  [MIGRATE] agent-memory.json -> memory/procedural/"
    fi

    # Migrate working-context.json -> memory/working/context.json
    if [ -f ".claude-harness/working-context.json" ]; then
        cp .claude-harness/working-context.json .claude-harness/memory/working/context.json
        echo "  [MIGRATE] working-context.json -> memory/working/context.json"
    fi

    # Migrate loop-state.json -> loops/state.json
    if [ -f ".claude-harness/loop-state.json" ]; then
        cp .claude-harness/loop-state.json .claude-harness/loops/state.json
        echo "  [MIGRATE] loop-state.json -> loops/state.json"
    fi

    # Create migration marker
    echo "3.0.0" > .claude-harness/.migrated-from-v2

    echo ""
    echo "Migration complete! Backup saved to $BACKUP_DIR"
    echo ""
}

# Check if migration is needed
needs_migration() {
    # If new structure already exists, no migration needed
    if [ -d ".claude-harness/memory" ] && [ -d ".claude-harness/features" ]; then
        return 1
    fi
    # If old v2 files exist, migration is needed
    if [ -f ".claude-harness/feature-list.json" ] || [ -f ".claude-harness/agent-memory.json" ]; then
        return 0
    fi
    return 1
}

# Legacy migration from root-level files (v1.x -> .claude-harness/)
migrate_legacy_root_files() {
    MIGRATED=0
    for legacy_file in feature-list.json feature-archive.json claude-progress.json working-context.json agent-context.json agent-memory.json init.sh; do
        if [ -f "$legacy_file" ] && [ ! -f ".claude-harness/$legacy_file" ]; then
            mkdir -p .claude-harness
            mv "$legacy_file" ".claude-harness/$legacy_file"
            echo "  [MIGRATE] $legacy_file -> .claude-harness/$legacy_file"
            MIGRATED=$((MIGRATED + 1))
        fi
    done

    if [ $MIGRATED -gt 0 ]; then
        echo ""
        echo "Migrated $MIGRATED legacy file(s) to .claude-harness/"
        echo ""
    fi
}

# Run migrations
migrate_legacy_root_files

if [ "$FORCE_MIGRATE" = true ] || needs_migration; then
    migrate_v2_to_v3
fi

echo "Creating harness files (v3.0 Memory Architecture)..."
echo ""

# ============================================================================
# CREATE v3.0 DIRECTORY STRUCTURE
# ============================================================================

mkdir -p .claude-harness/memory/episodic
mkdir -p .claude-harness/memory/semantic
mkdir -p .claude-harness/memory/procedural
mkdir -p .claude-harness/memory/learned
mkdir -p .claude-harness/impact
mkdir -p .claude-harness/features/tests
mkdir -p .claude-harness/agents
mkdir -p .claude-harness/sessions
mkdir -p .claude-harness/worktrees
mkdir -p .claude-harness/prd
# Note: memory/working and loops are session-scoped, not created at setup

# ============================================================================
# 1. CLAUDE.md - Main context file
# ============================================================================

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
2. Run \`/claude-harness:start\` to compile working context
3. Read \`.claude-harness/sessions/{session-id}/context.json\` for computed context
4. Check \`.claude-harness/features/active.json\` for current priorities

## Development Rules
- Work on ONE feature at a time
- Always run /claude-harness:checkpoint after completing work
- Run tests before marking features complete
- Commit with descriptive messages
- Leave codebase in clean, working state

## Testing Requirements
<!-- Add your test commands -->
- Build: \`${BUILD_CMD:-npm run build}\`
- Lint: \`${LINT_CMD:-npm run lint}\`
- Test: \`${TEST_CMD:-npm test}\`
- Typecheck: \`${TYPECHECK_CMD:-npx tsc --noEmit}\`

## Progress Tracking
See: \`.claude-harness/sessions/{session-id}/context.json\` and \`.claude-harness/features/active.json\`

## Memory Architecture (v3.0)
- \`sessions/{session-id}/\` - Current session context (per-session, gitignored)
- \`memory/episodic/\` - Recent decisions (rolling window)
- \`memory/semantic/\` - Project knowledge (persistent)
- \`memory/procedural/\` - Success/failure patterns (append-only)
- \`memory/learned/\` - Rules from user corrections (append-only)
"

# ============================================================================
# 2. MEMORY LAYER: Working Context (session-scoped, no longer created here)
# ============================================================================
# Session-scoped working context is created by SessionStart hook at:
# .claude-harness/sessions/{session-id}/context.json

# ============================================================================
# 3. MEMORY LAYER: Episodic Memory (rolling window of decisions)
# ============================================================================

create_file ".claude-harness/memory/episodic/decisions.json" '{
  "version": 3,
  "maxEntries": 50,
  "entries": []
}'

# ============================================================================
# 4. MEMORY LAYER: Semantic Memory (persistent project knowledge)
# ============================================================================

create_file ".claude-harness/memory/semantic/architecture.json" '{
  "version": 3,
  "projectType": "'$FRAMEWORK'",
  "techStack": {
    "framework": "'$FRAMEWORK'",
    "language": "'$LANGUAGE'",
    "database": "'$DATABASE'",
    "testFramework": "'$TEST_FRAMEWORK'"
  },
  "structure": {
    "entryPoints": [],
    "components": [],
    "api": [],
    "tests": []
  },
  "patterns": {
    "naming": {},
    "fileOrganization": {},
    "codeStyle": {}
  },
  "discoveredAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}'

create_file ".claude-harness/memory/semantic/entities.json" '{
  "version": 3,
  "entities": []
}'

create_file ".claude-harness/memory/semantic/constraints.json" '{
  "version": 3,
  "constraints": [],
  "rules": []
}'

# ============================================================================
# 5. MEMORY LAYER: Procedural Memory (success/failure patterns - append-only)
# ============================================================================

create_file ".claude-harness/memory/procedural/failures.json" '{
  "version": 3,
  "entries": []
}'

create_file ".claude-harness/memory/procedural/successes.json" '{
  "version": 3,
  "entries": []
}'

create_file ".claude-harness/memory/procedural/patterns.json" '{
  "version": 3,
  "patterns": {
    "codePatterns": [],
    "namingConventions": {},
    "projectSpecificRules": []
  }
}'

# ============================================================================
# 5.5. MEMORY LAYER: Learned Rules (from user corrections)
# ============================================================================

create_file ".claude-harness/memory/learned/rules.json" '{
  "version": 3,
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "metadata": {
    "totalRules": 0,
    "projectSpecific": 0,
    "general": 0,
    "lastReflection": null
  },
  "rules": []
}'

# ============================================================================
# 6. IMPACT ANALYSIS: Dependency graph and change log
# ============================================================================

create_file ".claude-harness/impact/dependency-graph.json" '{
  "version": 3,
  "generatedAt": null,
  "nodes": {},
  "hotspots": [],
  "criticalPaths": []
}'

create_file ".claude-harness/impact/change-log.json" '{
  "version": 3,
  "entries": []
}'

# ============================================================================
# 7. FEATURES: Active features with test-driven schema
# ============================================================================

create_file ".claude-harness/features/active.json" '{
  "version": 3,
  "features": [],
  "fixes": []
}'

create_file ".claude-harness/features/archive.json" '{
  "version": 3,
  "archived": [],
  "archivedFixes": []
}'

# ============================================================================
# 8. AGENTS: Orchestration context and handoffs
# ============================================================================

create_file ".claude-harness/agents/context.json" '{
  "version": 3,
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "currentSession": null,
  "projectContext": {
    "name": "'$PROJECT_NAME'",
    "techStack": ["'$TECH_STACK'"],
    "testingFramework": "'$TEST_FRAMEWORK'",
    "buildCommand": "'$BUILD_CMD'",
    "testCommand": "'$TEST_CMD'"
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

create_file ".claude-harness/agents/handoffs.json" '{
  "version": 3,
  "queue": []
}'

# ============================================================================
# 8.5. PRD: Product Requirements Document analysis
# ============================================================================

create_file ".claude-harness/prd/subagent-prompts.json" '{
  "version": 1,
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "prompts": {
    "productAnalyst": {
      "role": "Product Analyst",
      "responsibility": "Extract and structure product requirements, user personas, and business goals"
    },
    "architect": {
      "role": "Architect",
      "responsibility": "Assess technical feasibility, implementation order, risks"
    },
    "qaLead": {
      "role": "QA Lead",
      "responsibility": "Define acceptance criteria, test scenarios, verification approach"
    }
  }
}'

# ============================================================================
# 9. LOOPS: Agentic loop state (session-scoped, no longer created here)
# ============================================================================
# Agentic loop state is now session-scoped, created by SessionStart hook at:
# .claude-harness/sessions/{session-id}/loop-state.json

# ============================================================================
# 9.5. WORKTREES: Registry for parallel development worktrees
# ============================================================================

create_file ".claude-harness/worktrees/registry.json" '{
  "version": 1,
  "worktrees": []
}'

# ============================================================================
# 10. CONFIG: Plugin configuration
# ============================================================================

create_file ".claude-harness/config.json" '{
  "version": 3,
  "projectName": "'$PROJECT_NAME'",
  "techStack": "'$TECH_STACK'",
  "verification": {
    "build": "'$BUILD_CMD'",
    "tests": "'$TEST_CMD'",
    "lint": "'$LINT_CMD'",
    "typecheck": "'$TYPECHECK_CMD'"
  },
  "memory": {
    "episodicMaxEntries": 50,
    "contextCompilationEnabled": true
  },
  "failurePrevention": {
    "enabled": true,
    "similarityThreshold": 0.7
  },
  "impactAnalysis": {
    "enabled": true,
    "warnOnHighImpact": true
  },
  "testDriven": {
    "enabled": true,
    "generateTestsBeforeImplementation": true
  },
  "reflection": {
    "enabled": true,
    "autoReflectOnCheckpoint": false,
    "autoApproveHighConfidence": true,
    "minConfidenceForAuto": "high"
  }
}'

# ============================================================================
# 11. claude-progress.json (session summary - kept for compatibility)
# ============================================================================

create_file ".claude-harness/claude-progress.json" '{
  "lastUpdated": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "currentProject": "'$PROJECT_NAME'",
  "lastSession": {
    "summary": "Initial harness setup (v3.0)",
    "completedTasks": [],
    "blockers": [],
    "nextSteps": ["Review CLAUDE.md and customize", "Run /claude-harness:start to begin"]
  },
  "recentChanges": [],
  "knownIssues": [],
  "environmentState": {
    "devServerRunning": false,
    "lastSuccessfulBuild": null,
    "lastTypeCheck": null
  }
}'

# ============================================================================
# 12. init.sh (inside .claude-harness for organization)
# ============================================================================

# Use heredoc with quoted delimiter to preserve all special characters
INIT_CONTENT=$(cat <<'INITEOF'
#!/bin/bash
# Development Environment Initializer (v3.0)

echo "=== Dev Environment Setup (v3.0 Memory Architecture) ==="
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

# Show memory status
echo ""
echo "=== Memory Layers Status ==="

# Working context
if [ -f ".claude-harness/memory/working/context.json" ]; then
    computed=$(grep -o '"computedAt":"[^"]*"' .claude-harness/memory/working/context.json 2>/dev/null | cut -d'"' -f4)
    echo "Working Context: Last compiled $computed"
else
    echo "Working Context: Not initialized"
fi

# Episodic memory
if [ -f ".claude-harness/memory/episodic/decisions.json" ]; then
    count=$(grep -c '"id":' .claude-harness/memory/episodic/decisions.json 2>/dev/null || echo "0")
    echo "Episodic Memory: $count decisions recorded"
else
    echo "Episodic Memory: Not initialized"
fi

# Procedural memory
if [ -f ".claude-harness/memory/procedural/failures.json" ]; then
    failures=$(grep -c '"id":' .claude-harness/memory/procedural/failures.json 2>/dev/null || echo "0")
    successes=$(grep -c '"id":' .claude-harness/memory/procedural/successes.json 2>/dev/null || echo "0")
    echo "Procedural Memory: $failures failures, $successes successes recorded"
else
    echo "Procedural Memory: Not initialized"
fi

# Check feature status
echo ""
echo "=== Features Status ==="
if [ -f ".claude-harness/features/active.json" ]; then
    pending=$(grep -c '"status":"pending"' .claude-harness/features/active.json 2>/dev/null || echo "0")
    in_progress=$(grep -c '"status":"in_progress"' .claude-harness/features/active.json 2>/dev/null || echo "0")
    needs_tests=$(grep -c '"status":"needs_tests"' .claude-harness/features/active.json 2>/dev/null || echo "0")
    echo "Pending: $pending | In Progress: $in_progress | Needs Tests: $needs_tests"
else
    echo "No features file found"
fi

# Archived features
if [ -f ".claude-harness/features/archive.json" ]; then
    archived=$(grep -c '"id":' .claude-harness/features/archive.json 2>/dev/null || echo "0")
    echo "Archived: $archived completed features"
fi

# Loop state
echo ""
echo "=== Agentic Loop State ==="
if [ -f ".claude-harness/loops/state.json" ]; then
    status=$(grep -o '"status":"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    feature=$(grep -o '"feature":"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    looptype=$(grep -o '"type":"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    linkedFeature=$(grep -o '"featureId":"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | head -1 | cut -d'"' -f4)
    if [ "$status" != "idle" ] && [ -n "$feature" ]; then
        attempt=$(grep -o '"attempt":[0-9]*' .claude-harness/loops/state.json 2>/dev/null | cut -d':' -f2)
        if [ "$looptype" = "fix" ]; then
            echo "ACTIVE FIX: $feature (attempt $attempt, status: $status)"
            echo "Linked to: $linkedFeature"
            echo "Resume with: /claude-harness:do $feature"
        else
            echo "ACTIVE LOOP: $feature (attempt $attempt, status: $status)"
            echo "Resume with: /claude-harness:do $feature"
        fi
    else
        echo "No active loop"
    fi
fi

# Pending fixes
if [ -f ".claude-harness/features/active.json" ]; then
    pendingFixes=$(grep -c '"type":"bugfix"' .claude-harness/features/active.json 2>/dev/null || echo "0")
    if [ "$pendingFixes" != "0" ]; then
        echo ""
        echo "Pending fixes: $pendingFixes"
    fi
fi

# Orchestration state
echo ""
echo "=== Orchestration State ==="
if [ -f ".claude-harness/agents/context.json" ]; then
    session=$(grep -o '"activeFeature":"[^"]*"' .claude-harness/agents/context.json 2>/dev/null | cut -d'"' -f4)
    if [ -n "$session" ]; then
        echo "Active orchestration: $session"
        echo "Run /claude-harness:orchestrate to resume"
    else
        echo "No active orchestration"
    fi
    handoffs=$(grep -c '"from":' .claude-harness/agents/handoffs.json 2>/dev/null || echo "0")
    if [ "$handoffs" != "0" ]; then
        echo "Pending handoffs: $handoffs"
    fi
else
    echo "No orchestration context yet"
fi

echo ""
echo "=== Environment Ready (v3.8) ==="
echo "Commands (6 total):"
echo "  /claude-harness:setup       - Initialize harness (one-time)"
echo "  /claude-harness:start       - Compile context, show GitHub dashboard"
echo "  /claude-harness:do          - Unified workflow (features + fixes)"
echo "  /claude-harness:checkpoint  - Save progress, persist memory"
echo "  /claude-harness:orchestrate - Spawn multi-agent team"
echo "  /claude-harness:merge       - Merge PRs, close issues"
INITEOF
)
create_file ".claude-harness/init.sh" "$INIT_CONTENT"
chmod +x .claude-harness/init.sh 2>/dev/null || true

# ============================================================================
# 12.5. hooks/ directory - Session hooks
# ============================================================================

mkdir -p hooks

# Session End Hook - Clean up inactive session directories
SESSION_END_HOOK=$(cat <<'SESSIONENDEOF'
#!/bin/bash
# Session End Hook - Clean up inactive session directories
# Runs automatically when a Claude Code session ends
# Only removes sessions where the PID is no longer running (inactive)

HARNESS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude-harness"
SESSIONS_DIR="$HARNESS_DIR/sessions"

# Exit if no sessions directory
[ -d "$SESSIONS_DIR" ] || exit 0

# Get current session ID from stdin (JSON input from SessionEnd hook)
INPUT=$(cat)
CURRENT_SESSION=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# Iterate through all session directories
for session_dir in "$SESSIONS_DIR"/*/; do
  [ -d "$session_dir" ] || continue

  session_id=$(basename "$session_dir")
  session_file="$session_dir/session.json"

  # Skip current session (the one that's ending)
  [ "$session_id" = "$CURRENT_SESSION" ] && continue

  # Skip if no session.json (malformed session)
  [ -f "$session_file" ] || continue

  # Get PID from session.json
  pid=$(jq -r '.pid // empty' "$session_file" 2>/dev/null)

  # If no PID or PID is not running, session is inactive - delete it
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    rm -rf "$session_dir"
  fi
done

exit 0
SESSIONENDEOF
)
create_file "hooks/session-end.sh" "$SESSION_END_HOOK"
chmod +x hooks/session-end.sh 2>/dev/null || true

# ============================================================================
# 13. .claude directory structure
# ============================================================================

mkdir -p .claude/commands

# ============================================================================
# 14. .claude/settings.local.json
# ============================================================================

create_file ".claude/settings.local.json" '{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/hooks/session-end.sh"
          }
        ]
      }
    ]
  },
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

# ============================================================================
# 15. /start command - Now with context compilation
# ============================================================================

create_file ".claude/commands/start.md" 'Run the initialization script and prepare for a new coding session:

## Phase 0: Auto-Migration
Check if legacy files exist and migrate them:
1. Root-level files (v1.x) -> .claude-harness/
2. v2.x structure -> v3.0 memory architecture (if needed)

## Phase 1: Context Compilation
1. Clear session context (.claude-harness/sessions/{session-id}/context.json)
2. Load active feature from .claude-harness/features/active.json
3. Query episodic memory for recent relevant decisions
4. Query semantic memory for project patterns
5. Query procedural memory for:
   - Failures to avoid (similar file patterns)
   - Successful approaches to reuse
6. Compute relevance scores, keep top entries
7. Write compiled context to sessions/{session-id}/context.json
8. Log compilation decisions

## Phase 2: Local Status
1. Execute `./.claude-harness/init.sh` to see environment status
2. Read compiled context from session-scoped context (.claude-harness/sessions/{session-id}/context.json)
3. Read `.claude-harness/features/active.json` to identify next priority

## Phase 3: Orchestration State
4. Read `.claude-harness/agents/context.json` if exists - check for pending handoffs
5. Read `.claude-harness/agents/handoffs.json` for queued handoffs

## Phase 4: GitHub Integration (if MCP configured)
6. Fetch GitHub dashboard: open issues, PRs, CI status
7. Sync GitHub Issues with .claude-harness/features/active.json

## Phase 5: Recommendations
8. Report:
   - Compiled context summary
   - Active feature and phase
   - Approaches to avoid (from failure memory)
   - Patterns to use (from success memory)
   - Recommended next action
' "command"

# ============================================================================
# 16. /checkpoint command - Now with memory persistence
# ============================================================================

create_file ".claude/commands/checkpoint.md" 'Create a checkpoint of the current session:

## Phase 1: Update Progress
1. Update `.claude-harness/claude-progress.json` with:
   - Summary of what was accomplished this session
   - Any blockers encountered
   - Recommended next steps
   - Update lastUpdated timestamp

## Phase 2: Persist Memory
2. Record decisions to episodic memory:
   - Add new entries to `.claude-harness/memory/episodic/decisions.json`
   - Prune old entries if > maxEntries (FIFO)

3. Update semantic memory:
   - Add discovered patterns to `.claude-harness/memory/semantic/architecture.json`
   - Update file structure mappings

4. Update procedural memory:
   - If verification PASSED: Add approach to `.claude-harness/memory/procedural/successes.json`
   - If verification FAILED: Add approach to `.claude-harness/memory/procedural/failures.json`
   - Extract patterns to `.claude-harness/memory/procedural/patterns.json`

## Phase 3: Run Verification
5. Run build/test commands appropriate for the project
6. Record results in loop state if active

## Phase 4: Git Operations
7. ALWAYS commit changes:
   - Stage all modified files (except secrets/env files)
   - Write descriptive commit message summarizing the work
   - Push to remote

## Phase 5: PR Management
8. If on a feature branch and GitHub MCP is available:
   - Check if PR exists for this branch
   - If no PR: Create PR with title, body linking to issue
   - If PR exists: Update PR description with latest progress
   - Update .claude-harness/features/active.json with prNumber

## Phase 6: Archive & Report
9. Archive completed features:
   - Find features with status=passing in active.json
   - Move to features/archive.json with archivedAt timestamp

10. Report final status:
    - Memory updates made
    - Build/test results
    - Commit hash and push status
    - PR URL (if created/updated)
    - Remaining work
' "command"

# ============================================================================
# 17. /do command - Unified workflow (features + fixes)
# ============================================================================

create_file ".claude/commands/do.md" '---
description: Unified workflow - create, plan, and implement features or fixes in one command
argumentsPrompt: Feature description, feature ID, or --fix flag (e.g., "Add dark mode", "feature-001", "--fix feature-001 Bug description")
---

Unified command that orchestrates the complete development workflow:

Arguments: $ARGUMENTS

## Argument Parsing

1. Detect argument type:
   - If starts with `--fix <feature-id>`: Create bug fix linked to feature
   - If matches `feature-\d+`: Resume existing feature
   - If matches `fix-feature-\d+-\d+`: Resume existing fix
   - If "resume": Resume last active workflow
   - Otherwise: Create new feature from description

2. Parse options:
   - `--fix <feature-id>`: Create bug fix linked to specified feature
   - `--quick`: Skip planning phase (for simple tasks)
   - `--auto`: No interactive prompts (full automation)
   - `--plan-only`: Stop after planning (review before implementation)

## Phase 1: Feature Creation (if new feature)

3. If creating new feature (no --fix flag):
   - Generate unique feature ID (feature-XXX based on existing IDs)
   - If GitHub MCP is available:
     - Create GitHub issue with title, description, labels
     - Create feature branch: `feature/feature-XXX`
     - Checkout the feature branch
   - Add to `.claude-harness/features/active.json`

## Phase 1a: Fix Creation (if --fix flag)

3a. If creating bug fix (`--fix <feature-id> "description"`):
    - Validate original feature exists in active.json or archive.json
    - Generate fix ID: `fix-{feature-id}-{NNN}`
    - Inherit verification commands from original feature
    - If GitHub MCP available: Create issue + branch
    - Add to `.claude-harness/features/active.json` fixes array

## Phase 2: Planning (unless --quick)

4. Load context from memory layers
5. Analyze requirements, identify files
6. Check past failures, suggest alternatives
7. Generate implementation plan

## Phase 3: Implementation

8. Initialize or resume agentic loop
9. Query procedural memory for failures to avoid
10. Execute implementation with verification
11. On success: Record to successes.json
12. On failure: Record to failures.json, retry

## Phase 4: Checkpoint (if confirmed or --auto)

13. Commit changes with appropriate prefix (feat: or fix:)
14. Push to remote, create/update PR
15. Auto-reflect on user corrections
16. Archive completed feature/fix

## Quick Reference

| Command | Behavior |
|---------|----------|
| `/claude-harness:do "Add X"` | Full workflow with prompts |
| `/claude-harness:do --fix feature-001 "Bug Y"` | Create bug fix linked to feature |
| `/claude-harness:do feature-001` | Resume existing feature |
| `/claude-harness:do fix-feature-001-001` | Resume existing fix |
| `/claude-harness:do resume` | Resume last active workflow |
| `/claude-harness:do --quick "Simple change"` | Skip planning phase |
| `/claude-harness:do --auto "Add Z"` | No prompts, full automation |
| `/claude-harness:do --plan-only "Big feature"` | Plan only, implement later |
' "command"

# ============================================================================
# 18. /merge command - Merge PRs, auto-version, release
# ============================================================================

create_file ".claude/commands/merge.md" '---
description: Merge all PRs, auto-version, create release
argumentsPrompt: Optional: specific version tag (e.g., v1.2.0). Defaults to auto-versioning.
---

Merge all open PRs, close related issues, create version tag and release:

Arguments: $ARGUMENTS (optional - specific version like v1.2.0, defaults to auto-versioning)

Requires GitHub MCP to be configured.

## Phase 1: Gather State
1. List all open PRs (features and fixes)
2. List all open issues with "feature" or "bugfix" labels
3. Read `.claude-harness/features/active.json` for linked issue/PR numbers
4. Get latest version tag from git

## Phase 2: Build Dependency Graph
5. Order PRs so dependent PRs merge after their base PRs

## Phase 3: Pre-merge Validation
6. For each PR: CI passes, no conflicts, has approvals

## Phase 4: Execute Merges
7. Merge in dependency order (squash preferred)
8. Close linked issues
9. Delete source branches

## Phase 5: Version Tagging
10. Auto-version based on PR types:
    - `feat:` PRs → bump MINOR
    - `fix:` PRs only → bump PATCH
    - `BREAKING CHANGE` → bump MAJOR
11. Create annotated git tag and push

## Phase 6: Release Notes
12. Create GitHub release with auto-generated notes

## Phase 7: Cleanup
13. Prune branches, switch to main, pull latest

## Phase 8: Report Summary
14. PRs merged, issues closed, version tag, release URL
' "command"

# ============================================================================
# 19. /orchestrate command - Multi-agent teams
# ============================================================================

create_file ".claude/commands/orchestrate.md" '---
description: Orchestrate multi-agent teams for complex features
argumentsPrompt: Feature ID or description to orchestrate
---

Orchestrate specialized agents to implement a feature or task:

Arguments: $ARGUMENTS

## Phase 1: Task Analysis
1. Identify target (feature ID or description)
2. Read orchestration context and learned patterns
3. Analyze task: file types, domains, security-sensitive ops

## Phase 2: Impact Analysis
4. Read dependency graph
5. Calculate impact score
6. Add mandatory quality agents for high-impact changes

## Phase 3: Agent Selection
7. Map requirements to agents:
   - Implementation: react-specialist, backend-developer, etc.
   - Quality: code-reviewer, security-auditor, qa-expert

## Phase 4: Failure Prevention Check
8. Check procedural/failures.json before spawning

## Phase 5: Agent Spawning
9. Build execution plan with groups
10. Provide context, failures to avoid, success patterns

## Phase 6: Coordination
11. Update agents/context.json, handle failures, manage handoffs

## Phase 7: Verification Loop
12. Run all verification commands, re-spawn on failure (max 3 cycles)

## Phase 8: Memory Persistence
13. Record successes/failures to procedural memory

## Phase 9: Report
14. Summary of agents, files, verification, next steps

Run `/claude-harness:checkpoint` after to commit changes.
' "command"

# ============================================================================
# 23. Update project .gitignore with harness ephemeral patterns
# ============================================================================

update_gitignore() {
    local GITIGNORE_FILE=".gitignore"
    local PATTERNS=(
        "# Claude Harness - Ephemeral/Per-Session State"
        ".claude-harness/sessions/"
        ".claude-harness/memory/compaction-backups/"
        ".claude-harness/memory/working/"
        ""
        "# Claude Code - Local settings"
        ".claude/settings.local.json"
    )

    # Create .gitignore if it doesn't exist
    if [ ! -f "$GITIGNORE_FILE" ]; then
        touch "$GITIGNORE_FILE"
        echo "  [CREATE] $GITIGNORE_FILE"
    fi

    local ADDED=0
    for pattern in "${PATTERNS[@]}"; do
        # Skip comments and empty lines for existence check
        if [[ "$pattern" == "#"* ]] || [[ -z "$pattern" ]]; then
            # Always add comments/empty lines if they don't exist as-is
            if ! grep -Fxq "$pattern" "$GITIGNORE_FILE" 2>/dev/null; then
                echo "$pattern" >> "$GITIGNORE_FILE"
            fi
            continue
        fi

        # Check if pattern already exists (use fixed string match, not regex)
        # Remove trailing slash for comparison
        local pattern_base="${pattern%/}"
        if ! grep -Fq "$pattern_base" "$GITIGNORE_FILE" 2>/dev/null; then
            echo "$pattern" >> "$GITIGNORE_FILE"
            ADDED=$((ADDED + 1))
        fi
    done

    if [ $ADDED -gt 0 ]; then
        echo "  [UPDATE] $GITIGNORE_FILE (added $ADDED harness patterns)"
    else
        echo "  [SKIP] $GITIGNORE_FILE (patterns already present)"
    fi
}

update_gitignore

# ============================================================================
# 24. Record plugin version for update detection
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_VERSION=$(grep '"version"' "$SCRIPT_DIR/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "4.2.0")
echo "$PLUGIN_VERSION" > .claude-harness/.plugin-version
echo "  [CREATE] .claude-harness/.plugin-version (v$PLUGIN_VERSION)"

# ============================================================================
# SETUP COMPLETE
# ============================================================================

echo ""
echo "=== Setup Complete (v4.2.3 - Removed legacy state files) ==="
echo ""
echo "Directory Structure (v3.0 Memory Architecture):"
echo "  .claude-harness/"
echo "  ├── memory/"
echo "  │   ├── working/context.json      (rebuilt each session)"
echo "  │   ├── episodic/decisions.json   (rolling window)"
echo "  │   ├── semantic/                 (persistent knowledge)"
echo "  │   │   ├── architecture.json"
echo "  │   │   ├── entities.json"
echo "  │   │   └── constraints.json"
echo "  │   └── procedural/               (success/failure patterns)"
echo "  │       ├── failures.json"
echo "  │       ├── successes.json"
echo "  │       └── patterns.json"
echo "  ├── impact/"
echo "  │   ├── dependency-graph.json"
echo "  │   └── change-log.json"
echo "  ├── features/"
echo "  │   ├── active.json"
echo "  │   ├── archive.json"
echo "  │   └── tests/"
echo "  ├── agents/"
echo "  │   ├── context.json"
echo "  │   └── handoffs.json"
echo "  ├── worktrees/"
echo "  │   └── registry.json         (worktree tracking)"
echo "  ├── loops/state.json"
echo "  ├── sessions/               (gitignored, per-instance)"
echo "  │   └── {uuid}/             (session-scoped state)"
echo "  └── config.json"
echo ""
echo "Commands (6 total):"
echo "  .claude/commands/setup.md           (initialize harness)"
echo "  .claude/commands/start.md           (compile context)"
echo "  .claude/commands/do.md              (unified workflow)"
echo "  .claude/commands/checkpoint.md      (save + persist memory)"
echo "  .claude/commands/orchestrate.md     (multi-agent)"
echo "  .claude/commands/merge.md           (merge PRs + release)"
echo ""
echo "=== GitHub MCP Setup (Optional) ==="
echo ""
echo "To enable GitHub integration:"
echo "  claude mcp add github -s user"
echo ""
echo "=== Next Steps ==="
echo ""
echo "  1. Edit CLAUDE.md to describe your project"
echo "  2. Run /claude-harness:start to compile context and see status"
echo "  3. Run /claude-harness:do \"feature description\" to create and implement features"
echo "  4. Run /claude-harness:do --fix feature-XXX \"bug\" to create bug fixes"
echo ""
echo "v4.2.0 Features (NEW):"
echo "  • Simplified /merge command - removed version tagging (use git/GitHub UI directly)"
echo ""
echo "v4.0.0+ Features (Existing):"
echo "  • PRD Analysis (/prd-breakdown) - Analyze Product Requirements Documents"
echo "  • Multi-agent Decomposition - Product Analyst, Architect, QA Lead work in parallel"
echo "  • Smart Feature Generation - Extracts requirements, resolves dependencies, assigns priorities"
echo "  • PRD Bootstrap - Quickly create feature lists for new projects"
echo "  • Flexible Input - Inline PRD, file-based, GitHub issues, or interactive paste"
echo "  • Git Worktree Support - True parallel development with isolated directories"
echo "  • Auto-worktree for /do - Each new feature gets its own worktree by default"
echo "  • --inline flag - Skip worktree for quick fixes in same directory"
echo "  • /worktree command - Manage worktrees (create, list, remove)"
echo "  • Worktree-aware /start - Detects worktree mode, loads shared state"
echo "  • Automatic Session Cleanup - Old sessions cleaned on exit (PID-based)"
echo "  • Parallel Work Streams - Multiple Claude instances on different features"
echo "  • Session-Scoped State - Isolated state per instance (sessions/{uuid}/)"
echo "  • 5-Layer Memory Architecture (Working/Episodic/Semantic/Procedural/Learned)"
echo "  • Failure Prevention (learns from mistakes)"
echo ""
