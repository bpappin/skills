# GitHub Copilot Setup Examples

This document outlines developer-interaction workflows for reviewing, adjusting, and setting up custom repository-wide and path-specific Copilot instructions.

## Example 1: Review and Adjustment (e.g. Removing Assertions Rule)

### 1. Initial Review
The agent runs the validator in review mode:
```bash
python3 .agents/skills/setup-github-copilot/scripts/validate.py --review
```

**Output:**
```text
Validating GitHub Copilot instructions in: .github/copilot-instructions.md
Detail Review Mode Enabled
==================================================
Validation Successful.

Parsed Instructions:
# GitHub Copilot Instructions - MCLAW_Android
...
## Testing Standards
- Ensure tests cover both happy paths and edge/error cases.
- Verify Google Truth assertions are used (e.g. assertThat).
```

### 2. Developer Request
> *"Let's remove the rule about Google Truth assertions, it is too pedantic."*

### 3. Agent Adjustment
The agent edits `.github/copilot-instructions.md` to remove the line:
```diff
- - Verify Google Truth assertions are used (e.g. assertThat).
```

### 4. Verification
The agent re-runs `validate.py --review` to show the clean, updated rules.

---

## Example 2: Setting up Optional Path-Specific Instructions

### 1. Agent Inquiry
> *"I can also set up path-specific instructions (e.g. rules that apply only to test directories, or only to frontend files). Would you like to set any up now?"*

### 2. Developer Request
> *"Yes, let's create a path-specific file for test directories to make sure mock structures are preferred."*

### 3. Agent Setup
The agent creates `.github/instructions/tests.instructions.md`:
```markdown
# Copilot Instructions for Tests

When writing or reviewing test files:
1. Always prefer using MockK or mockito for mocking external dependencies rather than manual mocks.
2. Ensure test names are descriptive and written in backticks (e.g. `\`should return success when input is valid\``).
```

### 4. Verification
The agent runs validation on the path-specific instructions file:
```bash
python3 .agents/skills/setup-github-copilot/scripts/validate.py --review .github/instructions/tests.instructions.md
```
