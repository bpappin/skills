#!/usr/bin/env python3
import os
import re
import requests
import json
import sys
from pathlib import Path

def load_config_and_secrets():
    config_path = Path(".config/project.json")
    if not config_path.exists():
        print("Error: .config/project.json not found in the project root.")
        exit(1)
        
    with open(config_path, "r") as f:
        config = json.load(f)
        
    project_id = config.get("project_id")
    if not project_id:
        print("Error: project_id not found in .config/project.json.")
        exit(1)
        
    # Load secrets
    secret_path = Path.home() / ".secrets" / "agents" / project_id / "github.env"
    if secret_path.exists():
        with open(secret_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip().strip('"').strip("'")
    
    return config

try:
    config = load_config_and_secrets()
except SystemExit:
    config = {}

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
REPO = os.getenv("GITHUB_REPOSITORY")
PROJECT_ID = config.get("project_id")

if PROJECT_ID:
    specific_token_key = f"{PROJECT_ID}_GITHUB_TOKEN"
    GITHUB_TOKEN = os.getenv(specific_token_key) or GITHUB_TOKEN

SYNC_ENABLED = bool(GITHUB_TOKEN and REPO)
DRY_RUN = os.getenv("DRY_RUN", "false").lower() == "true"

def update_github_issue(issue_number, state=None, labels=None):
    """Updates an existing GitHub issue."""
    if DRY_RUN:
        print(f"[DRY RUN] Would update issue #{issue_number} with state={state}, labels={labels}")
        return True

    if not GITHUB_TOKEN or not REPO:
        return False

    url = f"https://api.github.com/repos/{REPO}/issues/{issue_number}"
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    payload = {}
    if state:
        payload["state"] = state
    if labels:
        payload["labels"] = labels
    
    try:
        response = requests.patch(url, headers=headers, json=payload)
        return response.status_code == 200
    except Exception as e:
        print(f"Error updating issue #{issue_number}: {e}")
        return False

def create_github_issue(title, body, labels=None):
    """Creates a GitHub issue and returns the issue number."""
    if DRY_RUN:
        print(f"[DRY RUN] Would create issue: {title}")
        return "MOCK_ID"

    if not GITHUB_TOKEN or not REPO:
        return None

    url = f"https://api.github.com/repos/{REPO}/issues"
    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    payload = {
        "title": title,
        "body": body,
        "labels": labels or ["documentation-sync"]
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload)
        if response.status_code == 201:
            return response.json().get("number")
        else:
            print(f"Failed to create issue: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error connecting to GitHub: {e}")
        return None

def update_id_in_index_files(old_id, new_id, file_basename):
    """Searches index files and replaces old_id with new_id on lines referencing file_basename."""
    index_files = list(Path("docs").rglob("README.md")) + list(Path("docs/prd").rglob("*.md"))
    for idx_file in index_files:
        if not idx_file.exists(): continue
        try:
            with open(idx_file, "r") as f:
                content = f.read()
            if file_basename in content and old_id in content:
                lines = content.splitlines()
                modified = False
                for i, line in enumerate(lines):
                    if file_basename in line and old_id in line:
                        lines[i] = line.replace(old_id, new_id)
                        modified = True
                if modified:
                    if not DRY_RUN:
                        with open(idx_file, "w") as f:
                            f.write("
".join(lines) + "
")
                        print(f"  Updated index {idx_file} -> {new_id}")
                    else:
                        print(f"  [DRY RUN] Would update index {idx_file} -> {new_id}")
        except Exception as e:
            print(f"Error processing index {idx_file}: {e}")

def sync_format_a_file(filepath):
    """Parses a Format A markdown file and syncs it with GitHub."""
    with open(filepath, "r") as f:
        content = f.read()
    
    # Parse Format A metadata
    id_match = re.search(r"\*\*ID:\*\*\s+\[(.*?)\]", content)
    status_match = re.search(r"\*\*Status:\*\*\s+(.*)", content)
    
    if not id_match:
        return
        
    issue_id = id_match.group(1).strip()
    status = status_match.group(1).strip() if status_match else "TODO"
    
    # Extract Title (first heading)
    title_match = re.search(r"^#\s+(.*)", content, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else filepath.stem
    
    gh_state = "closed" if status in ["DONE", "OBSOLETE"] else "open"
    
    default_labels = ["documentation-sync"]
    if "gap" in filepath.parts:
        default_labels.append("technical-debt")
    
    if issue_id == "#NEW":
        if SYNC_ENABLED or DRY_RUN:
            print(f"Syncing new issue: {title}")
            new_id = create_github_issue(title, f"Sync source: {filepath}

{content}", labels=default_labels)
            if new_id:
                real_id = f"{new_id}"
                new_content = content.replace("**ID:** [#NEW]", f"**ID:** [{real_id}]")
                if not DRY_RUN:
                    with open(filepath, "w") as f:
                        f.write(new_content)
                    print(f"  Updated {filepath} with new ID: [{real_id}]")
                update_id_in_index_files("[#NEW]", f"[{real_id}]", filepath.name)
        else:
            print(f"Skipping new issue creation (sync disabled): {title}")
    elif issue_id.isdigit():
        if SYNC_ENABLED or DRY_RUN:
            print(f"Updating issue #{issue_id} status to {gh_state} for: {title}")
            update_github_issue(issue_id, state=gh_state)

def sync_project_docs():
    """Scans relevant directories for Format A files to sync."""
    search_paths = [Path("docs/prd"), Path("docs/gap")]
    for path in search_paths:
        if not path.exists():
            continue
        for filepath in path.rglob("*.md"):
            if filepath.name == "README.md":
                continue
            sync_format_a_file(filepath)

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--create-skeleton":
        title = sys.argv[2]
        new_id = create_github_issue(title, f"Skeleton for PRD: {title}", labels=["documentation-sync"])
        if new_id:
            print(new_id)
        else:
            print("FAILED")
        sys.exit(0)

    if DRY_RUN:
        print("--- RUNNING IN DRY RUN MODE ---")
    if not SYNC_ENABLED and not DRY_RUN:
        print("Note: GitHub Token or Repository not configured. Issue synchronization is disabled.")
    
    if config:
        sync_project_docs()
