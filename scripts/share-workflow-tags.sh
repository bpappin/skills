#!/usr/bin/env bash
# One-off: assert read+update sharing (All Users) on every workflow tag,
# reporting each tag's owner and result. Safe to re-run.
set -euo pipefail
source "$HOME/.agents/story-tools/connections/${1:-evolyn}.env"
export YOUTRACK_URL YOUTRACK_TOKEN
python3 <<'EOF'
import json, os, urllib.request, urllib.error
URL = os.environ['YOUTRACK_URL'].rstrip('/'); TOK = os.environ['YOUTRACK_TOKEN']
def api(p, payload=None):
    req = urllib.request.Request(URL + p,
        data=json.dumps(payload).encode() if payload else None,
        headers={'Authorization': 'Bearer ' + TOK, 'Content-Type': 'application/json'})
    b = urllib.request.urlopen(req).read()
    return json.loads(b) if b else None

me = api('/api/users/me?fields=login')['login']
gid = next((g['id'] for g in api('/api/groups?fields=id,name&$top=100')
            if g.get('name') == 'All Users'), None)
if not gid:
    raise SystemExit('error: no "All Users" group visible to this token')
want = {'needs-triage','needs-info','ready-for-agent','ready-for-human',
        'wontfix','triaged','discovered','needs-gherkin'}
share = {'permittedGroups': [{'id': gid}]}
seen = set()
for t in api('/api/tags?fields=id,name,owner(login)&$top=500'):
    if t['name'].lower() not in want: continue
    seen.add(t['name'].lower())
    owner = (t.get('owner') or {}).get('login', '?')
    try:
        api(f"/api/tags/{t['id']}?fields=id",
            {'readSharingSettings': share, 'updateSharingSettings': share})
        print(f"  ok: {t['name']:<16} owner={owner}  read+update -> All Users")
    except urllib.error.HTTPError as e:
        print(f"FAIL: {t['name']:<16} owner={owner}  HTTP {e.code} - set 'Updatable by' in the UI (owner-only)")
missing = want - seen
print(f"token user: {me}")
if missing:
    print("not visible to this token at all:", ', '.join(sorted(missing)))
EOF
