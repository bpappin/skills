#!/usr/bin/env python3
import sys
import os

def validate_instruction(inst, line_num, errors):
    if not inst.get('name'):
        errors.append(f"Instruction item ending near line {line_num} has an empty or missing 'name'")
    if not inst.get('fileFilters'):
        errors.append(f"Instruction '{inst.get('name', 'unnamed')}' near line {line_num} has empty or missing 'fileFilters'")
    if not inst.get('instructions'):
        errors.append(f"Instruction '{inst.get('name', 'unnamed')}' near line {line_num} has empty or missing 'instructions'")

def validate_yaml(file_path, show_details=False):
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' does not exist.")
        return False

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error: Could not read file '{file_path}': {e}")
        return False

    errors = []
    instructions = []
    current_instruction = None
    state = "ROOT"  # ROOT, INSTRUCTIONS, INST_ITEM, FILE_FILTERS, INST_TEXT
    multiline_indent = 0
    multiline_text = []

    for i, raw_line in enumerate(lines):
        line_num = i + 1

        # Handle multiline text block
        if state == "INST_TEXT":
            stripped = raw_line.lstrip()
            if not stripped:
                multiline_text.append(raw_line)
                continue
            indent = len(raw_line) - len(stripped)
            if indent <= multiline_indent:
                # End of multiline text block
                if current_instruction:
                    current_instruction['instructions'] = "".join(multiline_text).strip()
                state = "INST_ITEM"
                # Fall through to process this line in the INST_ITEM state
            else:
                multiline_text.append(raw_line[multiline_indent:])
                continue

        # Strip comments and trailing whitespace
        line = raw_line.split('#')[0].rstrip()
        if not line.strip():
            continue

        stripped = line.lstrip()
        indent = len(line) - len(stripped)

        if state == "ROOT":
            if stripped == "instructions:":
                if indent != 0:
                    errors.append(f"Line {line_num}: 'instructions:' must be at root level (indentation 0)")
                state = "INSTRUCTIONS"
            else:
                errors.append(f"Line {line_num}: Expected root element 'instructions:' but got '{stripped}'")

        elif state in ("INSTRUCTIONS", "INST_ITEM"):
            if stripped.startswith("- name:"):
                if indent != 2:
                    errors.append(f"Line {line_num}: Instruction item must be indented by 2 spaces")
                if current_instruction:
                    validate_instruction(current_instruction, line_num - 1, errors)
                name_val = stripped[7:].strip()
                if (name_val.startswith('"') and name_val.endswith('"')) or (name_val.startswith("'") and name_val.endswith("'")):
                    name_val = name_val[1:-1]
                current_instruction = {
                    'name': name_val,
                    'fileFilters': [],
                    'instructions': None
                }
                instructions.append(current_instruction)
                state = "INST_ITEM"
            elif stripped == "fileFilters:":
                if not current_instruction:
                    errors.append(f"Line {line_num}: 'fileFilters:' found outside of instruction item")
                elif indent != 4:
                    errors.append(f"Line {line_num}: 'fileFilters:' must be indented by 4 spaces")
                state = "FILE_FILTERS"
            elif stripped.startswith("instructions:"):
                if not current_instruction:
                    errors.append(f"Line {line_num}: 'instructions:' found outside of instruction item")
                elif indent != 4:
                    errors.append(f"Line {line_num}: 'instructions:' key must be indented by 4 spaces")
                
                val = stripped[13:].strip()
                if val.startswith('|'):
                    state = "INST_TEXT"
                    # Try to dynamically set multiline indent or default to at least 6
                    multiline_indent = indent
                    multiline_text = []
                else:
                    if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                        val = val[1:-1]
                    if current_instruction:
                        current_instruction['instructions'] = val
            else:
                errors.append(f"Line {line_num}: Unexpected line under instruction item: '{stripped}'")

        elif state == "FILE_FILTERS":
            if stripped.startswith("-"):
                if indent != 6:
                    errors.append(f"Line {line_num}: File filter items must be indented by 6 spaces")
                filter_val = stripped[1:].strip()
                if (filter_val.startswith('"') and filter_val.endswith('"')) or (filter_val.startswith("'") and filter_val.endswith("'")):
                    filter_val = filter_val[1:-1]
                if current_instruction:
                    current_instruction['fileFilters'].append(filter_val)
            else:
                # No longer in fileFilters, transitions back and we parse this line
                state = "INST_ITEM"
                if stripped.startswith("- name:"):
                    if indent != 2:
                        errors.append(f"Line {line_num}: Instruction item must be indented by 2 spaces")
                    if current_instruction:
                        validate_instruction(current_instruction, line_num - 1, errors)
                    name_val = stripped[7:].strip()
                    if (name_val.startswith('"') and name_val.endswith('"')) or (name_val.startswith("'") and name_val.endswith("'")):
                        name_val = name_val[1:-1]
                    current_instruction = {
                        'name': name_val,
                        'fileFilters': [],
                        'instructions': None
                    }
                    instructions.append(current_instruction)
                elif stripped.startswith("instructions:"):
                    if indent != 4:
                        errors.append(f"Line {line_num}: 'instructions:' key must be indented by 4 spaces")
                    val = stripped[13:].strip()
                    if val.startswith('|'):
                        state = "INST_TEXT"
                        multiline_indent = indent
                        multiline_text = []
                    else:
                        if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                            val = val[1:-1]
                        if current_instruction:
                            current_instruction['instructions'] = val
                else:
                    errors.append(f"Line {line_num}: Expected file filter item starting with '-' or another instruction block field, but got '{stripped}'")

    # Wrap up any trailing items
    if state == "INST_TEXT" and current_instruction:
        current_instruction['instructions'] = "".join(multiline_text).strip()
    if current_instruction:
        validate_instruction(current_instruction, len(lines), errors)

    if not instructions and not errors:
        errors.append("File contains no GitLab Duo instruction blocks under 'instructions:'")

    if errors:
        print("YAML Validation Failed:")
        for err in errors:
            print(f"  - {err}")
        return False
    else:
        print(f"Validation Successful: Checked {len(instructions)} instruction block(s).\n")
        for idx, inst in enumerate(instructions):
            print(f"  [{idx + 1}] Name: '{inst['name']}'")
            print(f"      File Filters: {', '.join(inst['fileFilters'])}")
            if show_details:
                print("      Instructions:")
                indented_inst = "\n".join("        " + line for line in inst['instructions'].splitlines())
                print(indented_inst)
                print()
            else:
                print(f"      Instructions: {len(inst['instructions'].splitlines())} line(s)\n")
        return True

if __name__ == "__main__":
    target_path = ".gitlab/duo/mr-review-instructions.yaml"
    show_details = False

    args = sys.argv[1:]
    if "--review" in args:
        show_details = True
        args.remove("--review")

    if args:
        target_path = args[0]

    print(f"Validating GitLab Duo instructions in: {target_path}")
    if show_details:
        print("Detail Review Mode Enabled\n" + "=" * 50)

    success = validate_yaml(target_path, show_details=show_details)
    sys.exit(0 if success else 1)
