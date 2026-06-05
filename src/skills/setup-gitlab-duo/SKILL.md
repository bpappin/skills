---
name: setup-gitlab-duo
description: Configure GitLab Duo custom merge request review instructions at the project level. Use when setting up or customizing GitLab Duo instructions, mr-review-instructions.yaml, or configuring project-specific AI code review standards.
---

# Setup GitLab Duo

Automatically configure GitLab Duo custom merge request review instructions at the project level by analyzing project-specific code review standards and generating a schema-compliant YAML file.

## Quick Start

1. **Verify or create configuration folder:**
   ```bash
   mkdir -p .gitlab/duo
   ```
2. **Scan for standards and source code:** Locate code review standards (e.g. `CODE_REVIEW_STANDARDS.md`) or identify file structures to determine targeted `fileFilters`.
3. **Generate file:** Write `.gitlab/duo/mr-review-instructions.yaml`.
4. **Validate schema:**
   ```bash
   python3 .agents/skills/setup-gitlab-duo/scripts/validate.py
   ```

## Workflows

### 1. Analyze Codebase
- Search for standard files like `CODE_REVIEW_STANDARDS.md`, `CONTRIBUTING.md`, or style guides in the root or `docs/`.
- Scan source directories (`src/`, `app/`, etc.) to identify languages (e.g., Kotlin, TS/JS, Python, Go) to build specific `fileFilters` (using glob patterns).

### 2. Map Standards to GitLab Duo Format
Construct instructions mapping code review rules into blocks:
- **Severity Levels:** Ensure the review outputs use:
  - `CR: Critical` - Runtime errors, bugs, security issues, performance blockages.
  - `IM: Important` - Missing error handling, API contract divergence, maintainability concerns.
  - `NP: Non-Priority` - Minor refactoring suggestions, style deviations, optional optimizations.
  - `Q: Question` - Requests for clarity or trade-off explanations.
- **Language/Pattern Matching:** Group rules using specific glob filters (e.g., `**/*.kt` for Kotlin/Android, `**/*.{ts,tsx}` for TypeScript/React).
- **Fallback Template:** If no `CODE_REVIEW_STANDARDS.md` is present, construct instructions based on standard programming language paradigms and the severity structure above.

### 3. Generate YAML Configuration
Write `.gitlab/duo/mr-review-instructions.yaml` matching this schema:
```yaml
instructions:
  - name: kotlin-android-reviews
    fileFilters:
      - "app/**/*.kt"
      - "src/**/*.kt"
    instructions: |
      1. Verify that ViewModel business logic contains no UI styling references (e.g., MaterialTheme, UI colors).
      2. Ensure suspend functions/async calls are explicitly awaited to avoid race conditions.
  - name: generic-rules
    fileFilters:
      - "**/*"
      - "!docs/**/*"
    instructions: |
      1. Categorize comments by severity: CR (Critical), IM (Important), NP (Non-Priority), or Q (Question).
      2. Ensure error paths are explicitly handled.
```

### 4. Validate
Always execute the validation script to ensure correct YAML syntax and schema properties. During validation, you can pass the `--review` flag to inspect the parsed instructions detail block by block:
```bash
python3 .agents/skills/setup-gitlab-duo/scripts/validate.py --review
```

### 5. Review and Adjust
- **Interactive Review:** Present the generated YAML rules (or the output of the validation script with the `--review` flag) directly to the developer for feedback.
- **Adjust Rules:** 
  - The developer can make direct manual modifications to `.gitlab/duo/mr-review-instructions.yaml` in the project.
  - Or, the developer can request the agent to make adjustments (e.g. adding new file filters, updating specific checks, or excluding patterns).
- **Verify Adjustments:** Re-run the validation script after any modification to ensure structural compliance.

## Examples & References

For detailed examples of how to handle developer requests to adjust instructions (e.g. changing test frameworks or excluding files), see [EXAMPLES.md](EXAMPLES.md).


