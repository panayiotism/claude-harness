# OKF Memory Bundle - Conformance Rules

The harness memory knowledge layers live as an **OKF v0.1 bundle** at
`.claude-harness/memory/` (spec: GoogleCloudPlatform/knowledge-catalog `okf/SPEC.md`).
This document replaces `memory-entries.schema.json` for those layers -- OKF
layers are markdown, not JSON, so conformance rules are documented here
instead of a JSON Schema. Remaining JSON state files keep their canonical
`schemas/*.schema.json`.

Check conformance with: `python3 scripts/check-okf.py .claude-harness/memory`

## Bundle layout

```
.claude-harness/memory/          # bundle root
├── index.md                     # declares okf_version: "0.1" (only frontmatter allowed here)
├── log.md                       # chronological history, newest first (## YYYY-MM-DD headings)
├── decisions/                   # episodic layer   - type: Decision
├── failures/                    # procedural layer - type: Failure
├── successes/                   # procedural layer - type: Success
├── patterns/                    # procedural layer - type: Pattern
├── rules/                       # learned layer    - type: Rule
│   └── (each directory: index.md + one .md concept file per entry)
└── semantic/                    # NOT part of the bundle contract (stays JSON)
```

## Hard conformance rules (checked by check-okf.py)

1. Every non-reserved `.md` file is a **concept**: it MUST start with a YAML
   frontmatter block delimited by `---` lines, containing a non-empty `type`
   field (`Decision`, `Failure`, `Success`, `Pattern`, `Rule`).
2. Reserved filenames `index.md` and `log.md` MUST NOT carry frontmatter --
   except the bundle-root `index.md`, which MUST carry exactly
   `okf_version: "0.1"`.

Everything else is soft guidance: consumers MUST tolerate unknown frontmatter
keys and value types, missing optional fields, and broken links.

## Concept file format

Filename doubles as the concept ID (path minus `.md`). Convention:
`{prefix}-{NNN}-{slug}.md` with prefixes `dec` / `fail` / `suc` / `pat` /
`rule`; NNN is the next number in the directory; slug is the lowercased
title with non-alphanumerics collapsed to hyphens, <=48 chars.

```markdown
---
type: Decision                    # REQUIRED - the only mandatory field
id: dec-007                       # entry id (carried over from legacy JSON `id`)
title: "Short one-line summary"   # <=80 chars, quoted
timestamp: 2026-07-17T12:00:00Z   # ISO 8601
feature: feature-004              # related feature id (omit when none)
tags: some-tag                    # optional
active: true                      # Rule concepts only (false = retired rule)
---

# Full title / statement of the entry

## Rationale        <- Decision: rationale / Alternatives / Impact
## Errors           <- Failure: Errors / Root Cause / Prevention / Files
## Files            <- Success: Files / Patterns / Lessons
## Source           <- Pattern: Source
```

Structured legacy JSON fields with no frontmatter analog live as `## Heading`
body sections (bulleted lists for arrays). Cross-references to features or
other concepts are written as prose or bundle-relative links (`/decisions/...`).

## index.md (progressive disclosure)

Each directory's `index.md` lists its concepts so agents can scan titles
before opening files:

```markdown
# Decisions

Episodic memory - recent significant decisions (type: Decision).

* [dec-007: Short one-line summary](/decisions/dec-007-short-summary.md) - short description
```

**Writers MUST append a listing line whenever they create a concept file.**
The decisions layer keeps a rolling window of 50 concepts (delete oldest
file + its index line, FIFO); the other layers are append-only.

## Consumers

- `scripts/compile-briefing.py` - session briefing (decisions, failures, rules)
- `scripts/check-okf.py` - conformance check
- `hooks/subagent-start` - injects last failures + active rules at spawn
- `setup.sh` - stamp-gated migration from legacy JSON (`memory/.okf-migrated`)
- skills: flow / checkpoint / start write and read concept files
