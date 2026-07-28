#!/usr/bin/env bash
# Pull YouTrack stories into a local markdown snapshot.
#
# Usage: yt-pull.sh [PROJECT_KEY] [OUT_DIR]
#   PROJECT_KEY  defaults to $YOUTRACK_PROJECT from the selected profile
#   OUT_DIR      defaults to ./docs/youtrack
#
# Connection selection: $YOUTRACK_CONNECTION, else the machine's only one,
# else the legacy env file. The snapshot is one .md per issue plus an
# INDEX.md; files are GENERATED - YouTrack stays the source of truth.
set -euo pipefail

if [[ -z "${YOUTRACK_URL:-}" ]]; then
  candidates=( )
  [[ -n "${YOUTRACK_ENV_FILE:-}" ]] && candidates+=("$YOUTRACK_ENV_FILE")
  conn="${YOUTRACK_CONNECTION:-${YOUTRACK_PROFILE:-}}"
  # no explicit connection: the project pointer names it
  if [[ -z "$conn" ]]; then
    for pf in "./.agents/config/story-tools.json" "./.agents/youtrack.json"; do
      [[ -f "$pf" ]] && { conn=$(sed -nE 's/.*"connection": *"([^"]+)".*/\1/p' "$pf" | head -1); break; }
    done
  fi
  [[ -n "$conn" ]] && candidates+=("$HOME/.agents/story-tools/connections/$conn.env")
  conns=( "$HOME"/.agents/story-tools/connections/*.env )
  [[ ${#conns[@]} -eq 1 && -f "${conns[0]}" ]] && candidates+=("${conns[0]}")
  for f in "${candidates[@]}"; do
    # shellcheck disable=SC1090
    [[ -f "$f" ]] && { source "$f"; break; }
  done
fi
YOUTRACK_URL="${YOUTRACK_URL:-${YOUTRACK_HOST:-}}"
YOUTRACK_TOKEN="${YOUTRACK_TOKEN:-${YOUTRACK_API_TOKEN:-}}"
[[ -z "$YOUTRACK_URL" || -z "$YOUTRACK_TOKEN" ]] && { echo "error: no YouTrack credentials found" >&2; exit 1; }

PROJECT="${1:-${YOUTRACK_PROJECT:-}}"
[[ -z "$PROJECT" ]] && { echo "usage: yt-pull.sh <PROJECT_KEY> [OUT_DIR]" >&2; exit 1; }
OUT="${2:-./docs/youtrack}"
mkdir -p "$OUT"

FIELDS="idReadable,summary,description,resolved,tags(name),customFields(name,value(name)),links(direction,linkType(name),issues(idReadable))"
TOP=100; SKIP=0; TOTAL=0
: > /tmp/yt-pull-issues.jsonl

while :; do
  BATCH=$(curl -sS -G "$YOUTRACK_URL/api/issues" \
    -H "Authorization: Bearer $YOUTRACK_TOKEN" \
    --data-urlencode "query=project: {$PROJECT} sort by: {issue id} asc" \
    --data-urlencode "fields=$FIELDS" \
    --data-urlencode "\$top=$TOP" \
    --data-urlencode "\$skip=$SKIP")
  COUNT=$(printf '%s' "$BATCH" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
  [[ "$COUNT" == "0" ]] && break
  printf '%s' "$BATCH" | python3 -c "
import json, sys
for it in json.load(sys.stdin):
    print(json.dumps(it))" >> /tmp/yt-pull-issues.jsonl
  TOTAL=$((TOTAL + COUNT)); SKIP=$((SKIP + TOP))
  [[ "$COUNT" -lt "$TOP" ]] && break
done

OUT="$OUT" URL="$YOUTRACK_URL" PROJECT="$PROJECT" python3 <<'EOF'
import json, os, re, datetime

out = os.environ['OUT']; url = os.environ['URL'].rstrip('/'); project = os.environ['PROJECT']
issues = [json.loads(l) for l in open('/tmp/yt-pull-issues.jsonl') if l.strip()]

def field(it, name):
    for f in it.get('customFields') or []:
        if f.get('name') == name:
            v = f.get('value')
            if isinstance(v, dict): return v.get('name')
            if isinstance(v, list): return ', '.join(x.get('name','') for x in v)
            return v
    return None

def slug(text, maxlen=60):
    t = re.sub(r'[^A-Za-z0-9]+', '-', text or '').strip('-').lower()
    return t[:maxlen].rstrip('-') or 'untitled'

index = []
for it in issues:
    iid = it['idReadable']
    state = next((v for v in (field(it, n) for n in ('Stage', 'Kanban State', 'Status', 'State')) if v), '')
    subsystem = field(it, 'Subsystem') or ''
    tags = ', '.join(t['name'] for t in it.get('tags') or [])
    links = []
    for l in it.get('links') or []:
        for li in l.get('issues') or []:
            links.append(f"{l.get('linkType',{}).get('name','link')} {li['idReadable']}")
    body = it.get('description') or '_(no description)_'
    # human-findable filename: EVO-2_title-of-the-story.md; drop stale
    # copies of this issue from earlier pulls (old name or changed title)
    fname = f"{iid}_{slug(it.get('summary'))}.md"
    for stale in os.listdir(out):
        if (stale == iid + '.md' or stale.startswith(iid + '_')) and stale != fname:
            os.remove(os.path.join(out, stale))
    with open(os.path.join(out, fname), 'w') as f:
        f.write(f"""---
id: {iid}
summary: "{(it.get('summary') or '').replace('"', "'")}"
state: "{state}"
subsystem: "{subsystem}"
resolved: {str(bool(it.get('resolved'))).lower()}
tags: "{tags}"
links: "{'; '.join(links)}"
url: {url}/issue/{iid}
---
<!-- GENERATED snapshot ({datetime.date.today()}): do not edit - YouTrack is the source of truth. Re-run scripts/yt-pull.sh to refresh. -->

# {iid}: {it.get('summary','')}

{body}
""")
    index.append((iid, fname, it.get('summary',''), state, subsystem, bool(it.get('resolved'))))

with open(os.path.join(out, 'INDEX.md'), 'w') as f:
    f.write(f"# YouTrack snapshot: project {project} ({datetime.date.today()})\n\n")
    f.write("GENERATED - do not edit. Re-run scripts/yt-pull.sh to refresh.\n\n")
    f.write("| ID | Summary | Subsystem | State | Resolved |\n|---|---|---|---|---|\n")
    for iid, fn, s, st, sub, r in index:
        f.write(f"| [{iid}]({fn}) | {s} | {sub} | {st} | {'yes' if r else ''} |\n")

print(f"Wrote {len(issues)} issues + INDEX.md to {out}")
EOF
