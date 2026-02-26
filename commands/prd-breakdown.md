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

10. **Generate feature specifications** (with structured Gherkin acceptance criteria):
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
      "acceptanceCriteria": [
        {
          "scenario": "Descriptive scenario name",
          "given": "precondition (context setup)",
          "when": "action performed",
          "then": "expected outcome"
        }
      ],
      "riskLevel": "low|medium|high",
      "estimatedComplexity": "low|medium|high",
      "mvpFeature": true|false
    }
    ```
    **Important**: `acceptanceCriteria` MUST use structured Gherkin format (`{ scenario, given, when, then }`) — not plain strings. This enables the ATDD workflow in `/flow --team` where the tester teammate programmatically iterates scenarios to write executable tests.

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
          "acceptanceCriteria": [
            {
              "scenario": "...",
              "given": "...",
              "when": "...",
              "then": "..."
            }
          ],
          "prdMetadata": {
            "section": "...",
            "breakdown": "prd-{date}-{hash}"
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

## Phase 3.5: GitHub Issue Creation (unless --no-issues)

GitHub issues are created **by default** for all generated features. Skip with `--no-issues`.

15. **Pass 1 — Create issues with rich bodies** (in dependency order — dependencies first):

    - Parse GitHub owner/repo from `git remote get-url origin` (or use cached from SessionStart)
    - For each created feature (ordered so dependencies are created first):

      1. **Build labels**:
         - Base: `["feature", "prd-generated", "claude-harness"]`
         - If `mvpFeature` is true: add `"mvp"`
         - If `riskLevel` is "high": add `"high-risk"`

      2. **Build rich issue body**:
         ```markdown
         ## Description

         {feature.detailedDescription or feature.description}

         ### PRD Source
         **Section:** {prdSource.section} | **Requirement:** {prdSource.requirement}

         ---

         ## Acceptance Criteria

         **Scenario: {scenario}**
         - **Given** {given}
         - **When** {when}
         - **Then** {then}

         {repeat for each criterion in acceptanceCriteria}

         ---

         ## Implementation Context

         | Attribute | Value |
         |-----------|-------|
         | Priority | {priority} |
         | Complexity | {estimatedComplexity} |
         | Risk Level | {riskLevel} |
         | MVP Feature | {mvpFeature ? "Yes" : "No"} |

         ### Related Files
         {for each file in relatedFiles: "- `{file}`"}
         {if empty: "- To be determined during planning"}

         ### Implementation Hints
         {from architecture analysis for this feature: suggested approach, tech stack considerations, risks and mitigations}

         ---

         ## Dependencies

         {placeholder — will be updated in Pass 2 with actual issue numbers}
         {if feature.dependencies: "Depends on: {list dependency feature names}"}
         {if no dependencies: "No dependencies — can be implemented independently."}

         ---

         ## Verification Commands
         ```
         build: {verification.build or "not configured"}
         tests: {verification.tests or "not configured"}
         lint: {verification.lint or "not configured"}
         typecheck: {verification.typecheck or "not configured"}
         acceptance: {verification.acceptance or "not configured"}
         ```

         ---
         *Generated by [claude-harness](https://github.com/panayiotism/claude-harness) PRD breakdown*
         *Breakdown ID: {prdMetadata.breakdown}*
         ```

      3. **Create issue** via `gh issue create` or `mcp__github__create_issue`:
         - Title: `{feature.name}`
         - Body: rich template from step 2
         - Labels: from step 1
         - Handle failures gracefully (log warning, continue with other features)

      4. **Update feature entry** in active.json:
         - Set `github.issueNumber` to created issue number
         - Save updated `.claude-harness/features/active.json`

      5. **Rate limiting**: 500ms delay between API calls

15.5. **Pass 2 — Update issues with cross-references** (after ALL issues are created):

    Now that every feature has an assigned `github.issueNumber`, update each issue that has dependencies or is depended upon:

    - For each feature with `dependencies` array OR that appears in another feature's `dependencies`:

      1. **Build "Depends on" section**:
         ```markdown
         **Depends on:**
         - #43 — Add user authentication
         - #45 — Create database schema
         ```
         Map each dependency feature ID to its `github.issueNumber` and `name`.

      2. **Build "Blocks" section** (reverse lookup):
         - Find all features whose `dependencies` array includes this feature's ID
         ```markdown
         **Blocks:**
         - #44 — Build user dashboard
         - #46 — Add admin panel
         ```

      3. **Replace the Dependencies section** in the issue body:
         - Use `gh issue edit {issueNumber} --body "{updated body}"` or GitHub MCP
         - Replace the placeholder dependency section with the actual cross-referenced version

      4. **Rate limiting**: 500ms delay between API calls

    This ensures **bidirectional linking**: if feature-002 depends on feature-001, then:
    - feature-001's issue shows "**Blocks:** #44 — feature-002 name"
    - feature-002's issue shows "**Depends on:** #43 — feature-001 name"

    **Error Handling** (applies to both Pass 1 and Pass 2):
    - GitHub MCP unavailable → Log warning, skip issue creation entirely but continue with feature creation
    - Permission denied → Log error for specific feature, continue with others
    - API rate limit → Add 500ms delay between requests
    - Network error → Retry 3x with exponential backoff
    - Pass 2 update failure → Log warning (issues exist but without cross-references), continue

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
    │  GitHub Issues Created: 3                                       │
    │    #43: Add user authentication (MVP)                           │
    │    #44: Build user dashboard → depends on #43                   │
    │    #45: Create database schema                                  │
    │  Cross-references: 2 issues updated with dependency links       │
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

**--no-issues**
- Skip GitHub issue creation. Features are still created in active.json.
- Useful when GitHub integration is not configured or not needed.
- By default, issues are always created alongside features.

**--analyze-only**
- Run PRD analysis without creating features
- Useful for review before committing to features

**--auto**
- Skip feature review confirmation prompt
- Create all extracted features and GitHub issues automatically

**--max-features N**
- Limit feature creation to top N features by priority
- Useful for phased rollout

### Usage Examples

```bash
/claude-harness:prd-breakdown "Detailed PRD markdown here..."           # Inline PRD (creates features + issues)
/claude-harness:prd-breakdown @./docs/prd.md                           # File reference (creates features + issues)
/claude-harness:prd-breakdown --file ./docs/prd.md                     # File flag
/claude-harness:prd-breakdown --url https://github.com/.../issues/42  # GitHub issue as PRD source
/claude-harness:prd-breakdown --analyze-only                           # Analysis only (no features, no issues)
/claude-harness:prd-breakdown --auto                                   # No prompts, full automation
/claude-harness:prd-breakdown --max-features 10                        # Top 10 only
/claude-harness:prd-breakdown @./prd.md --no-issues                   # Features only, skip GitHub issues
/claude-harness:prd-breakdown @./prd.md --auto                        # Full automation: analyze + features + issues
```

### Syntax Variations

| Syntax | Behavior |
|--------|----------|
| `/prd-breakdown "markdown text"` | Analyze inline PRD, create features + GitHub issues |
| `/prd-breakdown @path/to/file.md` | Read PRD from file, create features + issues |
| `/prd-breakdown --file path/to/file.md` | Read PRD from file (--flag syntax) |
| `/prd-breakdown --url https://...` | Fetch PRD from GitHub issue |
| `/prd-breakdown @file.md --no-issues` | Create features only, skip GitHub issues |
| `/prd-breakdown @file.md --auto` | Full automation: analyze, create features AND issues |
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
| GitHub MCP unavailable | Log warning, skip issue creation entirely but continue with feature creation |
| Issue creation permission denied | Log error for specific feature, continue with others |
| Issue creation rate limit | Add 500ms delay between requests, continue |
| Issue creation network error | Retry 3x with exponential backoff |
| Pass 2 update failure | Log warning (issues exist but without cross-references), continue |

## Integration with Other Commands

- **With `/flow`**: Each created feature can be implemented via `/flow feature-XXX`
- **With `/start`**: Shows PRD analysis summary from prior sessions
- **With memory**: Records decomposition patterns to procedural memory for future PRDs
