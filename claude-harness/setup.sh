#!/bin/bash
# Claude Code Long-Running Agent Harness Setup
# Based on: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
# Enhanced with: Context-Engine memory architecture, Agent-Foreman patterns, Anthropic autonomous-coding
#
# Usage:
#   curl -sL <url> | bash                    # New repo (interactive)
#   ./setup.sh                  # Run locally (skip existing files)
#   ./setup.sh --force          # Overwrite ALL files (use with caution)
#   ./setup.sh --force-commands # DEPRECATED — commands served from plugin cache
#   ./setup.sh --migrate        # Force migration from v2.x to v3.0

set -e

FORCE=false
FORCE_MIGRATE=false

case "$1" in
    --force)
        FORCE=true
        ;;
    --force-commands)
        echo "NOTE: --force-commands is deprecated. Commands are served from the plugin cache."
        echo "      Run 'claude plugin update' to update plugin commands."
        ;;
    --migrate)
        FORCE_MIGRATE=true
        ;;
esac

# Extract plugin version from plugin.json (single source of truth)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_VERSION=$(grep '"version"' "$SCRIPT_DIR/.claude-plugin/plugin.json" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "4.2.0")

echo "=== Claude Code Agent Harness Setup v${PLUGIN_VERSION} ==="
echo ""

# Auto-detect version upgrade: if installed version is older, force command updates
INSTALLED_VERSION=$(cat .claude-harness/.plugin-version 2>/dev/null || echo "0.0.0")
if [ "$INSTALLED_VERSION" != "$PLUGIN_VERSION" ] && [ "$INSTALLED_VERSION" != "0.0.0" ]; then
    echo "Version upgrade detected: v${INSTALLED_VERSION} -> v${PLUGIN_VERSION}"
    echo "Project files will be checked for migrations."
    echo ""

    # Run v6 migration if upgrading from v5.x or earlier
    MAJOR_OLD=$(echo "$INSTALLED_VERSION" | cut -d. -f1)
    if [ "$MAJOR_OLD" -lt 6 ] 2>/dev/null; then
        V6_MIGRATE=true
    fi
fi

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
    ACCEPTANCE_CMD=""

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

        # Detect acceptance/E2E test framework
        ACCEPTANCE_CMD=""
        if grep -q '"test:e2e"' package.json 2>/dev/null; then
            ACCEPTANCE_CMD="npm run test:e2e"
        elif grep -q '"test:acceptance"' package.json 2>/dev/null; then
            ACCEPTANCE_CMD="npm run test:acceptance"
        elif grep -q "playwright" package.json 2>/dev/null; then
            ACCEPTANCE_CMD="npx playwright test"
        elif grep -q "cypress" package.json 2>/dev/null; then
            ACCEPTANCE_CMD="npx cypress run"
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

        # Detect acceptance/E2E test directory
        ACCEPTANCE_CMD=""
        if [ -d "tests/acceptance" ]; then
            ACCEPTANCE_CMD="pytest tests/acceptance/"
        elif [ -d "tests/e2e" ]; then
            ACCEPTANCE_CMD="pytest tests/e2e/"
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
# Create file if it doesn't exist (or force is set)
create_file() {
    local filepath=$1
    local content=$2

    # Check if we should skip this file
    if [ -f "$filepath" ]; then
        if [ "$FORCE" = true ]; then
            : # Always overwrite with --force
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

# Migrate from v5.x to v6.0: remove worktrees, handoffs, stale commands
migrate_to_v6() {
    echo "Running v6.0 migration (cleanup legacy artifacts)..."
    CLEANED=0

    # Remove worktrees directory (legacy parallelism approach)
    if [ -d ".claude-harness/worktrees" ]; then
        rm -rf ".claude-harness/worktrees"
        echo "  [CLEANUP] Removed .claude-harness/worktrees/ (legacy)"
        CLEANED=$((CLEANED + 1))
    fi

    # Remove handoffs.json (legacy handoff mechanism)
    if [ -f ".claude-harness/agents/handoffs.json" ]; then
        rm -f ".claude-harness/agents/handoffs.json"
        echo "  [CLEANUP] Removed agents/handoffs.json (legacy)"
        CLEANED=$((CLEANED + 1))
    fi

    # Remove stale commands from target project (merged into flow.md in v5.2, worktree removed in v6)
    for stale_cmd in worktree.md do.md do-tdd.md orchestrate.md; do
        if [ -f ".claude/commands/$stale_cmd" ]; then
            rm -f ".claude/commands/$stale_cmd"
            echo "  [CLEANUP] Removed .claude/commands/$stale_cmd (obsolete command)"
            CLEANED=$((CLEANED + 1))
        fi
    done

    # Clean pendingHandoffs from agents/context.json
    if [ -f ".claude-harness/agents/context.json" ] && grep -q '"pendingHandoffs"' ".claude-harness/agents/context.json" 2>/dev/null; then
        # Remove the pendingHandoffs line (with optional trailing comma handling)
        sed -i '/"pendingHandoffs"/d' ".claude-harness/agents/context.json"
        echo "  [CLEANUP] Removed pendingHandoffs from agents/context.json"
        CLEANED=$((CLEANED + 1))
    fi

    if [ $CLEANED -gt 0 ]; then
        echo "  Cleaned $CLEANED v5.x artifact(s)"
    else
        echo "  No v5.x artifacts to clean"
    fi
    echo ""
}

# Run migrations
migrate_legacy_root_files

if [ "$FORCE_MIGRATE" = true ] || needs_migration; then
    migrate_v2_to_v3
fi

if [ "${V6_MIGRATE:-false}" = true ]; then
    migrate_to_v6
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
# 8. AGENTS: Orchestration context
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
  "agentResults": []
}'

# ============================================================================
# 8.5. PRD: Product Requirements Document analysis
# ============================================================================

create_file ".claude-harness/prd/analyst-prompts.json" '{
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
    "typecheck": "'$TYPECHECK_CMD'",
    "acceptance": "'$ACCEPTANCE_CMD'"
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
    computed=$(grep -o '"computedAt"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-harness/memory/working/context.json 2>/dev/null | cut -d'"' -f4)
    echo "Working Context: Last compiled $computed"
else
    echo "Working Context: Not initialized"
fi

# Episodic memory
if [ -f ".claude-harness/memory/episodic/decisions.json" ]; then
    count=$(grep -c '"id":' .claude-harness/memory/episodic/decisions.json 2>/dev/null) || count=0
    echo "Episodic Memory: $count decisions recorded"
else
    echo "Episodic Memory: Not initialized"
fi

# Procedural memory
if [ -f ".claude-harness/memory/procedural/failures.json" ]; then
    failures=$(grep -c '"id":' .claude-harness/memory/procedural/failures.json 2>/dev/null) || failures=0
    successes=$(grep -c '"id":' .claude-harness/memory/procedural/successes.json 2>/dev/null) || successes=0
    echo "Procedural Memory: $failures failures, $successes successes recorded"
else
    echo "Procedural Memory: Not initialized"
fi

# Check feature status
echo ""
echo "=== Features Status ==="
if [ -f ".claude-harness/features/active.json" ]; then
    pending=$(grep -c '"status"[[:space:]]*:[[:space:]]*"pending"' .claude-harness/features/active.json 2>/dev/null) || pending=0
    in_progress=$(grep -c '"status"[[:space:]]*:[[:space:]]*"in_progress"' .claude-harness/features/active.json 2>/dev/null) || in_progress=0
    needs_tests=$(grep -c '"status"[[:space:]]*:[[:space:]]*"needs_tests"' .claude-harness/features/active.json 2>/dev/null) || needs_tests=0
    echo "Pending: $pending | In Progress: $in_progress | Needs Tests: $needs_tests"
else
    echo "No features file found"
fi

# Archived features
if [ -f ".claude-harness/features/archive.json" ]; then
    archived=$(grep -c '"id":' .claude-harness/features/archive.json 2>/dev/null) || archived=0
    echo "Archived: $archived completed features"
fi

# Loop state
echo ""
echo "=== Agentic Loop State ==="
if [ -f ".claude-harness/loops/state.json" ]; then
    status=$(grep -o '"status"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    feature=$(grep -o '"feature"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    looptype=$(grep -o '"type"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | cut -d'"' -f4)
    linkedFeature=$(grep -o '"featureId"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-harness/loops/state.json 2>/dev/null | head -1 | cut -d'"' -f4)
    if [ "$status" != "idle" ] && [ -n "$feature" ]; then
        attempt=$(grep -o '"attempt"[[:space:]]*:[[:space:]]*[0-9]*' .claude-harness/loops/state.json 2>/dev/null | grep -o '[0-9]*')
        if [ "$looptype" = "fix" ]; then
            echo "ACTIVE FIX: $feature (attempt $attempt, status: $status)"
            echo "Linked to: $linkedFeature"
            echo "Resume with: /claude-harness:flow $feature (or /do for step-by-step)"
        else
            echo "ACTIVE LOOP: $feature (attempt $attempt, status: $status)"
            echo "Resume with: /claude-harness:flow $feature (or /do for step-by-step)"
        fi
    else
        echo "No active loop"
    fi
fi

# Pending fixes
if [ -f ".claude-harness/features/active.json" ]; then
    pendingFixes=$(grep -c '"type"[[:space:]]*:[[:space:]]*"bugfix"' .claude-harness/features/active.json 2>/dev/null) || pendingFixes=0
    if [ "$pendingFixes" != "0" ]; then
        echo ""
        echo "Pending fixes: $pendingFixes"
    fi
fi

# Orchestration state
echo ""
echo "=== Orchestration State ==="
if [ -f ".claude-harness/agents/context.json" ]; then
    session=$(grep -o '"activeFeature"[[:space:]]*:[[:space:]]*"[^"]*"' .claude-harness/agents/context.json 2>/dev/null | cut -d'"' -f4)
    if [ -n "$session" ]; then
        echo "Active orchestration: $session"
        echo "Run /claude-harness:flow to resume"
    else
        echo "No active orchestration"
    fi
else
    echo "No orchestration context yet"
fi

echo ""
DISPLAY_VERSION=$(cat .claude-harness/.plugin-version 2>/dev/null || echo "unknown")
echo "=== Environment Ready (v${DISPLAY_VERSION}) ==="
echo "Commands (5 total):"
echo "  /claude-harness:setup       - Initialize harness (one-time)"
echo "  /claude-harness:start       - Compile context, show GitHub dashboard"
echo "  /claude-harness:flow        - Unified workflow (recommended)"
echo "  /claude-harness:checkpoint  - Save progress, persist memory"
echo "  /claude-harness:merge       - Merge PRs, close issues"
echo "  Flags: --no-merge --plan-only --autonomous --quick --fix"
INITEOF
)
# init.sh is always refreshed (generated status script, not user-customizable)
echo "$INIT_CONTENT" > .claude-harness/init.sh
chmod +x .claude-harness/init.sh 2>/dev/null || true
echo "  [UPDATE] .claude-harness/init.sh (always refreshed)"

# ============================================================================
# 12.5. CLEANUP: Remove legacy hooks from target project
# ============================================================================
# Plugin hooks are served from hooks/hooks.json via ${CLAUDE_PLUGIN_ROOT}.
# Remove any legacy hook copies in the target project.

if [ -f "hooks/session-end.sh" ]; then
    rm -f "hooks/session-end.sh"
    echo "  [CLEANUP] Removed legacy hooks/session-end.sh (served from plugin cache)"
fi
if [ -d "hooks" ] && [ -z "$(ls -A hooks 2>/dev/null)" ]; then
    rmdir hooks 2>/dev/null
    echo "  [CLEANUP] Removed empty hooks/ directory"
fi

# Remove stale SessionEnd hook from settings.local.json (removed in v6.0.0)
if [ -f ".claude/settings.local.json" ] && grep -q '"SessionEnd"' ".claude/settings.local.json" 2>/dev/null; then
    python3 -c "
import json
with open('.claude/settings.local.json') as f:
    data = json.load(f)
if 'hooks' in data and 'SessionEnd' in data['hooks']:
    del data['hooks']['SessionEnd']
    if not data['hooks']:
        del data['hooks']
    with open('.claude/settings.local.json', 'w') as f:
        json.dump(data, f, indent=2)
        f.write('\n')
    print('  [CLEANUP] Removed stale SessionEnd hook from .claude/settings.local.json')
" 2>/dev/null
fi

# ============================================================================
# 13. .claude directory structure
# ============================================================================

mkdir -p .claude

# ============================================================================
# 14. .claude/settings.local.json
# ============================================================================

# settings.local.json: create if missing with default permissions.
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
# 15. CLEANUP: Remove legacy command copies from .claude/commands/
# ============================================================================
# Plugin commands are now served directly from the plugin cache.
# Remove any stale copies that were placed by older versions of setup.sh.

PLUGIN_COMMANDS_DIR="$SCRIPT_DIR/commands"
LOCAL_COMMANDS_DIR=".claude/commands"
CLEANED_COMMANDS=0

if [ -d "$LOCAL_COMMANDS_DIR" ]; then
    for cmd_file in "$PLUGIN_COMMANDS_DIR"/*.md; do
        [ -f "$cmd_file" ] || continue
        filename=$(basename "$cmd_file")
        target="$LOCAL_COMMANDS_DIR/$filename"
        if [ -f "$target" ]; then
            rm -f "$target"
            echo "  [CLEANUP] Removed legacy $target (served from plugin cache)"
            CLEANED_COMMANDS=$((CLEANED_COMMANDS + 1))
        fi
    done
    # Also clean up known obsolete commands
    for stale_cmd in worktree.md do.md do-tdd.md orchestrate.md prd-breakdown.md; do
        if [ -f "$LOCAL_COMMANDS_DIR/$stale_cmd" ]; then
            rm -f "$LOCAL_COMMANDS_DIR/$stale_cmd"
            echo "  [CLEANUP] Removed obsolete $LOCAL_COMMANDS_DIR/$stale_cmd"
            CLEANED_COMMANDS=$((CLEANED_COMMANDS + 1))
        fi
    done
    # Remove .claude/commands/ dir if now empty
    if [ -d "$LOCAL_COMMANDS_DIR" ] && [ -z "$(ls -A "$LOCAL_COMMANDS_DIR" 2>/dev/null)" ]; then
        rmdir "$LOCAL_COMMANDS_DIR" 2>/dev/null
        echo "  [CLEANUP] Removed empty $LOCAL_COMMANDS_DIR/"
    fi
fi
if [ $CLEANED_COMMANDS -gt 0 ]; then
    echo "  Cleaned $CLEANED_COMMANDS legacy command file(s)"
else
    echo "  No legacy command files to clean"
fi


# ============================================================================
# 16. Update project .gitignore with harness ephemeral patterns (was 20)
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
# 17. Record plugin version for update detection
# ============================================================================

# PLUGIN_VERSION and SCRIPT_DIR already set at top of script
echo "$PLUGIN_VERSION" > .claude-harness/.plugin-version
echo "  [CREATE] .claude-harness/.plugin-version (v$PLUGIN_VERSION)"

# ============================================================================
# SETUP COMPLETE
# ============================================================================

echo ""
echo "=== Setup Complete (v${PLUGIN_VERSION}) ==="
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
echo "  │   └── context.json"
echo "  ├── sessions/               (gitignored, per-instance)"
echo "  │   └── {uuid}/             (session-scoped state)"
echo "  └── config.json"
echo ""
echo "Commands (served from plugin cache):"
echo "  /claude-harness:*             (auto-discovered by Claude Code)"
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
echo "  3. Run /claude-harness:flow \"feature description\" for end-to-end automation (recommended)"
echo "  4. Run /claude-harness:flow --no-merge \"description\" for step-by-step control"
echo "  5. Run /claude-harness:flow --fix feature-XXX \"bug\" to create bug fixes"
echo ""
echo "v6.0.0 Changes:"
echo "  • Commands served from plugin cache (no longer copied to .claude/commands/)"
echo "  • Hooks consolidated: 6 registrations (safety, quality gates)"
echo "  • Update plugin via: claude plugin update claude-harness"
echo ""
