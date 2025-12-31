# Release v2.6.0 - Agentic Loops

## What's Changed

### Features
- **Agentic Loops**: Autonomous loops that continue until verification passes, even across multiple context windows (#9) @panayiotism

### New Command: `/claude-harness:implement <feature-id>`

Runs autonomous loops until verification passes:
- **Health Check** - Ensure environment works before starting
- **Attempt** - Execute implementation
- **Verify** - Run build/tests/lint/typecheck (MANDATORY)
- **Retry** - Analyze errors and try different approach
- **Escalate** - After maxAttempts, request human intervention

### Session Continuity

Loop state persists in `.claude-harness/loop-state.json`:
- Survives context window limits
- Resume exactly where you left off
- SessionStart hook shows active loops and prompt to resume

Based on [Anthropic's insight](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents): "Claude marked features complete without proper testing" - so we **never trust self-assessment**. All verification is mandatory.

**Full Changelog**: https://github.com/panayiotism/claude-harness/compare/v2.5.1...v2.6.0
