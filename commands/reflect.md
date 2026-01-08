---
description: Extract learnings from user corrections in this session
argumentsPrompt: Optional flags (--auto, --dry-run, --since="timestamp")
---

Reflect on user corrections and extract learnable rules:

Arguments: $ARGUMENTS

## Core Principle
Learn from user corrections. When a user explicitly corrects Claude's approach,
that correction should be captured as a rule to prevent repeating the mistake.

## Phase 0: Parse Arguments

1. Parse optional flags:
   - `--auto`: Skip interactive confirmation (for checkpoint integration)
   - `--dry-run`: Show what would be extracted without saving
   - `--since="timestamp"`: Only analyze conversation since timestamp

2. Read `.claude-harness/config.json` for reflection settings:
   - Check if `reflection.enabled` is true
   - Get `autoApproveHighConfidence` setting
   - Get `minConfidenceForAuto` setting

## Phase 1: Analyze Conversation for Corrections

3. Scan the current conversation for correction patterns:

   **Explicit corrections** (high confidence):
   - "No, do X instead"
   - "Please use Y not Z"
   - "Don't do X, do Y"
   - "Always..." / "Never..."
   - "Stop doing X"
   - "That's wrong/incorrect"

   **Preference statements** (medium confidence):
   - "I prefer..."
   - "In this project we..."
   - "Our convention is..."
   - "We use X for..."
   - "The pattern is..."

4. For each detected correction, extract:
   - What Claude was doing (incorrect approach)
   - What user wants instead (correct approach)
   - Context/reason if provided
   - Applicable scope (file patterns, always, specific feature)

## Phase 2: Filter and Categorize

5. Filter out non-learnable corrections:
   - One-time context-specific corrections (not generalizable)
   - Corrections about facts/data (not preferences/patterns)
   - Already captured in existing rules (check for duplicates)

6. Check for duplicates:
   - Read `.claude-harness/memory/learned/rules.json`
   - Compare extracted learnings against existing rules by title/description
   - Skip exact duplicates
   - Flag similar rules for potential merge

7. Categorize each learning:
   - **category**: "project-specific" or "general"
   - **scope**: "coding-style", "architecture", "testing", "git", "documentation", "tooling"
   - **confidence**: "high" (explicit) or "medium" (implicit preference)
   - **applicability**: file patterns, features, or "always"

## Phase 3: Present Learnings for Approval

8. If not `--auto` mode, present each learning for user approval:
   ```
   ┌─────────────────────────────────────────────────────────────────┐
   │  📚 POTENTIAL RULE EXTRACTED                                    │
   ├─────────────────────────────────────────────────────────────────┤
   │  Title: {short actionable title}                                │
   │  Category: {project-specific|general} | Confidence: {high|med}  │
   │                                                                 │
   │  Source: "{user's original correction}"                         │
   │                                                                 │
   │  Description:                                                   │
   │  {detailed explanation of what to do}                           │
   │                                                                 │
   │  Applies to: {file patterns or "all files"}                     │
   │                                                                 │
   │  Example:                                                       │
   │  ✗ {incorrect}: {example of wrong way}                          │
   │  ✓ {correct}: {example of right way}                            │
   ├─────────────────────────────────────────────────────────────────┤
   │  [A]pprove  [E]dit  [R]eject  [S]kip                           │
   └─────────────────────────────────────────────────────────────────┘
   ```

9. Handle user response:
   - **Approve** (A): Add rule as-is
   - **Edit** (E): Allow user to modify title, description, scope before saving
   - **Reject** (R): Discard this learning permanently
   - **Skip** (S): Move to next learning (don't save, but don't reject)

10. If `--auto` mode:
    - Auto-approve rules with confidence >= `minConfidenceForAuto`
    - Skip lower confidence rules (report them but don't save)

## Phase 4: Persist Approved Rules

11. For each approved rule:
    - Generate unique ID: `rule-{NNN}` (based on count of existing rules)
    - Set timestamps: `createdAt`, `updatedAt`
    - Set `active: true`
    - Set `usageCount: 0`

12. Update rules file:
    - Read `.claude-harness/memory/learned/rules.json`
    - Append new rules to `rules` array
    - Update `metadata`:
      - Increment `totalRules`
      - Update `projectSpecific` or `general` count
      - Set `lastReflection` to current timestamp
    - Update `lastUpdated`
    - Write file

## Phase 5: Display Summary

13. Display reflection summary:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  📚 REFLECTION COMPLETE                                         │
    ├─────────────────────────────────────────────────────────────────┤
    │  Corrections analyzed: {count}                                  │
    │  Rules extracted: {count}                                       │
    │  Approved: {N} | Rejected: {N} | Skipped: {N}                  │
    │                                                                 │
    │  New rules:                                                     │
    │  • rule-{NNN}: {title}                                          │
    │  • rule-{NNN}: {title}                                          │
    │                                                                 │
    │  Total rules in memory: {total}                                 │
    └─────────────────────────────────────────────────────────────────┘
    ```

14. If `--dry-run`:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  📚 DRY RUN - No changes saved                                  │
    ├─────────────────────────────────────────────────────────────────┤
    │  Would extract {N} rules:                                       │
    │  • {title} (confidence: {level})                                │
    │  • {title} (confidence: {level})                                │
    │                                                                 │
    │  Run without --dry-run to save these rules                      │
    └─────────────────────────────────────────────────────────────────┘
    ```

## Phase 6: Git Integration

15. If changes were made (not dry-run):
    - Stage the rules file: `git add .claude-harness/memory/learned/rules.json`
    - Report: "New rules staged. Run /claude-harness:checkpoint to commit."

16. Do NOT auto-commit. Let `/checkpoint` handle commits to include rules
    in the same commit as other session work.

## Error Handling

17. If reflection is disabled in config:
    ```
    Reflection is disabled in config.json
    Set reflection.enabled: true to enable
    ```

18. If no corrections detected:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  📚 NO CORRECTIONS DETECTED                                     │
    ├─────────────────────────────────────────────────────────────────┤
    │  No user corrections found in this session.                     │
    │                                                                 │
    │  Corrections are captured when you explicitly correct Claude:   │
    │  • "No, use X instead of Y"                                     │
    │  • "Always do X in this project"                                │
    │  • "Our convention is..."                                       │
    └─────────────────────────────────────────────────────────────────┘
    ```

19. If rules file doesn't exist:
    - Create it with empty rules array
    - Proceed with reflection

## Rule Schema Reference

```json
{
  "id": "rule-001",
  "title": "Always use absolute imports",
  "description": "Use @/components/... instead of relative paths like ../../../",
  "category": "project-specific",
  "scope": "coding-style",
  "confidence": "high",
  "source": {
    "type": "user-correction",
    "timestamp": "2026-01-06T12:00:00Z",
    "context": "User corrected import pattern in component file",
    "conversationExcerpt": "Please use @/ imports, not relative paths"
  },
  "applicability": {
    "filePatterns": ["*.ts", "*.tsx"],
    "features": [],
    "always": false
  },
  "examples": {
    "correct": "import { Button } from '@/components/ui/Button'",
    "incorrect": "import { Button } from '../../../components/ui/Button'"
  },
  "tags": ["imports", "typescript", "code-style"],
  "active": true,
  "usageCount": 0,
  "lastApplied": null,
  "createdAt": "2026-01-06T12:00:00Z",
  "updatedAt": "2026-01-06T12:00:00Z"
}
```

## Next Steps After Reflection

- Run `/claude-harness:checkpoint` to commit rules with your work
- Rules will be displayed at next `/claude-harness:start`
- Claude will follow learned rules in future sessions
