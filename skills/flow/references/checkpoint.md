# Checkpoint - Detailed Phases (within Flow)

Covers Phase 5 (Auto-Checkpoint) which triggers when verification passes. This mirrors the standalone checkpoint skill to ensure all memory layers are updated.

## Phase 5.1: Update Progress

Update `.claude-harness/claude-progress.json` with:
- Summary of what was accomplished this session
- Any blockers encountered
- Recommended next steps
- Update lastUpdated timestamp

## Phase 5.2: Compile Session Briefing

**Write persistent session briefing** to `.claude-harness/session-briefing.md`:
- The SessionStart hook points Claude at this file on every new session
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
Next steps: {immediate actionable items}
```

- Keep under 120 lines (~1500 tokens) to avoid context bloat
- Source data: `${FEATURES_FILE}` plus the OKF memory bundle at `${MEMORY_DIR}` (`decisions/`, `failures/`, `rules/` concept files) -- or run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/compile-briefing.py" .claude-harness --write` to generate it
- This file is git-tracked and persists across sessions, `/clear`, and machine reboots

## Phase 5.3: Persist to Memory Layers (OKF bundle)

Memory layers are an OKF v0.1 bundle at `${MEMORY_DIR}`: one markdown concept file per entry with YAML frontmatter (required `type` field). See `schemas/okf-memory.md` for the concept file format per layer.

1. **Persist session decisions** to `${MEMORY_DIR}/decisions/`:
   - For each key decision, write a concept file `dec-{NNN}-{slug}.md` (next NNN from existing files):
     ```markdown
     ---
     type: Decision
     id: dec-{NNN}
     title: "{decision, <=80 chars}"
     timestamp: {ISO timestamp}
     feature: {feature-id}
     ---

     # {full decision text}

     ## Rationale
     {why}

     ## Alternatives
     - {other options considered}

     ## Impact
     {files or areas affected}
     ```
   - Append a `* [{id}: {title}](/decisions/{filename}) - {short description}` line to `${MEMORY_DIR}/decisions/index.md`
   - Rolling window: if more than 50 decision concepts exist, delete the oldest files and their index lines (FIFO)

2. **Update semantic memory with discovered patterns** (stays JSON):
   - Read `${MEMORY_DIR}/semantic/architecture.json`
   - Update `structure`, `patterns.naming`, `patterns.fileOrganization`, `patterns.codeStyle` based on work done
   - Write updated file

3. **Update semantic entities** (if new concepts discovered, stays JSON):
   - Read `${MEMORY_DIR}/semantic/entities.json`
   - Append new concepts/entities with name, type, location, relationships
   - Write updated file

4. **Persist reusable patterns** to `${MEMORY_DIR}/patterns/`:
   - For each new reusable pattern (skip ones already in existing concepts), write `pat-{NNN}-{slug}.md` with frontmatter `type: Pattern`, `id`, `title` and body `# {pattern}` + `## Source`
   - Append matching lines to `${MEMORY_DIR}/patterns/index.md`

## Phase 5.4: Auto-Reflect on User Corrections

- Scan conversation for user correction patterns
- For corrections with high confidence: write a concept file to `${MEMORY_DIR}/rules/` (`rule-{NNN}-{slug}.md`, frontmatter `type: Rule`, `id`, `title`, `timestamp`, `active: true`; body = `# {title}` + description) and add it to `${MEMORY_DIR}/rules/index.md`
- For lower confidence: queue for manual review
- Display results if rules extracted; continue silently if none detected

## Phase 5.5: Persist Orchestration Memory

- Read `.claude-harness/agents/context.json`
- For completed agent results: write Success concepts to `${MEMORY_DIR}/successes/` (`suc-{NNN}-{slug}.md`, `type: Success`; body = `# {approach}` + `## Files` + `## Patterns`) and update `successes/index.md`
- For failed agent results: write Failure concepts to `${MEMORY_DIR}/failures/` (`fail-{NNN}-{slug}.md`, `type: Failure`; body = `# {approach}` + `## Errors` + `## Root Cause` + `## Prevention`) and update `failures/index.md`
- Merge `discoveredPatterns` into `${MEMORY_DIR}/patterns/` as Pattern concepts (don't duplicate existing ones)
- Persist `architecturalDecisions` to `${MEMORY_DIR}/decisions/` as Decision concepts
- Clear `agentResults`, set `currentSession` to null

## Phase 5.6: Commit, Push, PR

1. **Stage harness state files**: `git add .claude-harness/` (sessions/ and working/ are gitignored, so only persistent state is staged -- memory layers, features, progress, session-briefing, agents, config)
2. Stage all other modified files: `git add -A`
3. Commit `feat(feature-XXX): {description}`, push with `git push -u origin {branch}`
4. Create or update the PR:
   - New: `gh pr create --title "feat: {description}" --body "..."` with `Closes #{issue}` in the body
   - Existing: `gh pr edit {number} --body "..."` with updated progress
5. Mark Checkpoint task completed
6. Display checkpoint summary: commit hash, PR number, task status
