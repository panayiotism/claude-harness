#!/bin/bash
# Claude Code Long-Running Agent Harness Setup v3.3
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

echo "=== Claude Code Agent Harness Setup v3.3 ==="
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

mkdir -p .claude-harness/memory/working
mkdir -p .claude-harness/memory/episodic
mkdir -p .claude-harness/memory/semantic
mkdir -p .claude-harness/memory/procedural
mkdir -p .claude-harness/memory/learned
mkdir -p .claude-harness/impact
mkdir -p .claude-harness/features/tests
mkdir -p .claude-harness/agents
mkdir -p .claude-harness/loops

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
3. Read \`.claude-harness/memory/working/context.json\` for computed context
4. Check \`.claude-harness/features/active.json\` for current priorities

## Development Rules
- Work on ONE feature at a time
- Always run /checkpoint after completing work
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
See: \`.claude-harness/memory/working/context.json\` and \`.claude-harness/features/active.json\`

## Memory Architecture (v3.0)
- \`memory/working/\` - Current session context (rebuilt each session)
- \`memory/episodic/\` - Recent decisions (rolling window)
- \`memory/semantic/\` - Project knowledge (persistent)
- \`memory/procedural/\` - Success/failure patterns (append-only)
- \`memory/learned/\` - Rules from user corrections (append-only)
"

# ============================================================================
# 2. MEMORY LAYER: Working Context (rebuilt each session)
# ============================================================================

create_file ".claude-harness/memory/working/context.json" '{
  "version": 3,
  "computedAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "sessionId": null,
  "activeFeature": null,
  "relevantMemory": {
    "recentDecisions": [],
    "projectPatterns": [],
    "avoidApproaches": []
  },
  "currentTask": {
    "description": null,
    "files": [],
    "acceptanceCriteria": []
  },
  "compilationLog": []
}'

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
# 9. LOOPS: Agentic loop state
# ============================================================================

create_file ".claude-harness/loops/state.json" '{
  "version": 3,
  "feature": null,
  "featureName": null,
  "type": "feature",
  "linkedTo": {
    "featureId": null,
    "featureName": null
  },
  "status": "idle",
  "attempt": 0,
  "maxAttempts": 10,
  "startedAt": null,
  "lastAttemptAt": null,
  "verification": {
    "build": "'$BUILD_CMD'",
    "tests": "'$TEST_CMD'",
    "lint": "'$LINT_CMD'",
    "typecheck": "'$TYPECHECK_CMD'",
    "custom": []
  },
  "history": [],
  "lastCheckpoint": null,
  "escalationRequested": false
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

# ============================================================================
# 12. init.sh (inside .claude-harness for organization)
# ============================================================================

create_file ".claude-harness/init.sh" '#!/bin/bash
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
    computed=$(grep -o "\"computedAt\":\"[^\"]*\"" .claude-harness/memory/working/context.json 2>/dev/null | cut -d'"' -f4)
    echo "Working Context: Last compiled $computed"
else
    echo "Working Context: Not initialized"
fi

# Episodic memory
if [ -f ".claude-harness/memory/episodic/decisions.json" ]; then
    count=$(grep -c "\"id\":" .claude-harness/memory/episodic/decisions.json 2>/dev/null || echo "0")
    echo "Episodic Memory: $count decisions recorded"
else
    echo "Episodic Memory: Not initialized"
fi

# Procedural memory
if [ -f ".claude-harness/memory/procedural/failures.json" ]; then
    failures=$(grep -c "\"id\":" .claude-harness/memory/procedural/failures.json 2>/dev/null || echo "0")
    successes=$(grep -c "\"id\":" .claude-harness/memory/procedural/successes.json 2>/dev/null || echo "0")
    echo "Procedural Memory: $failures failures, $successes successes recorded"
else
    echo "Procedural Memory: Not initialized"
fi

# Check feature status
echo ""
echo "=== Features Status ==="
if [ -f ".claude-harness/features/active.json" ]; then
    pending=$(grep -c "\"status\":\"pending\"" .claude-harness/features/active.json 2>/dev/null || echo "0")
    in_progress=$(grep -c "\"status\":\"in_progress\"" .claude-harness/features/active.json 2>/dev/null || echo "0")
    needs_tests=$(grep -c "\"status\":\"needs_tests\"" .claude-harness/features/active.json 2>/dev/null || echo "0")
    echo "Pending: $pending | In Progress: $in_progress | Needs Tests: $needs_tests"
else
    echo "No features file found"
fi

# Archived features
if [ -f ".claude-harness/features/archive.json" ]; then
    archived=$(grep -c "\"id\":" .claude-harness/features/archive.json 2>/dev/null || echo "0")
    echo "Archived: $archived completed features"
fi

# Loop state
echo ""
echo "=== Agentic Loop State ==="
if [ -f ".claude-harness/loops/state.json" ]; then
    status=$(grep -o "\"status\":\"[^\"]*\"" .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    feature=$(grep -o "\"feature\":\"[^\"]*\"" .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    looptype=$(grep -o "\"type\":\"[^\"]*\"" .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    linkedFeature=$(grep -o "\"featureId\":\"[^\"]*\"" .claude-harness/loops/state.json 2>/dev/null | head -1 | cut -d'"' -f4)
    if [ "$status" != "idle" ] && [ -n "$feature" ]; then
        attempt=$(grep -o "\"attempt\":[0-9]*" .claude-harness/loops/state.json 2>/dev/null | cut -d':' -f2)
        if [ "$looptype" = "fix" ]; then
            echo "ACTIVE FIX: $feature (attempt $attempt, status: $status)"
            echo "Linked to: $linkedFeature"
            echo "Resume with: /claude-harness:implement $feature"
        else
            echo "ACTIVE LOOP: $feature (attempt $attempt, status: $status)"
            echo "Resume with: /claude-harness:implement $feature"
        fi
    else
        echo "No active loop"
    fi
fi

# Pending fixes
if [ -f ".claude-harness/features/active.json" ]; then
    pendingFixes=$(grep -c "\"type\":\"bugfix\"" .claude-harness/features/active.json 2>/dev/null || echo "0")
    if [ "$pendingFixes" != "0" ]; then
        echo ""
        echo "Pending fixes: $pendingFixes"
    fi
fi

# Orchestration state
echo ""
echo "=== Orchestration State ==="
if [ -f ".claude-harness/agents/context.json" ]; then
    session=$(grep -o "\"activeFeature\":\"[^\"]*\"" .claude-harness/agents/context.json 2>/dev/null | cut -d'"' -f4)
    if [ -n "$session" ]; then
        echo "Active orchestration: $session"
        echo "Run /claude-harness:orchestrate to resume"
    else
        echo "No active orchestration"
    fi
    handoffs=$(grep -c "\"from\":" .claude-harness/agents/handoffs.json 2>/dev/null || echo "0")
    if [ "$handoffs" != "0" ]; then
        echo "Pending handoffs: $handoffs"
    fi
else
    echo "No orchestration context yet"
fi

echo ""
echo "=== Environment Ready (v3.3) ==="
echo "Commands:"
echo "  /start           - Compile context, show GitHub dashboard"
echo "  /feature         - Add feature (generates tests first)"
echo "  /fix             - Create bug fix linked to a feature"
echo "  /plan-feature    - Plan implementation before coding"
echo "  /generate-tests  - Generate test cases for a feature"
echo "  /check-approach  - Check if approach matches past failures"
echo "  /implement       - Start agentic loop until tests pass"
echo "  /orchestrate     - Spawn multi-agent team"
echo "  /checkpoint      - Save progress, persist memory"
echo "  /merge-all       - Merge PRs, close issues"
'
chmod +x .claude-harness/init.sh 2>/dev/null || true

# ============================================================================
# 13. .claude directory structure
# ============================================================================

mkdir -p .claude/commands

# ============================================================================
# 14. .claude/settings.local.json
# ============================================================================

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

# ============================================================================
# 15. /start command - Now with context compilation
# ============================================================================

create_file ".claude/commands/start.md" 'Run the initialization script and prepare for a new coding session:

## Phase 0: Auto-Migration
Check if legacy files exist and migrate them:
1. Root-level files (v1.x) -> .claude-harness/
2. v2.x structure -> v3.0 memory architecture (if needed)

## Phase 1: Context Compilation
1. Clear .claude-harness/memory/working/context.json
2. Load active feature from .claude-harness/features/active.json
3. Query episodic memory for recent relevant decisions
4. Query semantic memory for project patterns
5. Query procedural memory for:
   - Failures to avoid (similar file patterns)
   - Successful approaches to reuse
6. Compute relevance scores, keep top entries
7. Write compiled context to working/context.json
8. Log compilation decisions

## Phase 2: Local Status
1. Execute `./.claude-harness/init.sh` to see environment status
2. Read `.claude-harness/memory/working/context.json` for compiled context
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
# 17. /feature command - Now with test-driven schema
# ============================================================================

create_file ".claude/commands/feature.md" '---
description: Add a new feature with test-driven approach
argumentsPrompt: Feature name and description
---

Add a new feature to .claude-harness/features/active.json:

Arguments: $ARGUMENTS

## Phase 1: Parse and Generate
1. Parse the feature description from arguments
2. Generate unique feature ID (feature-XXX based on existing IDs)

## Phase 2: GitHub Integration (if MCP available)
3. If GitHub MCP is available:
   - Create GitHub issue with:
     - Title: Feature name
     - Body: Description + verification steps checklist
     - Labels: ["feature", "claude-harness", priority label]
   - Create feature branch: `feature/feature-XXX`
   - Checkout the feature branch

## Phase 3: Create Feature Entry
4. Add to .claude-harness/features/active.json with v3.0 schema:
   ```json
   {
     "id": "feature-XXX",
     "name": "Feature name",
     "description": "Full description",
     "priority": 1,
     "status": "pending",
     "phase": "planning",
     "tests": {
       "generated": false,
       "file": null,
       "passing": 0,
       "total": 0
     },
     "verification": {
       "build": "<detected or default>",
       "tests": "<detected or default>",
       "lint": "<detected or default>",
       "typecheck": "<detected or default>",
       "custom": []
     },
     "attempts": 0,
     "maxAttempts": 10,
     "relatedFiles": [],
     "github": {
       "issueNumber": <from GitHub>,
       "prNumber": null,
       "branch": "feature/feature-XXX"
     },
     "createdAt": "<ISO timestamp>",
     "updatedAt": "<ISO timestamp>"
   }
   ```

## Phase 4: Recommend Next Steps
5. Confirm creation with:
   - Feature ID
   - GitHub issue URL (if created)
   - Branch name (if created)
   - **Recommended**: Run `/claude-harness:generate-tests feature-XXX` to generate test cases
   - Then: Run `/claude-harness:implement feature-XXX` to start implementation
' "command"

# ============================================================================
# 18. /generate-tests command - NEW for test-driven development
# ============================================================================

create_file ".claude/commands/generate-tests.md" '---
description: Generate test cases for a feature before implementation
argumentsPrompt: Feature ID (e.g., feature-001)
---

Generate test cases BEFORE implementation:

Arguments: $ARGUMENTS

## Core Principle
Test-driven development: Generate tests first, then implement to pass them.
This provides clear acceptance criteria and prevents "marking complete without testing".

## Phase 1: Load Feature
1. Parse feature ID from arguments
2. Read feature from .claude-harness/features/active.json
3. Verify feature exists and is in pending/planning phase

## Phase 2: Analyze Project
4. Read .claude-harness/memory/semantic/architecture.json for:
   - Test framework (jest, vitest, pytest, etc.)
   - Test directory structure
   - Existing test patterns

5. Read .claude-harness/memory/procedural/successes.json for:
   - Test patterns that worked before
   - File naming conventions

## Phase 3: Generate Test Cases
6. Based on feature description, generate test cases:
   - Unit tests for core functionality
   - Integration tests for API/database
   - Edge cases and error handling

7. Create test file at `.claude-harness/features/tests/{feature-id}.json`:
   ```json
   {
     "featureId": "feature-XXX",
     "generatedAt": "<ISO timestamp>",
     "framework": "jest|pytest|vitest",
     "cases": [
       {
         "id": "test-001",
         "type": "unit|integration|e2e",
         "description": "Should do X when Y",
         "file": "tests/path/to/test.ts",
         "status": "pending",
         "code": "test code here",
         "dependencies": []
       }
     ],
     "coverage": {
       "target": 80,
       "current": 0
     }
   }
   ```

## Phase 4: Create Test Files
8. Write actual test files to the project:
   - Create test file(s) based on project conventions
   - Tests should FAIL initially (no implementation yet)

9. Run tests to confirm they fail (expected)

## Phase 5: Update Feature
10. Update feature in active.json:
    - Set status to "needs_implementation"
    - Set phase to "test_generation"
    - Set tests.generated = true
    - Set tests.file = path to test spec
    - Set tests.total = number of test cases

## Phase 6: Report
11. Report:
    - Number of test cases generated
    - Test file locations
    - Expected failures (normal - no implementation yet)
    - **Next**: Run `/claude-harness:implement feature-XXX` to implement
' "command"

# ============================================================================
# 19. /plan-feature command - NEW for two-phase approach
# ============================================================================

create_file ".claude/commands/plan-feature.md" '---
description: Plan feature implementation before coding (Phase 1 of two-phase pattern)
argumentsPrompt: Feature ID to plan (e.g., feature-001)
---

Plan a feature before implementation (Two-Phase Pattern - Phase 1):

Arguments: $ARGUMENTS

## Core Principle
Separate planning from implementation for better outcomes.
This is Phase 1: Planning. Phase 2 is /implement.

## Phase 1: Load Context
1. Parse feature ID from arguments
2. Read feature from .claude-harness/features/active.json
3. Read compiled context from .claude-harness/memory/working/context.json
4. Read semantic memory for project architecture

## Phase 2: Analyze Requirements
5. Break down feature into sub-tasks
6. Identify files to create/modify
7. Identify dependencies on other features/modules

## Phase 3: Impact Analysis
8. Read .claude-harness/impact/dependency-graph.json
9. For each file to modify:
   - Identify dependent files (importedBy)
   - Identify related tests
   - Calculate impact score
10. Warn if high-impact changes detected

## Phase 4: Check Past Approaches
11. Read .claude-harness/memory/procedural/failures.json
12. Check if planned approach matches any past failures
13. If match found:
    - Warn about similar past failure
    - Show root cause and prevention tips
    - Suggest alternative approach from successes.json

## Phase 5: Generate Tests (if not done)
14. If feature.tests.generated = false:
    - Automatically run test generation
    - Or prompt to run /generate-tests first

## Phase 6: Create Implementation Plan
15. Write implementation plan to feature:
    ```json
    {
      "plan": {
        "steps": [
          {"step": 1, "description": "...", "files": [...]},
          ...
        ],
        "estimatedFiles": ["file1.ts", "file2.ts"],
        "impactScore": "low|medium|high",
        "risks": ["..."],
        "mitigations": ["..."]
      }
    }
    ```

## Phase 7: Update Feature
16. Update feature in active.json:
    - Set phase to "planned"
    - Store implementation plan

## Phase 8: Report
17. Report:
    - Implementation steps
    - Files to modify
    - Impact analysis
    - Risks and mitigations
    - Past failures to avoid
    - **Next**: Run `/claude-harness:implement feature-XXX` to start coding
' "command"

# ============================================================================
# 20. /check-approach command - NEW for failure prevention
# ============================================================================

create_file ".claude/commands/check-approach.md" '---
description: Check if a proposed approach matches past failures
argumentsPrompt: Describe the approach you plan to take
---

Check if your planned approach matches any past failures:

Arguments: $ARGUMENTS

## Core Principle
Learn from mistakes. Do not repeat approaches that failed before.

## Phase 1: Parse Approach
1. Extract approach description from arguments
2. Identify key elements:
   - Files involved
   - Technique/pattern being used
   - Problem being solved

## Phase 2: Query Failure Memory
3. Read .claude-harness/memory/procedural/failures.json
4. For each failure entry:
   - Calculate similarity score based on:
     - File overlap (same files affected)
     - Technique similarity (same approach)
     - Problem similarity (same type of issue)
   - If similarity > 0.7, flag as potential match

## Phase 3: Report Matches
5. If matches found:
   ```
   ⚠️  SIMILAR APPROACH FAILED BEFORE

   Failure: {failure description}
   When: {timestamp}
   Files: {affected files}
   Error: {error messages}
   Root Cause: {why it failed}

   Prevention Tip: {how to avoid}
   ```

## Phase 4: Suggest Alternatives
6. Read .claude-harness/memory/procedural/successes.json
7. Find successful approaches for similar problems
8. Report alternatives:
   ```
   ✅ SUCCESSFUL ALTERNATIVE

   Approach: {description}
   When: {timestamp}
   Files: {files}
   Why it worked: {rationale}
   ```

## Phase 5: Recommendation
9. If high-similarity failure found:
   - Recommend NOT proceeding with current approach
   - Suggest specific alternative

10. If no matches:
    - "No similar failures found. Proceed with caution."
    - Still recommend running tests frequently
' "command"

# ============================================================================
# 21. /implement command - Enhanced with failure check and test-driven loop
# ============================================================================

create_file ".claude/commands/implement.md" '---
description: Start or resume an agentic loop to implement a feature until verification passes
argumentsPrompt: Feature ID to implement (e.g., feature-001)
---

Implement a feature using a persistent agentic loop until tests pass:

Arguments: $ARGUMENTS

## Core Principle
"Claude marked features complete without proper testing" - NEVER trust self-assessment.
Always run actual verification commands. Tests must pass.

## Loop Cycle (v3.0 Enhanced)

### Phase 0: Load State
1. Read .claude-harness/loops/state.json
2. If status != idle and feature matches: RESUME
3. Otherwise: INITIALIZE new loop

### Phase 1: Pre-Implementation Checks
4. **FAILURE PREVENTION**: Query .claude-harness/memory/procedural/failures.json
   - Check if planned approach matches past failures
   - If match found: WARN and suggest alternative
   - If critical match: BLOCK and require acknowledgment

5. **TEST READINESS**: Check if tests are generated
   - If feature.tests.generated = false: Run /generate-tests first
   - Tests must exist before implementation

### Phase 2: Health Check
6. Run baseline verification to ensure environment works:
   - Build command: {from config or feature}
   - If baseline fails: Report and exit (environment issue)

### Phase 3: Attempt Implementation
7. Plan approach (record in history)
8. Execute implementation
9. Record files modified

### Phase 4: Verification (MANDATORY)
10. Run ALL verification commands:
    - Build: {build command}
    - Tests: {test command}
    - Lint: {lint command}
    - Typecheck: {typecheck command}
    - Custom: {any custom commands}

11. ALL must pass. Partial success = failure.

### Phase 5A: On Success
12. Update .claude-harness/loops/state.json: status = "completed"
13. Update feature status to "passing"
14. **PERSIST SUCCESS**: Add to .claude-harness/memory/procedural/successes.json:
    ```json
    {
      "id": "uuid",
      "timestamp": "ISO",
      "feature": "feature-XXX",
      "approach": "What worked",
      "files": ["modified files"],
      "verificationResults": {"build": "passed", ...},
      "patterns": ["reusable patterns discovered"]
    }
    ```
15. Git commit with descriptive message
16. Report success, recommend /checkpoint

### Phase 5B: On Failure
17. **PERSIST FAILURE**: Add to .claude-harness/memory/procedural/failures.json:
    ```json
    {
      "id": "uuid",
      "timestamp": "ISO",
      "feature": "feature-XXX",
      "attempt": N,
      "approach": "What was tried",
      "files": ["affected files"],
      "errors": ["error messages"],
      "rootCause": "Analysis of why it failed",
      "tags": ["type-error", "test-failure"],
      "prevention": "How to avoid in future"
    }
    ```
18. Increment attempt counter
19. Analyze errors, formulate different approach
20. If attempt < maxAttempts: RETRY (go to Phase 3)
21. If attempt >= maxAttempts: ESCALATE

### Phase 6: Escalation
22. Update status to "escalated"
23. Generate escalation report:
    - All attempts and their outcomes
    - Error patterns observed
    - Suggested manual intervention
24. Do NOT mark feature as complete

## Session Continuity

Loop state persists in .claude-harness/loops/state.json across context windows.
SessionStart hook shows active loops and prompts to resume.

## Commands

- Start/resume: `/claude-harness:implement feature-001`
- With more attempts: `/claude-harness:implement feature-001 --max-attempts 20`
- Skip failure check: `/claude-harness:implement feature-001 --skip-failure-check` (not recommended)
' "command"

# ============================================================================
# 22. /merge-all command
# ============================================================================

create_file ".claude/commands/merge-all.md" 'Merge all open PRs, close related issues, and delete branches in dependency order:

Requires GitHub MCP to be configured.

## Phase 1: Gather State
1. List all open PRs for this repository
2. List all open issues with "feature" label
3. Read .claude-harness/features/active.json for linked issue/PR numbers

## Phase 2: Build Dependency Graph
4. For each PR, check if its base branch is another feature branch (not main/master)
5. Order PRs so that dependent PRs are merged after their base PRs
6. If PR A base is PR B head branch, merge B first

## Phase 3: Pre-merge Validation
7. For each PR:
   - CI status passes
   - No merge conflicts
   - Has required approvals (if any)
8. Report any PRs that cannot be merged and why

## Phase 4: Execute Merges
9. Merge in dependency order:
   - Merge the PR (squash merge preferred)
   - Wait for merge to complete
   - Find and close any linked issues
   - Delete the source branch
   - Update features/active.json: set status=passing

## Phase 5: Cleanup
10. Prune local branches: `git fetch --prune`
11. Delete local feature branches that were merged
12. Switch to main/master branch

## Phase 6: Archive & Report
13. Move completed features to archive
14. Report summary:
    - PRs merged (with commit hashes)
    - Issues closed
    - Branches deleted
    - Features archived
    - Any failures or skipped items
' "command"

# ============================================================================
# 23. /orchestrate command - Enhanced with impact analysis
# ============================================================================

create_file ".claude/commands/orchestrate.md" '---
description: Orchestrate multi-agent teams for complex features
argumentsPrompt: Feature ID or description to orchestrate
---

Orchestrate specialized agents to implement a feature or task:

Arguments: $ARGUMENTS

## Phase 1: Task Analysis

1. Identify the target:
   - If $ARGUMENTS matches a feature ID, read from features/active.json
   - Otherwise, treat as task description

2. Read orchestration context:
   - Read `.claude-harness/agents/context.json`
   - Read `.claude-harness/memory/procedural/` for learned patterns

3. Analyze the task:
   - Identify file types to modify
   - Detect domains (frontend, backend, database, testing)
   - Check for security-sensitive operations

## Phase 2: Impact Analysis (NEW in v3.0)

4. Read `.claude-harness/impact/dependency-graph.json`
5. For each file in scope:
   - Identify dependents (importedBy)
   - Identify related tests
   - Calculate impact score
6. If high impact: Add code-reviewer and qa-expert to mandatory agents

## Phase 3: Agent Selection

7. Map requirements to agents:

   **Implementation Agents:**
   | Domain | Agent | Triggers |
   |--------|-------|----------|
   | React/Frontend | react-specialist | .tsx, .jsx, component |
   | Backend/API | backend-developer | route.ts, api/ |
   | Next.js | nextjs-developer | app/, pages/ |
   | Database | database-administrator | prisma, SQL |
   | Python | python-pro | .py files |
   | TypeScript | typescript-pro | complex types |

   **Quality Agents (mandatory for code):**
   | Type | Agent | When |
   |------|-------|------|
   | Review | code-reviewer | Always for code changes |
   | Security | security-auditor | Auth, tokens, encryption |
   | Testing | qa-expert | New features, bug fixes |

## Phase 4: Failure Prevention Check

8. Before spawning agents, check procedural/failures.json:
   - Any similar tasks that failed?
   - What approaches to avoid?
   - What worked for similar tasks?

## Phase 5: Agent Spawning

9. Build execution plan:
   - Group 1: Analysis/research agents
   - Group 2: Implementation agents (parallel if independent)
   - Group 3: Quality agents (code-reviewer, security-auditor)
   - Group 4: Documentation agents

10. For each agent, provide:
    - Shared context from agents/context.json
    - Failure patterns to avoid
    - Success patterns to use
    - Specific task assignment

## Phase 6: Coordination

11. After each agent:
    - Update agents/context.json with results
    - Handle failures (retry or fallback)
    - Manage handoffs via agents/handoffs.json

## Phase 7: Verification Loop

12. After all agents complete:
    - Run all verification commands
    - If ANY fail: Re-spawn relevant agents
    - Max 3 retry cycles

## Phase 8: Memory Persistence

13. Update procedural memory:
    - Record successful approaches
    - Record any failures

## Phase 9: Report

14. Report summary:
    - Agents invoked and status
    - Files created/modified
    - Impact analysis results
    - Verification results
    - Decisions recorded
    - Next steps

Run `/checkpoint` after to commit changes.
' "command"

# ============================================================================
# 24. Record plugin version for update detection
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_VERSION=$(grep '"version"' "$SCRIPT_DIR/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "3.3.1")
echo "$PLUGIN_VERSION" > .claude-harness/.plugin-version
echo "  [CREATE] .claude-harness/.plugin-version (v$PLUGIN_VERSION)"

# ============================================================================
# SETUP COMPLETE
# ============================================================================

echo ""
echo "=== Setup Complete (v3.3 - Self-Improving Skills) ==="
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
echo "  ├── loops/state.json"
echo "  └── config.json"
echo ""
echo "Commands:"
echo "  .claude/commands/start.md           (compile context)"
echo "  .claude/commands/feature.md         (add feature)"
echo "  .claude/commands/generate-tests.md  (test-driven development)"
echo "  .claude/commands/plan-feature.md    (two-phase planning)"
echo "  .claude/commands/check-approach.md  (failure prevention)"
echo "  .claude/commands/implement.md       (agentic loop)"
echo "  .claude/commands/orchestrate.md     (multi-agent)"
echo "  .claude/commands/checkpoint.md      (save + persist memory)"
echo "  .claude/commands/merge-all.md       (merge PRs)"
echo ""
echo "=== GitHub MCP Setup (Optional) ==="
echo ""
echo "To enable GitHub integration:"
echo "  claude mcp add github -s user"
echo ""
echo "=== Next Steps ==="
echo ""
echo "  1. Edit CLAUDE.md to describe your project"
echo "  2. Run /start to compile context and see status"
echo "  3. Run /feature to add features (tests generated first)"
echo "  4. Run /implement to start test-driven implementation"
echo ""
echo "v3.3 Features:"
echo "  • Self-Improving Skills (/reflect) - Learn from user corrections"
echo "  • Bug Fix Command (/fix) - Create fixes linked to original features"
echo "  • 5-Layer Memory Architecture (Working/Episodic/Semantic/Procedural/Learned)"
echo "  • Failure Prevention (learns from mistakes)"
echo "  • Impact Analysis (warns about breaking changes)"
echo "  • Test-Driven Features (generate tests before implementation)"
echo "  • Two-Phase Pattern (plan-feature -> implement)"
echo "  • Context Compilation (fresh, relevant context each session)"
echo ""
