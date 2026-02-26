#!/bin/bash
# SubagentStart Hook - Context injection for Agent Team teammates
# Injects feature context, verification commands, acceptance criteria,
# and past failures into teammate context at spawn time.
# Outputs JSON with additionalContext in hookSpecificOutput.

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Find project root
PROJECT_ROOT="$(pwd)"
while [ "$PROJECT_ROOT" != "/" ]; do
    [ -d "$PROJECT_ROOT/.claude-harness" ] && break
    PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done

if [ ! -d "$PROJECT_ROOT/.claude-harness" ]; then
    # No harness — no context to inject
    echo '{}'
    exit 0
fi

CONFIG_FILE="$PROJECT_ROOT/.claude-harness/config.json"
FEATURES_FILE="$PROJECT_ROOT/.claude-harness/features/active.json"
FAILURES_FILE="$PROJECT_ROOT/.claude-harness/memory/procedural/failures.json"
RULES_FILE="$PROJECT_ROOT/.claude-harness/memory/learned/rules.json"

# Find active session dir (most recent session with loop-state)
SESSION_DIR=""
if [ -d "$PROJECT_ROOT/.claude-harness/sessions" ]; then
    for dir in "$PROJECT_ROOT/.claude-harness/sessions"/*/; do
        [ -f "${dir}loop-state.json" ] && SESSION_DIR="$dir"
    done
fi

# Build context using python3 for JSON handling
if command -v python3 >/dev/null 2>&1; then
    CONTEXT=$(python3 -c "
import json, sys, os

context_parts = []

# 1. Active loop state (feature info, attempt count)
session_dir = '$SESSION_DIR'
if session_dir and os.path.isfile(os.path.join(session_dir, 'loop-state.json')):
    with open(os.path.join(session_dir, 'loop-state.json')) as f:
        loop = json.load(f)
    if loop.get('status') == 'in_progress':
        context_parts.append(f\"Feature: {loop.get('feature', '?')} - {loop.get('featureName', '?')}\")
        context_parts.append(f\"Attempt: {loop.get('attempt', 0)}/{loop.get('maxAttempts', 15)}\")

# 2. Verification commands from config
config_file = '$CONFIG_FILE'
if os.path.isfile(config_file):
    with open(config_file) as f:
        config = json.load(f)
    v = config.get('verification', {})
    cmds = [f'{k}: {v[k]}' for k in ['build', 'tests', 'lint', 'typecheck', 'acceptance'] if v.get(k)]
    if cmds:
        context_parts.append('Verification: ' + ' | '.join(cmds))

# 3. Acceptance criteria from active feature
features_file = '$FEATURES_FILE'
if os.path.isfile(features_file):
    with open(features_file) as f:
        features = json.load(f)
    # Find the in_progress feature
    for feat in features.get('features', []):
        if feat.get('status') == 'in_progress':
            criteria = feat.get('acceptanceCriteria', [])
            if criteria:
                scenarios = [c.get('scenario', '') for c in criteria[:5]]
                context_parts.append('Acceptance criteria: ' + '; '.join(scenarios))
            break

# 4. Last 3 failures from procedural memory
failures_file = '$FAILURES_FILE'
if os.path.isfile(failures_file):
    with open(failures_file) as f:
        fail_data = json.load(f)
    entries = fail_data.get('entries', [])[-3:]
    if entries:
        avoid = [f\"{e.get('approach', '?')} ({e.get('rootCause', '?')})\" for e in entries]
        context_parts.append('Avoid: ' + '; '.join(avoid))

# 5. Learned rules (titles only)
rules_file = '$RULES_FILE'
if os.path.isfile(rules_file):
    with open(rules_file) as f:
        rules_data = json.load(f)
    rules = [r.get('title', '') for r in rules_data.get('rules', []) if r.get('active', True)][:5]
    if rules:
        context_parts.append('Rules: ' + '; '.join(rules))

# Build output JSON (keep under 500 chars for token efficiency)
additional = ' | '.join(context_parts)
if len(additional) > 500:
    additional = additional[:497] + '...'

output = {
    'hookSpecificOutput': {
        'additionalContext': additional
    }
} if additional else {}

print(json.dumps(output))
" 2>/dev/null || echo '{}')
else
    CONTEXT='{}'
fi

echo "$CONTEXT"
exit 0
