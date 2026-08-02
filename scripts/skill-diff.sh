#!/usr/bin/env bash
# What moved between two VERSIONS.json manifests?
#
# Usage: skill-diff.sh <old.json> <new.json>
#
# Prints one line per skill that changed, was added, or was removed.
# Exits 1 when nothing moved - the signal that there is nothing to
# publish. Missing or unreadable old file means everything is new.
set -euo pipefail

OLD="${1:-}"; NEW="${2:-}"
[[ -f "$NEW" ]] || { echo "usage: skill-diff.sh <old.json> <new.json>" >&2; exit 2; }

python3 - "$OLD" "$NEW" <<'PY'
import json, os, sys

def load(p):
    if not p or not os.path.isfile(p):
        return {}
    try:
        return json.load(open(p, encoding='utf-8')).get('skills', {})
    except Exception:
        return {}

old, new = load(sys.argv[1]), load(sys.argv[2])
moved = []

for name, v in sorted(new.items()):
    if name not in old:
        moved.append(f'added    {name} {v}')
    elif old[name] != v:
        moved.append(f'updated  {name} {old[name]} -> {v}')
for name in sorted(old):
    if name not in new:
        moved.append(f'removed  {name}')

if not moved:
    sys.exit(1)
print('\n'.join(moved))
PY
