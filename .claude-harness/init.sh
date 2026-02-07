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
echo "  /claude-harness:flow        - Unified workflow with Agent Teams (recommended)"
echo "  /claude-harness:checkpoint  - Save progress, persist memory"
echo "  /claude-harness:merge       - Merge PRs, close issues"
echo "  Flags: --no-merge --plan-only --autonomous --quick --fix"
