# Checkpoint - Detailed Phases (within Flow)

Covers Phase 5 (Auto-Checkpoint) which triggers when verification passes. This mirrors the standalone checkpoint skill to ensure all memory layers are updated.

## Phase 5.1: Update Progress

Update `.claude-harness/claude-progress.json` with:
- Summary of what was accomplished this session
- Any blockers encountered
- Recommended next steps
- Update lastUpdated timestamp

## Phase 5.2: Capture Working Context

Update session-scoped working context `.claude-harness/sessions/{session-id}/working-context.json`:
- Set `activeFeature`, `summary`
- Populate `workingFiles` from feature's `relatedFiles` + `git status`
- Populate `decisions` with key architectural/implementation decisions made
- Set `nextSteps` to immediate actionable items
- Keep concise (~25-40 lines)

## Phase 5.2.5: Compile Session Briefing

**Write persistent session briefing** to `.claude-harness/session-briefing.md`:
- This file is automatically injected into Claude's context at every SessionStart (via the hook)
- Ensures Claude is immediately aware of project state on new sessions without manual `/start`
- Compile from current state -- read features, decisions, failures, rules, and status:

```markdown
# Session Briefing
Last updated: {ISO timestamp}

## Active Features
- {id}: {name} [{status}]
  {one-line description}
  Acceptance: {N} scenarios | Files: {relatedFiles summary}

## Recent Decisions (last 5)
- {decision} ({feature}, {date})

## Approaches to AVOID
- {approach} -> {rootCause} ({feature})

## Learned Rules
- {title}: {description}

## Current Status
Last checkpoint: {commit message summary}
Branch: {current branch}
Next steps: {from working-context nextSteps}
```

- Keep under 120 lines (~1500 tokens) to avoid context bloat
- Source data: `${FEATURES_FILE}`, `${MEMORY_DIR}/episodic/decisions.json`, `${MEMORY_DIR}/procedural/failures.json`, `${MEMORY_DIR}/learned/rules.json`
- This file is git-tracked and persists across sessions, `/clear`, and machine reboots

## Phase 5.3: Persist to Memory Layers

1. **Persist session decisions to episodic memory**:
   - Read `${MEMORY_DIR}/episodic/decisions.json`
   - For each key decision, append entry with id, timestamp, feature, decision, rationale, alternatives, impact
   - If entries exceed `maxEntries` (50), remove oldest (FIFO)
   - Write updated file

2. **Update semantic memory with discovered patterns**:
   - Read `${MEMORY_DIR}/semantic/architecture.json`
   - Update `structure`, `patterns.naming`, `patterns.fileOrganization`, `patterns.codeStyle` based on work done
   - Write updated file

3. **Update semantic entities** (if new concepts discovered):
   - Read `${MEMORY_DIR}/semantic/entities.json`
   - Append new concepts/entities with name, type, location, relationships
   - Write updated file

4. **Update procedural patterns**:
   - Read `${MEMORY_DIR}/procedural/patterns.json`
   - Extract reusable patterns (code patterns, naming conventions, project-specific rules)
   - Merge into existing (don't duplicate)
   - Write updated file

## Phase 5.4: Auto-Reflect on User Corrections

- Scan conversation for user correction patterns
- For corrections with high confidence: auto-save to `${MEMORY_DIR}/learned/rules.json`
- For lower confidence: queue for manual review
- Display results if rules extracted; continue silently if none detected

## Phase 5.5: Persist Orchestration Memory

- Read `.claude-harness/agents/context.json`
- For completed agent results: add to `${MEMORY_DIR}/procedural/successes.json`
- For failed agent results: add to `${MEMORY_DIR}/procedural/failures.json`
- Merge `discoveredPatterns` into `${MEMORY_DIR}/procedural/patterns.json`
- Persist `architecturalDecisions` to `${MEMORY_DIR}/episodic/decisions.json`
- Clear `agentResults`, set `currentSession` to null

## Phase 5.6: Commit, Push, PR

1. Commit `feat(feature-XXX): {description}`, push to remote
2. Create/update PR via `mcp__github__create_pull_request`: title, body with `Closes #{issue}`
3. Mark Checkpoint task completed
4. Display checkpoint summary: commit hash, PR number, task status
