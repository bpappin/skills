#!/usr/bin/env bash
# Work out the repo's next version from how the skills moved.
#
# Usage: next-version.sh <old VERSIONS.json> <new VERSIONS.json> [last-version]
#
# The largest per-skill bump decides the repo bump: any skill major -> a
# major release, any minor -> minor, otherwise patch. A new skill counts
# as minor, a removed one as minor. No movement at all prints nothing and
# exits 1, which is the signal that there is nothing to release.
set -euo pipefail

OLD="${1:-}"; NEW="${2:-}"; LAST="${3:-0.0.0}"
[[ -f "$NEW" ]] || { echo "usage: next-version.sh <old.json> <new.json> [last]" >&2; exit 2; }

python3 - "$OLD" "$NEW" "${LAST#v}" <<'PY'
import json, os, sys

old_p, new_p, last = sys.argv[1:4]

def load(p):
    if not p or not os.path.isfile(p):
        return {}
    try:
        return json.load(open(p, encoding='utf-8')).get('skills', {})
    except Exception:
        return {}

old, new = load(old_p), load(new_p)

def parts(v):
    out = []
    for chunk in str(v).split('.')[:3]:
        digits = ''.join(c for c in chunk if c.isdigit())
        out.append(int(digits or 0))
    while len(out) < 3:
        out.append(0)
    return out

rank = {'patch': 0, 'minor': 1, 'major': 2}
level, moved = None, []

def raise_to(kind):
    global level
    if level is None or rank[kind] > rank[level]:
        level = kind

for name, v in new.items():
    if name not in old:
        raise_to('minor'); moved.append(f'+ {name} {v}')
        continue
    if old[name] == v:
        continue
    a, b = parts(old[name]), parts(v)
    kind = 'major' if b[0] != a[0] else 'minor' if b[1] != a[1] else 'patch'
    raise_to(kind); moved.append(f'  {name} {old[name]} -> {v}')

for name in old:
    if name not in new:
        raise_to('minor'); moved.append(f'- {name} (removed)')

if level is None:
    sys.exit(1)                      # nothing moved: no release

M, m, p = parts(last)
if level == 'major':   M, m, p = M + 1, 0, 0
elif level == 'minor': m, p = m + 1, 0
else:                  p += 1

print(f'{M}.{m}.{p}')
print(level, file=sys.stderr)
for line in moved:
    print(line, file=sys.stderr)
PY
