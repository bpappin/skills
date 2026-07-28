#!/usr/bin/env bash
# Push a locally-authored document INTO the Product Management zone of the
# knowledge base - the repo -> PM half of cross-zone authoring.
#
# This is a HAND-OFF AT BIRTH, not a sync: the created article is canonical
# from that moment. Do not keep a copy under docs/development/ - the
# content returns to the repo as a read-only snapshot via the PM pull.
# Articles created here carry NO generated banner (they are the original).
#
# Usage: yt-pm-push.sh FILE [--section "Mandates & Compliance"]
#                           [--zone "Product Management"] [--project KEY]
#                           [--update] [--dry-run]
#   FILE       markdown file to push; title = its first # heading
#   --section  section under the zone to file it in (created if missing);
#              omit to file directly under the zone root
#   --zone     zone root article name (default "Product Management",
#              created if missing)
#   --update   overwrite an existing article with the same title in the
#              target section (default: refuse - after the hand-off, edits
#              belong in YouTrack, not here)
#   --dry-run  print what would happen; no credentials needed
set -euo pipefail

FILE=""; SECTION=""; ZONE="Product Management"; PROJECT="${YOUTRACK_PROJECT:-}"; UPDATE=0; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --section) SECTION="$2"; shift 2;;
    --zone) ZONE="$2"; shift 2;;
    --project) PROJECT="$2"; shift 2;;
    --update) UPDATE=1; shift;;
    --dry-run) DRY=1; shift;;
    *) FILE="$1"; shift;;
  esac
done
[[ -n "$FILE" && -f "$FILE" ]] || { echo "usage: yt-pm-push.sh FILE [--section NAME] [--update] [--dry-run]" >&2; exit 1; }

if [[ "$DRY" == 1 ]]; then
  title=$(sed -nE 's/^# +(.+)$/\1/p' "$FILE" | head -1)
  [[ -z "$title" ]] && title="$(basename "$FILE" .md)"
  echo "(dry run) would create article \"$title\" under \"$ZONE\"${SECTION:+ > \"$SECTION\"}"
  echo "(dry run) source: $FILE - after a real push, remove/archive the local copy;"
  echo "the article is canonical and returns via the docs/product/ pull."
  exit 0
fi

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

export YOUTRACK_URL YOUTRACK_TOKEN PROJECT FILE SECTION ZONE UPDATE
python3 <<'EOF'
import json, os, re, sys, urllib.request, urllib.parse

URL = os.environ['YOUTRACK_URL'].rstrip('/')
TOKEN = os.environ['YOUTRACK_TOKEN']
PROJECT = os.environ['PROJECT']
FILE = os.environ['FILE']
SECTION = os.environ['SECTION']
ZONE = os.environ['ZONE']
UPDATE = os.environ['UPDATE'] == '1'

def api(path, payload=None, method=None):
    req = urllib.request.Request(
        URL + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'Authorization': 'Bearer ' + TOKEN, 'Content-Type': 'application/json'},
        method=method or ('POST' if payload is not None else 'GET'))
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else None

projects = api(f'/api/admin/projects?fields=id,shortName&query={urllib.parse.quote(PROJECT)}')
pid = next((p['id'] for p in projects if p.get('shortName') == PROJECT), None)
if not pid:
    sys.exit(f'error: project {PROJECT} not found or not visible')

# fetch the project's articles (paged) to locate zone/section/duplicates
articles, skip = [], 0
while True:
    batch = api(f'/api/articles?fields=id,summary,parentArticle(id),project(shortName)&$top=200&$skip={skip}')
    if not batch: break
    articles += [a for a in batch if (a.get('project') or {}).get('shortName') == PROJECT]
    if len(batch) < 200: break
    skip += 200

def find(summary, parent_id):
    for a in articles:
        pa = (a.get('parentArticle') or {}).get('id')
        if a.get('summary') == summary and pa == parent_id:
            return a['id']
    return None

def create(summary, content, parent_id=None):
    payload = {'summary': summary, 'content': content, 'project': {'id': pid}}
    if parent_id:
        payload['parentArticle'] = {'id': parent_id}
    return api('/api/articles?fields=id', payload)['id']

zone_id = find(ZONE, None)
if not zone_id:
    zone_id = create(ZONE, f'{ZONE} - authored here in the knowledge base by its owners. '
                           'This zone is canonical; the repository holds only a read-only snapshot.')
    print(f'  created zone root: "{ZONE}"')

parent_id = zone_id
if SECTION:
    sec_id = find(SECTION, zone_id)
    if not sec_id:
        sec_id = create(SECTION, f'{SECTION}.', zone_id)
        print(f'  created section: "{SECTION}"')
    parent_id = sec_id

text = open(FILE, encoding='utf-8').read()
m = re.search(r'^#\s+(.+)$', text, re.M)
title = m.group(1).strip() if m else os.path.splitext(os.path.basename(FILE))[0]

existing = find(title, parent_id)
if existing and not UPDATE:
    sys.exit(f'error: an article "{title}" already exists there. After the hand-off, edits belong '
             'in YouTrack - or pass --update to overwrite it deliberately.')
if existing:
    api(f'/api/articles/{existing}?fields=id', {'summary': title, 'content': text})
    print(f'  updated: "{title}"')
else:
    create(title, text, parent_id)
    print(f'  created: "{title}" under "{ZONE}"' + (f' > "{SECTION}"' if SECTION else ''))

print()
print('Hand-off complete: the ARTICLE is now canonical. Remove or archive the local')
print('file (do not keep it under docs/development/) - the content returns to the')
print('repo as a read-only snapshot via the Product Management pull.')
EOF
