# GitLab Duo Review Setup Examples

This document provides examples of developer interaction flows for reviewing, adjusting, and verifying merge request review instructions.

## Example 1: Removing or Changing a Test Framework Requirement

### 1. Initial Review
The agent runs the validation script in review mode:
```bash
python3 .agents/skills/setup-gitlab-duo/scripts/validate.py --review
```

**Output:**
```text
  [1] Name: 'android-code-review'
      File Filters: **/*.kt
      Instructions:
        1. ...
        4. Testing:
           - Verify Google Truth assertions are used (e.g., assertThat(x).isEqualTo(y)).
```

### 2. Developer Request
The developer reviews the output and requests an adjustment:
> *"We no longer use Google Truth. Please update the testing rule to require standard JUnit assertions instead."*

### 3. Agent Adjustment
The agent modifies `.gitlab/duo/mr-review-instructions.yaml`:
```diff
-        - Verify Google Truth assertions are used (e.g., assertThat(x).isEqualTo(y) instead of assertEquals(y, x)).
+        - Verify standard JUnit or AssertJ assertions are used (e.g., assertEquals or assertThat).
```

### 4. Verification
The agent re-validates the updated configuration:
```bash
python3 .agents/skills/setup-gitlab-duo/scripts/validate.py --review
```

---

## Example 2: Adding an Exclude Filter

### 1. Developer Request
> *"I want to make sure the code review instructions do not run on generated or mock files in the `mock/` folder."*

### 2. Agent Adjustment
The agent updates the `fileFilters` in `.gitlab/duo/mr-review-instructions.yaml`:
```diff
     fileFilters:
       - "**/*.kt"
       - "**/*.java"
+      - "!**/mock/**/*"
```
