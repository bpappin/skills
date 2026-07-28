#!/usr/bin/env bash
# One-way publisher: the repo docs tree -> YouTrack knowledge-base articles.
#
# Mirrors the file hierarchy as the article hierarchy:
#   "Product Development" (root, or docs/README.md's H1)
#     └── Reference            (article per directory, any depth)
#           └── Vendors
#                 └── OpenStreetMap   (article per .md file, titled by H1)
#
# Usage: yt-publish.sh [--dirs adr,prd,...] [--project KEY] [--dry-run] [DOCS_DIR]
#   --dirs     limit to these top-level subdirs (default: every subdir)
#   --project  YouTrack project key (default: $YOUTRACK_PROJECT or
#              .agents/config/story-tools.json next to DOCS_DIR)
#   --dry-run  print the article tree (titles + hierarchy + actions) without
#              touching YouTrack; needs no credentials
#   DOCS_DIR   default ./docs/development (the git-canonical zone)
#
# Directory articles are titled for humans: a README.md inside a directory
# IS that directory's article (its H1 = the title, its body = the landing
# content). Without a README, a built-in title map covers the standard
# taxonomy dirs (adr -> "Architecture Decision Records", ...), else the
# dir name is title-cased. docs/README.md does the same for the root.
#
# Always skipped: docs/stories/ (the yt-pull snapshot - publishing it
# would mirror YouTrack into YouTrack), docs/product/ (the
# generated mirror of the KB's Product Management zone), docs/outbox/
# (outbound artifacts, never knowledge-base content), non-.md files, and any path
# matching a glob line in DOCS_DIR/.yt-publish-ignore. README.md files
# are consumed as directory articles, never published as leaves.
#
# One-way, idempotent: DOCS_DIR/.yt-articles.json maps path -> article id
# (commit it). Articles carry a do-not-edit banner. The repo is canonical:
# a publish overwrites article CONTENT and re-asserts article POSITION -
# edits or moves made in YouTrack do not survive the next publish and are
# never copied back. To move a doc, git mv it and re-publish.
set -euo pipefail

DIRS=""; PROJECT="${YOUTRACK_PROJECT:-}"; DOCS_DIR="./docs/development"; DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dirs) DIRS="$2"; shift 2;;
    --project) PROJECT="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    *) DOCS_DIR="$1"; shift;;
  esac
done

if [[ -z "${YOUTRACK_URL:-}" ]]; then
  candidates=( )
  [[ -n "${YOUTRACK_ENV_FILE:-}" ]] && candidates+=("$YOUTRACK_ENV_FILE")
  conn="${YOUTRACK_CONNECTION:-${YOUTRACK_PROFILE:-}}"
  # no explicit connection: the project pointer names it
  if [[ -z "$conn" ]]; then
    for pf in "$DOCS_DIR/../.agents/config/story-tools.json" "$DOCS_DIR/../../.agents/config/story-tools.json" "$DOCS_DIR/../.agents/youtrack.json" "$DOCS_DIR/../../.agents/youtrack.json"; do
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
[[ "$DRY" != 1 && ( -z "$YOUTRACK_URL" || -z "$YOUTRACK_TOKEN" ) ]] && { echo "error: no YouTrack credentials found" >&2; exit 1; }

if [[ -z "$PROJECT" ]]; then
  for pf in "$DOCS_DIR/../.agents/config/story-tools.json" "$DOCS_DIR/../../.agents/config/story-tools.json" "$DOCS_DIR/../.agents/youtrack.json" "$DOCS_DIR/../../.agents/youtrack.json"; do
    [[ -f "$pf" ]] && { PROJECT=$(sed -nE 's/.*"project": *"([^"]+)".*/\1/p' "$pf" | head -1); break; }
  done
fi
[[ "$DRY" != 1 && -z "$PROJECT" ]] && { echo "error: no project key (--project, \$YOUTRACK_PROJECT, or .agents/config/story-tools.json)" >&2; exit 1; }

export YOUTRACK_URL YOUTRACK_TOKEN PROJECT DIRS DOCS_DIR DRY
python3 <<'EOF'
import fnmatch, json, os, re, sys, urllib.request, urllib.parse, datetime

URL = os.environ['YOUTRACK_URL'].rstrip('/')
TOKEN = os.environ['YOUTRACK_TOKEN']
PROJECT = os.environ['PROJECT']
ONLY = [d.strip() for d in os.environ['DIRS'].split(',') if d.strip()]
DOCS = os.environ['DOCS_DIR'].rstrip('/')
DRY = os.environ.get('DRY') == '1'
MAP_PATH = os.path.join(DOCS, '.yt-articles.json')
ALWAYS_SKIP = {'youtrack', 'outbox', 'product-management', 'product', 'stories', '_archive'}

# Human-readable fallback titles for directories without a README.md index.
DEFAULT_TITLES = {
    'adr': 'Architecture Decision Records',
    'prd': 'Product Requirements',
    'spec': 'Specifications',
    'design': 'Design & Accessibility',
    'mandates': 'Mandates & Compliance',
    'research': 'Research & Development',
    'reference': 'Reference',
    'guides': 'Guides',
    'qa': 'Quality Assurance',
    'vendors': 'Vendors',
    'prospects': 'Prospects',
    'regulations': 'Regulations',
    'out-of-scope': 'Out of Scope',
}

def h1(text):
    m = re.search(r'^#\s+(.+)$', text, re.M)
    return m.group(1).strip() if m else None

def dir_article(abspath, entry, rel):
    """Title + body for a directory article. A README.md index inside the
    directory IS the article: its H1 is the title, its body the content."""
    readme = os.path.join(abspath, 'README.md')
    if os.path.exists(readme):
        text = open(readme, encoding='utf-8').read()
        title = h1(text) or DEFAULT_TITLES.get(entry) or entry.replace('-', ' ').title()
        return title, text, f'docs/{rel}/README.md'
    title = DEFAULT_TITLES.get(entry) or entry.replace('-', ' ').title()
    return title, None, None

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

pid = None
if not DRY:
    projects = api(f'/api/admin/projects?fields=id,shortName&query={urllib.parse.quote(PROJECT)}')
    pid = next((p['id'] for p in projects if p.get('shortName') == PROJECT), None)
    if not pid:
        sys.exit(f'error: project {PROJECT} not found or not visible')

amap = json.load(open(MAP_PATH)) if os.path.exists(MAP_PATH) else {}
stamp = datetime.date.today().isoformat()

def upsert(key, summary, content, parent_id=None):
    aid = amap.get(key)
    if DRY:
        return aid or f'dry:{key}', ('updated' if aid else 'created')
    payload = {'summary': summary, 'content': content}
    if aid and exists(aid):
        # re-assert the canonical parent: the repo owns the hierarchy, so an
        # article someone moved in YouTrack snaps back on the next publish
        if parent_id:
            payload['parentArticle'] = {'id': parent_id}
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
            title, body, src = dir_article(full, entry, rel)
            if body is not None:
                banner = (f'> **Generated** from `{src}` ({stamp}) - the repo is canonical. '
                          'Do not edit this article; edit the file and re-publish.\n\n')
                content = banner + body
            else:
                content = f'Generated mirror of `docs/{rel}/` ({stamp}). Do not edit here.'
            dir_id, act = upsert(rel + '/', title, content, parent_id)
            sub = publish_dir(rel, dir_id)
            if sub == 0 and act == 'created':
                pass  # empty branch stays as a placeholder; harmless
            print(f'  {act}: {rel}/ -> "{title}"')
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

root_title, root_body = 'Product Development', None
root_readme = os.path.join(DOCS, 'README.md')
if os.path.exists(root_readme):
    text = open(root_readme, encoding='utf-8').read()
    root_title = h1(text) or root_title
    root_body = text
root_banner = (f'> **Generated** mirror of the repository `docs/` tree ({stamp}) - '
    'THE REPO IS CANONICAL. Do not edit these articles; edit the repo and re-publish.\n\n')
root_id, act = upsert('__root__', root_title, root_banner + (root_body or ''))
print(f'  {act}: "{root_title}" (root)')
total = publish_dir('', root_id)

# docs/README.md (one level above DOCS_DIR) is the documentation-system
# guide: published as a TOP-LEVEL article, sibling of the zone roots.
guide_path = os.path.join(os.path.dirname(DOCS) or '.', 'README.md')
if os.path.exists(guide_path):
    gtext = open(guide_path, encoding='utf-8').read()
    gtitle = h1(gtext) or 'How This Documentation Works'
    gbanner = (f'> **Generated** from `docs/README.md` ({stamp}) - the repo is canonical. '
               'Do not edit this article; edit the file and re-publish.\n\n')
    _, act = upsert('__guide__', gtitle, gbanner + gtext)
    print(f'  {act}: docs/README.md -> "{gtitle}" (top level)')

if not DRY:
    json.dump(dict(sorted(amap.items())), open(MAP_PATH, 'w'), indent=2)
else:
    print('\n(dry run - nothing sent to YouTrack, map not written)')
print(f"\nPublished {total} docs ({counts['created']} created, {counts['updated']} updated, "
      f"{counts['skipped']} ignored). Map: {MAP_PATH} (commit it).")
EOF
