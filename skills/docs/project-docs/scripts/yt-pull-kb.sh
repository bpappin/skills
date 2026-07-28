#!/usr/bin/env bash
# Pull the knowledge base's Product Management zone into the repo as a
# GENERATED read-only snapshot - the KB -> repo half of the ownership model.
#
# The zone is canonical in YouTrack; the snapshot exists so agents keep PM
# material (mandates, BSA docs, support, design direction) in context while
# working. Never edit the snapshot - re-run this script to refresh it.
#
# Usage: yt-pull-kb.sh [--zone "Product Management"] [--project KEY]
#                      [--force] [--dry-run] [OUT_DIR]
#   OUT_DIR    default ./docs/product
#   --force    overwrite an OUT_DIR that wasn't created by this script
#              (first pull over hand-pushed interim copies needs this)
#   --dry-run  fetch and print the planned tree; write nothing
#
# Layout mirrors the publisher's convention in reverse: an article with
# children becomes a directory whose README.md holds its content; a leaf
# article becomes <slug>.md. The zone root's content lands in
# OUT_DIR/README.md. A .yt-kb-pull.json stamp marks the dir as generated.
set -euo pipefail

ZONE="Product Management"; PROJECT="${YOUTRACK_PROJECT:-}"; OUT=""; FORCE=0; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --zone) ZONE="$2"; shift 2;;
    --project) PROJECT="$2"; shift 2;;
    --force) FORCE=1; shift;;
    --dry-run) DRY=1; shift;;
    *) OUT="$1"; shift;;
  esac
done
OUT="${OUT:-./docs/product}"

if [[ -z "${YOUTRACK_URL:-}" ]]; then
  candidates=( )
  [[ -n "${YOUTRACK_ENV_FILE:-}" ]] && candidates+=("$YOUTRACK_ENV_FILE")
  conn="${YOUTRACK_CONNECTION:-${YOUTRACK_PROFILE:-}}"
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
[[ -z "$YOUTRACK_URL" || -z "$YOUTRACK_TOKEN" ]] && { echo "error: no YouTrack credentials found - run the story-tools installer" >&2; exit 1; }
if [[ -z "$PROJECT" ]]; then
  for pf in "./.agents/config/story-tools.json" "./.agents/youtrack.json"; do
    [[ -f "$pf" ]] && { PROJECT=$(sed -nE 's/.*"project": *"([^"]+)".*/\1/p' "$pf" | head -1); break; }
  done
fi
[[ -z "$PROJECT" ]] && { echo "error: no project key (--project or .agents/config/story-tools.json)" >&2; exit 1; }

# safety: only regenerate a dir this script owns, unless --force
if [[ "$DRY" != 1 && -d "$OUT" && -n "$(ls -A "$OUT" 2>/dev/null)" && ! -f "$OUT/.yt-kb-pull.json" && "$FORCE" != 1 ]]; then
  echo "error: $OUT exists, is not empty, and has no .yt-kb-pull.json stamp." >&2
  echo "If its contents were interim hand-pushed copies (now canonical in YouTrack)," >&2
  echo "re-run with --force to replace them with the generated snapshot." >&2
  exit 1
fi

export YOUTRACK_URL YOUTRACK_TOKEN PROJECT ZONE OUT DRY
python3 <<'EOF'
import datetime, json, os, re, shutil, sys, urllib.request, urllib.parse

URL = os.environ['YOUTRACK_URL'].rstrip('/')
TOKEN = os.environ['YOUTRACK_TOKEN']
PROJECT = os.environ['PROJECT']
ZONE = os.environ['ZONE']
OUT = os.environ['OUT'].rstrip('/')
DRY = os.environ['DRY'] == '1'

def api(path):
    req = urllib.request.Request(URL + path, headers={'Authorization': 'Bearer ' + TOKEN})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

projects = api(f'/api/admin/projects?fields=id,shortName&query={urllib.parse.quote(PROJECT)}')
pid = next((p['id'] for p in projects if p.get('shortName') == PROJECT), None)
if not pid:
    sys.exit(f'error: project {PROJECT} not found or not visible')

articles, skip = [], 0
while True:
    batch = api('/api/articles?fields=id,idReadable,summary,content,parentArticle(id),project(shortName)'
                f'&$top=100&$skip={skip}')
    if not batch: break
    articles += [a for a in batch if (a.get('project') or {}).get('shortName') == PROJECT]
    if len(batch) < 100: break
    skip += 100

by_parent = {}
for a in articles:
    by_parent.setdefault((a.get('parentArticle') or {}).get('id'), []).append(a)

root = next((a for a in by_parent.get(None, []) if a.get('summary') == ZONE), None)
if not root:
    print(f'No "{ZONE}" zone exists in the knowledge base yet - nothing to pull.')
    sys.exit(0)

def slug(text, maxlen=60):
    t = re.sub(r'[^A-Za-z0-9]+', '-', text or '').strip('-').lower()
    return t[:maxlen].rstrip('-') or 'untitled'

stamp = datetime.date.today().isoformat()
count = 0

def banner(a):
    return (f'<!-- GENERATED snapshot ({stamp}) of knowledge-base article '
            f'"{a.get("summary","")}" ({a.get("idReadable","")}) - canonical in YouTrack: '
            f'{URL}/articles/{a.get("idReadable","")}\n'
            f'     Do not edit this file; edit the article. Refresh with yt-pull-kb.sh -->\n\n')

def emit(a, dirpath):
    global count
    children = by_parent.get(a['id'], [])
    body = (a.get('content') or '').strip()
    if children:
        sub = dirpath if a is root else os.path.join(dirpath, slug(a.get('summary')))
        if DRY:
            print(f'  dir : {sub}/  ("{a.get("summary","")}")')
        else:
            os.makedirs(sub, exist_ok=True)
            open(os.path.join(sub, 'README.md'), 'w').write(banner(a) + body + '\n')
        count += 1
        for c in sorted(children, key=lambda x: x.get('summary') or ''):
            emit(c, sub)
    else:
        path = os.path.join(dirpath, slug(a.get('summary')) + '.md')
        if DRY:
            print(f'  file: {path}  ("{a.get("summary","")}")')
        else:
            os.makedirs(dirpath, exist_ok=True)
            open(path, 'w').write(banner(a) + body + '\n')
        count += 1

if DRY:
    print(f'(dry run) zone "{ZONE}" -> {OUT}/')
    emit(root, OUT)
    print(f'(dry run) {count} articles; nothing written')
else:
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT, exist_ok=True)
    emit(root, OUT)
    json.dump({'zone': ZONE, 'project': PROJECT, 'pulled': stamp, 'articles': count},
              open(os.path.join(OUT, '.yt-kb-pull.json'), 'w'), indent=2)
    print(f'Pulled {count} articles from "{ZONE}" into {OUT}/ (generated - do not edit).')
EOF
