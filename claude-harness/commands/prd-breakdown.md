---
description: Analyze PRD and break down into atomic features for harness tracking
argument-hint: "[PRD-TEXT | @FILE | --file PATH | --url GITHUB-ISSUE]"
---

Analyze a Product Requirements Document (PRD) and decompose it into atomic features that integrate with the claude-harness workflow.

Arguments: $ARGUMENTS

## Phase 0: PRD Input Detection & Storage

1. **Detect PRD source** (in priority order):
   - If arguments start with `@` → treat as file reference (e.g., `@./docs/prd.md`)
   - Else if `--url` flag provided → fetch from GitHub issue
   - Else if `--file` flag provided → read from specified file path
   - Else if file `./.claude-harness/prd.md` exists → read from file
   - Else if arguments provided → treat as inline PRD markdown
   - Else → prompt user for interactive input

2. **Validate PRD format**:
   - Check minimum length (at least 100 characters of content)
   - If Markdown: verify structure (sections, requirements)
   - If plain text: parse as-is
   - If too large (>100KB): warn user, ask to focus on specific sections

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

---

## Phase 1: PRD Analysis

Perform comprehensive analysis from three perspectives:

4. **Product Analysis**:
   - Extract business goals, user personas, functional requirements
   - Identify non-functional requirements, dependencies, constraints

5. **Architecture Analysis**:
   - Review feasibility and technical complexity
   - Propose implementation order (dependency graph)
   - Identify risks and mitigations
   - Suggest MVP features

6. **QA Analysis**:
   - Define acceptance criteria for each requirement
   - Identify edge cases and error scenarios
   - Specify performance/security requirements

7. **Save analysis results** to `.claude-harness/prd/analysis.json`:
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
     - Determine complexity from architecture assessment
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

12. **Generate preview** showing (skip if `--auto` flag provided):
    - Total PRD sections analyzed
    - Functional requirements extracted
    - Features to create (grouped by priority)
    - MVP features highlighted
    - Risk assessment summary

    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  PRD BREAKDOWN ANALYSIS COMPLETE                                │
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

## Phase 3.5: GitHub Issue Creation (if --create-issues flag provided)

15. **Create GitHub issues for generated features** (only if `--create-issues` flag was provided):
    - For each created feature:
      1. Build GitHub issue payload:
         ```json
         {
           "title": "{feature.name}",
           "body": "## Description\n{feature.description}\n\n## Acceptance Criteria\n{bulleted acceptance criteria}\n\n## Priority\nLevel {feature.priority}",
           "labels": ["feature", "prd-generated"],
           "milestone": null
         }
         ```

      2. Create issue using Claude Code's GitHub MCP:
         - Parse GitHub owner/repo from `git remote get-url origin`
         - Call `mcp__github__create_issue` function
         - Handle failures gracefully (log warning, continue with other features)

      3. Update feature metadata with issue number:
         - Set `github.issueNumber` to created issue number
         - Update `prdMetadata.createdViaFlag` to `"--create-issues"`
         - Save updated `.claude-harness/features/active.json`

      4. Report results:
         ```
         Created GitHub issues for {N} features:
           - #{issue-num}: {feature-name}
           - #{issue-num}: {feature-name}
           ...
         ```

    - **Error Handling**:
      - GitHub MCP unavailable → Log warning, skip issue creation but continue
      - Permission denied → Log error for specific feature, continue with others
      - API rate limit → Add 500ms delay between requests
      - Network error → Retry 3x with exponential backoff

## Phase 4: Summary & Next Steps

16. **Report completion**:
    ```
    ┌─────────────────────────────────────────────────────────────────┐
    │  FEATURES CREATED FROM PRD                                      │
    ├─────────────────────────────────────────────────────────────────┤
    │  PRD Sections: 5                                                │
    │  Features Extracted: 8                                          │
    │  Created Now: 3                                                 │
    │                                                                 │
    │  Files:                                                         │
    │  - PRD input: .claude-harness/prd/input.md                      │
    │  - Analysis: .claude-harness/prd/analysis.json                  │
    │  - Breakdown: .claude-harness/prd/breakdown.json                │
    │                                                                 │
    │  NEXT STEPS:                                                    │
    │  1. Start implementation: /flow feature-001                     │
    │  2. Or batch process: /flow --autonomous                        │
    │  3. Review analysis: cat .claude-harness/prd/breakdown.json     │
    └─────────────────────────────────────────────────────────────────┘
    ```

17. **Interactive menu** (if user doesn't select all):
    - Use AskUserQuestion with multi-select: true
    - Show pending features from breakdown
    - Allow user to start implementing any features

## Command Options

### Flags

**--create-issues**
- Create GitHub issues for each generated feature automatically
- One issue created per feature with description and acceptance criteria
- Issues labeled with `feature` and `prd-generated`
- Features linked with `github.issueNumber` in harness tracking
- Requires: GitHub MCP integration configured
- Behavior: No confirmation prompt (full automation)
- Example: `/prd-breakdown @./prd.md --create-issues`

**--analyze-only**
- Run PRD analysis without creating features
- Useful for review before committing to features

**--auto**
- Skip feature review confirmation prompt
- Create all extracted features automatically
- Can be combined with `--create-issues` for full automation

**--max-features N**
- Limit feature creation to top N features by priority
- Useful for phased rollout

### Usage Examples

```bash
/claude-harness:prd-breakdown "Detailed PRD markdown here..."           # Inline PRD
/claude-harness:prd-breakdown @./docs/prd.md                           # File reference
/claude-harness:prd-breakdown --file ./docs/prd.md                     # File flag
/claude-harness:prd-breakdown --url https://github.com/.../issues/42  # GitHub issue
/claude-harness:prd-breakdown --analyze-only                           # Analysis only
/claude-harness:prd-breakdown --auto                                   # No prompts
/claude-harness:prd-breakdown --max-features 10                        # Top 10 only
/claude-harness:prd-breakdown @./prd.md --create-issues               # Create issues
/claude-harness:prd-breakdown @./prd.md --create-issues --auto        # Full automation
```

### Syntax Variations

| Syntax | Behavior |
|--------|----------|
| `/prd-breakdown "markdown text"` | Treat argument as inline PRD content |
| `/prd-breakdown @path/to/file.md` | Read PRD from file (@ prefix) |
| `/prd-breakdown --file path/to/file.md` | Read PRD from file (--flag syntax) |
| `/prd-breakdown --url https://...` | Fetch PRD from GitHub issue |
| `/prd-breakdown @file.md --create-issues` | Analyze PRD and create GitHub issues for features |
| `/prd-breakdown @file.md --create-issues --auto` | Full automation: analyze, create features AND GitHub issues |
| (no args) | Prompt user for interactive input |

## Error Handling

| Scenario | Action |
|----------|--------|
| PRD not provided | Prompt via AskUserQuestion |
| PRD too large (>100KB) | Warn user, ask to focus section |
| GitHub fetch fails (no MCP) | Fall back to interactive input |
| Invalid markdown | Parse as plaintext, still extract |
| Feature ID collision | Use timestamp suffix for uniqueness |
| Dependency cycle | Report error, suggest manual ordering |
| --create-issues but no GitHub MCP | Log warning, create features without issues |
| Issue creation permission denied | Log error for feature, continue with others |
| Issue creation rate limit | Add 500ms delay between requests, continue |
| Issue creation network error | Retry 3x with exponential backoff |

## Integration with Other Commands

- **With `/flow`**: Each created feature can be implemented via `/flow feature-XXX`
- **With `/start`**: Shows PRD analysis summary from prior sessions
- **With memory**: Records decomposition patterns to procedural memory for future PRDs
