#!/usr/bin/env python3
import sys
import os
import re

def validate_markdown(file_path, show_details=False):
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' does not exist.")
        return False

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
    except Exception as e:
        print(f"Error: Could not read file '{file_path}': {e}")
        return False

    errors = []
    lines = content.splitlines()

    # 1. Check if empty
    if not content.strip():
        errors.append("File is empty.")

    # 2. Check heading hierarchy
    h1_count = 0
    h1_title = ""
    for idx, line in enumerate(lines):
        line_num = idx + 1
        if line.startswith("# "):
            h1_count += 1
            h1_title = line[2:].strip()
        elif line.startswith("#") and not line.startswith("##") and not line.startswith("# "):
            errors.append(f"Line {line_num}: Malformed H1 header (needs space after '#').")

    if h1_count == 0:
        errors.append("Missing H1 title (starts with '# ').")
    elif h1_count > 1:
        errors.append(f"Found multiple H1 titles ({h1_count}). Only one H1 title is allowed per instructions file.")

    # 3. Check for placeholders
    placeholder_patterns = [
        r"<TODO[^>]*>",
        r"\[TODO[^\]]*\]",
        r"\[replace[^\]]*\]",
        r"<insert[^>]*>",
        r"\[insert[^\]]*\]",
        r"your-project-name",
        r"your-org-name"
    ]
    for idx, line in enumerate(lines):
        line_num = idx + 1
        for pattern in placeholder_patterns:
            if re.search(pattern, line, re.IGNORECASE):
                errors.append(f"Line {line_num}: Found unresolved placeholder '{line.strip()}'.")
                break

    if errors:
        print("Markdown Validation Failed:")
        for err in errors:
            print(f"  - {err}")
        return False
    else:
        print("Validation Successful.")
        print(f"  Title: '{h1_title}'")
        print(f"  Size: {len(lines)} line(s)")
        if show_details:
            print("\nParsed Instructions:\n" + "=" * 50)
            print(content.strip())
            print("=" * 50 + "\n")
        return True

if __name__ == "__main__":
    target_path = ".github/copilot-instructions.md"
    show_details = False

    args = sys.argv[1:]
    if "--review" in args:
        show_details = True
        args.remove("--review")

    if args:
        target_path = args[0]

    print(f"Validating GitHub Copilot instructions in: {target_path}")
    if show_details:
        print("Detail Review Mode Enabled\n" + "=" * 50)

    success = validate_markdown(target_path, show_details=show_details)
    sys.exit(0 if success else 1)
