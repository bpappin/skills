---
name: setup-github-copilot
description: Configure GitHub Copilot custom instructions at the repository level. Use when setting up or customizing Copilot instructions, creating .github/copilot-instructions.md, or setting up project-specific Copilot guidelines.
---

# Setup GitHub Copilot Instructions

Automatically configure GitHub Copilot custom repository-wide and optional path-specific instructions by parsing codebase conventions and formatting them into clean Markdown.

## Quick Start

1. **Verify or create configuration folder:**
   ```bash
   mkdir -p .github/instructions
   ```
2. **Scan for standards and source code:** Locate code review standards (e.g., `CODE_REVIEW_STANDARDS.md`) to establish baseline rules.
3. **Write configuration:** Create `.github/copilot-instructions.md`.
4. **Optional path-specific rules:** Ask the developer if they want path-specific instruction files (e.g., `.github/instructions/tests.instructions.md`).
5. **Validate schema & review:**
   ```bash
   python3 .agents/skills/setup-github-copilot/scripts/validate.py --review
   ```

## Workflows

### 1. Analyze Codebase
- Search for standard files like `CODE_REVIEW_STANDARDS.md`, `CONTRIBUTING.md`, or style guides in the root or `docs/`.
- Identify languages and frameworks. Ask the developer if they want to configure path-specific rules under `.github/instructions/` but do not require it.

### 2. Map Standards to Copilot Format
Construct repository-wide instructions under `.github/copilot-instructions.md` using distinct headings:
- **Severity Levels:** Instruct Copilot to classify its review comments using:
  - `CR: Critical` - Runtime bugs, layer separation violations, crash risks.
  - `IM: Important` - Missing error handling, inconsistent patterns, tight coupling.
  - `NP: Non-Priority` - Optional style improvements, minor readability suggestions.
  - `Q: Question` - Requests for clarity or trade-offs.
- **Organization**: Structure rules clearly under headings (`## Architectural Principles`, `## Code Quality`, `## Testing Standards`).

### 3. Generate Markdown Files
- Write the repository-wide instructions to `.github/copilot-instructions.md`.
- If requested, generate path-specific instruction files named `NAME.instructions.md` under `.github/instructions/` (e.g. `tests.instructions.md` which will automatically apply to test directories).

### 4. Validate and Review
Always execute the validation script `.agents/skills/setup-github-copilot/scripts/validate.py` (with `--review` flag) to verify markdown structure, checking for single H1 headers, content presence, and resolving placeholder text.

### 5. Review and Adjust
- Present the parsed output of the rules to the developer.
- If requested, modify the markdown sections manually or through instructions, and re-run validation.

## Examples & References

For detailed examples of how to handle developer requests to adjust instructions or configure path-specific rules, see [EXAMPLES.md](EXAMPLES.md).
