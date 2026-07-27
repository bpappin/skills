#!/usr/bin/env bash
# One-way publisher: the repo docs tree -> YouTrack knowledge-base articles.
#
# Mirrors the file hierarchy as the article hierarchy:
#   "Project Docs" (root)
#     └── reference            (article per directory, any depth)
#           └── vendors
#                 └── OSM      (article per .md file)
#
# Usage: yt-publish.sh [--dirs adr,prd,...] [--project KEY] [DOCS_DIR]
#   --dirs     limit to these top-level subdirs (default: every subdir)
#   --project  YouTrack project key (default: $YOUTRACK_PROJECT or
#              .agents/config/story-tools.json next to DOCS_DIR)
#   DOCS_DIR   default ./docs
#
# Always skipped: docs/youtrack/ (the yt-pull snapshot - publishing it
# would mirror YouTrack into YouTrack), non-.md files, README.md indexes,
# and any path matching a glob line in DOCS_DIR/.yt-publish-ignore.
#
# One-way, idempotent: DOCS_DIR/.yt-articles.json maps path -> article id
# (commit it). Articles carry a do-not-edit banner. The repo is canonical.
set -euo pipefail

DIRS=""; PROJECT="${YOUTRACK_PROJECT:-}"; DOCS_DIR="./docs"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dirs) DIRS="$2"; shift 2;;
    --project) PROJECT="$2"; shift 2;;
    *) DOCS_DIR="$1"; shift;;
  esac
done

if [[ -z "${YOUTRACK_URL:-}" ]]; then
  candidates=( )
  [[ -n "${YOUTRACK_ENV_FILE:-}" ]] && candidates+=("$YOUTRACK_ENV_FILE")
  conn="${YOUTRACK_CONNECTION:-${YOUTRACK_PROFILE:-}}"
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

if [[ -z "$PROJECT" ]]; then
  for pf in "$DOCS_DIR/../.agents/config/story-tools.json" "$DOCS_DIR/../.agents/youtrack.json"; do
    [[ -f "$pf" ]] && { PROJECT=$(sed -nE 's/.*"project": *"([^"]+)".*/\1/p' "$pf" | head -1); break; }
  done
fi
[[ -z "$PROJECT" ]] && { echo "error: no project key (--project, \$YOUTRACK_PROJECT, or .agents/config/story-tools.json)" >&2; exit 1; }

export YOUTRACK_URL YOUTRACK_TOKEN PROJECT DIRS DOCS_DIR
python3 <<'EOF'
import fnmatch, json, os, re, sys, urllib.request, urllib.parse, datetime

URL = os.environ['YOUTRACK_URL'].rstrip('/')
TOKEN = os.environ['YOUTRACK_TOKEN']
PROJECT = os.environ['PROJECT']
ONLY = [d.strip() for d in os.environ['DIRS'].split(',') if d.strip()]
DOCS = os.environ['DOCS_DIR'].rstrip('/')
MAP_PATH = os.path.join(DOCS, '.yt-articles.json')
ALWAYS_SKIP = {'youtrack'}

ignore_globs = []
ign = os.path.join(DOCS, '.yt-publish-ignore')
if os.path.exists(ign):
    ignore_globs = [l.strip() for l in open(ign) if l.strip() and not l.startswith('#')]

def ignored(rel):
    return any(fnmatch.fnmatch(rel, g) for g in ignore_globs)

def api(path, payload=None, method=None):
    req = urllib.request.Request(
        URL + path,
        data=json.dumps(payload).encode() if payload is not None else None,
        headers={'Authorization': 'Bearer ' + TOKEN, 'Content-Type': 'application/json'},
        method=method or ('POST' if payload is not None else 'GET'))
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else None

def exists(article_id):
    try:
        api(f'/api/articles/{article_id}?fields=id')
        return True
    except urllib.error.HTTPError:
        return False

projects = api(f'/api/admin/projects?fields=id,shortName&query={urllib.parse.quote(PROJECT)}')
pid = next((p['id'] for p in projects if p.get('shortName') == PROJECT), None)
if not pid:
    sys.exit(f'error: project {PROJECT} not found or not visible')

amap = json.load(open(MAP_PATH)) if os.path.exists(MAP_PATH) else {}
stamp = datetime.date.today().isoformat()

def upsert(key, summary, content, parent_id=None):
    aid = amap.get(key)
    payload = {'summary': summary, 'content': content}
    if aid and exists(aid):
        api(f'/api/articles/{aid}?fields=id', payload)
        return aid, 'updated'
    payload['project'] = {'id': pid}
    if parent_id:
        payload['parentArticle'] = {'id': parent_id}
    created = api('/api/articles?fields=id', payload)
    amap[key] = created['id']
    return created['id'], 'created'

counts = {'created': 0, 'updated': 0, 'skipped': 0}

def publish_dir(relpath, parent_id):
    """relpath '' = DOCS root. Returns number of docs published beneath."""
    abspath = os.path.join(DOCS, relpath) if relpath else DOCS
    n = 0
    for entry in sorted(os.listdir(abspath)):
        rel = f'{relpath}/{entry}' if relpath else entry
        full = os.path.join(abspath, entry)
        if os.path.isdir(full):
            if entry.startswith('.') or entry in ALWAYS_SKIP and not relpath:
                continue
            if not relpath and ONLY and entry not in ONLY:
                continue
            if ignored(rel):
                counts['skipped'] += 1
                continue
            dir_id, act = upsert(rel + '/', entry,
                f'Generated mirror of `docs/{rel}/` ({stamp}). Do not edit here.', parent_id)
            sub = publish_dir(rel, dir_id)
            if sub == 0 and act == 'created':
                pass  # empty branch stays as a placeholder; harmless
            print(f'  {act}: {rel}/')
            n += sub
        elif entry.endswith('.md') and entry != 'README.md':
            if ignored(rel):
                counts['skipped'] += 1
                continue
            text = open(full, encoding='utf-8').read()
            m = re.search(r'^#\s+(.+)$', text, re.M)
            title = m.group(1).strip() if m else entry[:-3]
            banner = (f'> **Generated** from `docs/{rel}` ({stamp}) - the repo is canonical. '
                      'Do not edit this article; edit the file and re-publish.\n\n')
            _, act = upsert(rel, title, banner + text, parent_id)
            counts[act] += 1
            print(f'  {act}: {rel} -> "{title}"')
            n += 1
    return n

root_id, act = upsert('__root__', 'Project Docs',
    f'Generated mirror of the repository `docs/` tree ({stamp}). '
    'THE REPO IS CANONICAL - do not edit these articles; edit the repo and re-publish.')
print(f'  {act}: Project Docs (root)')
total = publish_dir('', root_id)

json.dump(dict(sorted(amap.items())), open(MAP_PATH, 'w'), indent=2)
print(f"\nPublished {total} docs ({counts['created']} created, {counts['updated']} updated, "
      f"{counts['skipped']} ignored). Map: {MAP_PATH} (commit it).")
EOF
