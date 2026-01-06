# v3.2.0 Release Notes - Memory System Utilization

**Release Date**: 2026-01-06

## Overview

This release implements the 4-layer memory system that was designed in v3.1.0 but never actually utilized by commands. Commands now actively read from and write to the memory layers, enabling true cross-session learning.

## What's New

### `/start` - Context Compilation (Phase 1)

The start command now compiles working context from all memory layers:

```
/claude-harness:start

Phase 1: Context Compilation
├── Clear/initialize working context
├── Query procedural memory for failures to avoid
├── Query procedural memory for successful approaches
├── Query episodic memory for recent decisions
├── Write compiled context to memory/working/context.json
└── Display "Approaches to AVOID" if failures exist
```

### `/implement` - Memory-Aware Implementation

The implement command now queries and records to memory:

**Before Implementation (Phase 0.5)**:
```
/claude-harness:implement feature-001

Phase 0.5: Query Failure Memory
├── Read procedural/failures.json
├── Filter by relevant files, tags, or feature
├── Read procedural/successes.json
└── Display warnings if similar approaches failed before
```

**After Verification**:
- On **success**: Records approach to `procedural/successes.json`
- On **failure**: Records approach + error details to `procedural/failures.json`

### `/checkpoint` - Memory Persistence (Phase 1.6)

The checkpoint command now persists session knowledge:

```
/claude-harness:checkpoint

Phase 1.6: Persist to Memory Layers
├── Persist decisions to episodic/decisions.json
├── Update semantic/architecture.json with discovered patterns
├── Update semantic/entities.json with new components
└── Update procedural/patterns.json with learned patterns
```

## Memory Architecture

```
.claude-harness/memory/
├── working/context.json     # Rebuilt each session (computed)
├── episodic/decisions.json  # Rolling window of recent decisions
├── semantic/                # Persistent project knowledge
│   ├── architecture.json
│   ├── entities.json
│   └── constraints.json
└── procedural/              # Success/failure patterns (append-only)
    ├── failures.json        # Approaches that failed
    ├── successes.json       # Approaches that worked
    └── patterns.json        # Learned patterns
```

## Files Changed

- `commands/start.md` - Added Phase 1: Context Compilation
- `commands/implement.md` - Added Phase 0.5: Memory Queries, success/failure recording
- `commands/checkpoint.md` - Added Phase 1.6: Memory Persistence

## Breaking Changes

None - existing installations will automatically benefit from memory utilization.

## Upgrade

No action required. The memory system will start being utilized on your next session.

---
Generated with [Claude Code](https://claude.ai/claude-code)
