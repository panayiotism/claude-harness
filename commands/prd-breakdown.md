---
description: Analyze PRD and break down into atomic features for harness tracking
argument-hint: "[PRD-TEXT | --file PATH | --url GITHUB-ISSUE]"
---

Analyze a Product Requirements Document (PRD) and decompose it into atomic features that integrate with the claude-harness workflow.

Arguments: $ARGUMENTS

## Phase 0: PRD Input Detection & Storage

1. **Detect PRD source** (in priority order):
   - If arguments provided → treat as inline PRD markdown
   - Else if file `./.claude-harness/prd.md` exists → read from file
   - Else if `--url` flag provided → fetch from GitHub issue
   - Else → prompt user for interactive input

2. **Validate PRD format**:
   - Check minimum length (at least 100 characters of content)
   - If Markdown: verify structure (sections, requirements)
   - If plain text: parse as-is
   - If too large (>50KB): warn user, ask to focus on specific sections

3. **Store PRD input**:
   - Create `.claude-harness/prd/` directory if missing
   - Save PRD content to `.claude-harness/prd/input.md`
   - Create `.claude-harness/prd/metadata.json`:
     ```json
     {
       "version": 1,
       "sourceType": "inline|file|github|interactive",
       "fetchedAt": "{ISO timestamp}",
       "sourceUrl": "{URL or path}",
       "hash": "{SHA256 of PRD}",
       "characterCount": 0,
       "sections": 0
     }
     ```

## Phase 1: Parallel Subagent Analysis

4. **Load subagent prompt templates**:
   - Read `.claude-harness/prd/subagent-prompts.json`
   - Get prompts for Product Analyst, Architect, QA Lead

5. **Spawn 3 parallel subagents** (all at once using Task tool):

   **Subagent 1: Product Analyst**
   - Extracts business goals, user personas, functional requirements
   - Identifies non-functional requirements, dependencies, constraints
   - Output: JSON with structured requirements list

   **Subagent 2: Architect**
   - Reviews feasibility and technical complexity
   - Proposes implementation order (dependency graph)
   - Identifies risks and mitigations
   - Suggests MVP features
   - Output: JSON with complexity scores, dependencies, risk assessment

   **Subagent 3: QA Lead**
   - Defines acceptance criteria for each requirement
   - Identifies edge cases and error scenarios
   - Specifies performance/security requirements
   - Output: JSON with verification framework and test scenarios

6. **Wait for all agents to complete**:
   - Set timeout of 10 minutes per agent
   - Display progress: "⏳ Analyzing with Product Analyst... Architect... QA Lead..."
   - On timeout: Retry with simpler prompt or use fallback analysis

7. **Merge analysis results**:
   - Combine outputs from all 3 agents
   - Save to `.claude-harness/prd/analysis.json`:
     ```json
     {
       "version": 1,
       "analyzedAt": "{timestamp}",
       "product": {
         "businessGoals": [...],
         "userPersonas": [...],
         "functionalRequirements": [...]
       },
       "architecture": {
         "feasibilityAssessment": [...],
         "implementationOrder": [...],
         "mvpFeatures": [...],
         "dependencies": {...}
       },
       "qa": {
         "verificationFramework": {...},
         "edgeCases": [...]
       }
     }
     ```

## Phase 2: Breakdown Generation

8. **Transform analysis into atomic features**:
   - For each functional requirement (from product analysis):
     - Generate feature name (readable title)
     - Extract acceptance criteria (from QA analysis)
     - Determine complexity from architect assessment
     - Identify dependencies
     - Assign risk level

9. **Resolve dependencies**:
   - Build dependency graph: feature A depends on B, B depends on C
   - Topologically sort (ensures dependencies implemented first)
   - Detect cycles: ERROR if circular dependency found
   - Generate priority ordering

10. **Generate feature specifications**:
    ```json
    {
      "id": "feature-XXX",
      "prdSource": {
        "section": "Section Name",
        "requirement": "R001"
      },
      "name": "Feature Title",
      "description": "One-line description",
      "detailedDescription": "Full description from PRD",
      "priority": 1,
      "dependencies": ["feature-YYY"],
      "acceptanceCriteria": ["Given X when Y then Z"],
      "riskLevel": "low|medium|high",
      "estimatedComplexity": "low|medium|high",
      "mvpFeature": true|false
    }
    ```

11. **Apply limits** (if `--max-features N` provided):
    - Sort by priority, keep top N
    - Summarize excluded features

## Phase 3: Feature Review & Creation

12. **Generate preview** showing:
    - Total PRD sections analyzed
    - Functional requirements extracted
    - Features to create (grouped by priority)
    - MVP features highlighted
    - Risk assessment summary

    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  📋 PRD BREAKDOWN ANALYSIS COMPLETE                             │
    ├─────────────────────────────────────────────────────────────────┤
    │  Sections: 5 | Requirements: 23 | Features: 8                   │
    │  MVP Features: 3 | High-Risk: 1 | Dependencies: 5              │
    │                                                                 │
    │  FEATURES (by priority):                                        │
    │  ┌─────────────────────────────────────────────────────────────┤
    │  │  1. [MVP] Add user authentication                           │
    │  │     Risk: MEDIUM | Complexity: MEDIUM | No dependencies     │
    │  │                                                              │
    │  │  2. Build user dashboard                                    │
    │  │     Risk: LOW | Complexity: LOW | Depends on: #1            │
    │  │  ... (6 more)                                                │
    │  └─────────────────────────────────────────────────────────────┤
    │                                                                 │
    │  Create features? [Y/n/select/review]                          │
    └─────────────────────────────────────────────────────────────────┘
    ```

13. **Handle user response**:
    - **Y**: Create all features (go to step 14)
    - **n**: Stop here, show file path: `.claude-harness/prd/breakdown.json`
    - **select**: Show multi-select menu, create only selected features
    - **review**: Display full breakdown details for inspection

14. **Create features in `.claude-harness/features/active.json`**:
    - For each selected feature:
      - Generate next sequential feature ID (read active.json, find max, increment)
      - Add feature entry with full PRD metadata:
        ```json
        {
          "id": "feature-XXX",
          "name": "...",
          "description": "...",
          "priority": N,
          "status": "pending",
          "prdMetadata": {
            "section": "...",
            "breakdown": "prd-{date}-{hash}",
            "acceptanceCriteria": [...]
          },
          "verification": {
            "build": "{auto-detected}",
            "tests": "{auto-detected}",
            "lint": "{auto-detected}",
            "typecheck": "{auto-detected}"
          },
          "relatedFiles": [],
          "github": {
            "issueNumber": null,
            "prNumber": null,
            "branch": "feature/feature-XXX"
          },
          "createdAt": "{timestamp}",
          "updatedAt": "{timestamp}"
        }
        ```

## Phase 4: Summary & Next Steps

15. **Report completion**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  ✅ FEATURES CREATED FROM PRD                                   │
    ├─────────────────────────────────────────────────────────────────┤
    │  PRD Sections: 5                                                │
    │  Features Extracted: 8                                          │
    │  Created Now: 3                                                 │
    │                                                                 │
    │  📁 Files:                                                       │
    │  - PRD input: .claude-harness/prd/input.md                      │
    │  - Analysis: .claude-harness/prd/analysis.json                  │
    │  - Breakdown: .claude-harness/prd/breakdown.json                │
    │                                                                 │
    │  🎯 NEXT STEPS:                                                 │
    │  1. Start implementation: /do feature-001                       │
    │  2. Or interactive menu: /do (select multiple)                  │
    │  3. Review analysis: cat .claude-harness/prd/breakdown.json      │
    │  4. Create more features: /do feature-004 feature-005           │
    └─────────────────────────────────────────────────────────────────┘
    ```

16. **Interactive menu** (if user doesn't select all):
    - Use AskUserQuestion with multi-select: true
    - Show pending features from breakdown
    - Allow user to start implementing any features

## Command Options

```bash
/claude-harness:prd-breakdown "Detailed PRD markdown here..."
/claude-harness:prd-breakdown --file ./docs/prd.md
/claude-harness:prd-breakdown --url https://github.com/owner/repo/issues/42
/claude-harness:prd-breakdown --analyze-only      # Run analysis but don't create features
/claude-harness:prd-breakdown --auto              # No prompts, create all features
/claude-harness:prd-breakdown --max-features 10   # Limit to 10 top features
```

## Error Handling

| Scenario | Action |
|----------|--------|
| PRD not provided | Prompt via AskUserQuestion |
| PRD too large (>50KB) | Warn user, ask to focus section |
| Subagent timeout (>10min) | Retry with simpler prompt, or skip that agent |
| GitHub fetch fails (no MCP) | Fall back to interactive input |
| Invalid markdown | Parse as plaintext, still extract |
| Feature ID collision | Use timestamp suffix for uniqueness |
| Dependency cycle | Report error, suggest manual ordering |

## Integration with Other Commands

- **With `/do`**: Each created feature can be implemented via `/do feature-XXX`
- **With `/start`**: Shows PRD analysis summary from prior sessions
- **With memory**: Records decomposition patterns to procedural memory for future PRDs

## Subagent Prompts

All three subagent prompts are stored in `.claude-harness/prd/subagent-prompts.json` and include:
- Complete PRD context
- Expected JSON output format
- Schema validation rules
