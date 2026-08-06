#!/usr/bin/env bash
# Migrate v1 library skills to the v2 layout.
#
# v1 put a library's skill in a FLAT FILE:
#   <pkg>/.ai-skills/<id>.ai-skill.md
#   <...>/META-INF/ai-skills/<id>.ai-skill.md
# v2 puts it in a standard Agent Skill DIRECTORY:
#   <pkg>/.agents/skills/<name>/SKILL.md
#   <...>/META-INF/agents/skills/<name>/SKILL.md
#
# This finds every v1 file in a repo and moves it, rewriting the
# frontmatter to the v2 shape. It also normalises two near-miss JVM
# paths we shipped before settling (`META-INF/skills/`,
# `META-INF/.agents/skills/`) onto the canonical one, so the
# `Agent-Skills` manifest attribute is correct for every module.
#
# Usage: migrate-library-skills.sh [ROOT] [--apply] [--quiet]
#   ROOT      repo root to scan (default: .)
#   --apply   actually move files. WITHOUT IT NOTHING IS WRITTEN -
#             the default is a report of what would happen.
#   --quiet   suppress the JVM manifest reminder
#
# Uses `git mv` for tracked files so history follows. NEVER commits -
# review the result and commit it yourself.
#
# Exit: 0 clean (or nothing to migrate), 1 error, 2 needs your attention
# (a collision, or a skill with no description).
set -uo pipefail

ROOT="."; APPLY=0; QUIET=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    --quiet) QUIET=1; shift;;
    --help|-h) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0;;
    -*) echo "unknown option: $1" >&2; exit 1;;
    *) ROOT="$1"; shift;;
  esac
done
ROOT="${ROOT%/}"; [[ -d "$ROOT" ]] || { echo "error: no such directory: $ROOT" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }

export ROOT APPLY QUIET
python3 <<'PYEOF'
import os, re, sys, subprocess

ROOT = os.environ['ROOT']
APPLY = os.environ['APPLY'] == '1'
QUIET = os.environ['QUIET'] == '1'
SKIP = {'.git', 'node_modules', 'build', 'out', 'dist', '.gradle', '.idea',
        'DerivedData', 'Pods', '_to_delete', '_archive', 'target',
        '.build', 'vendor', '__pycache__'}

JVM_MARKERS = ('build.gradle', 'build.gradle.kts', 'pom.xml', 'settings.gradle',
               'settings.gradle.kts')
CANON_JVM = os.path.join('META-INF', 'agents', 'skills')

# ---------------------------------------------------------------- helpers

def sanitize(name):
    """Match what a fresh scaffold would name it: npm scopes collapse to
    a dash (`@acme/http` -> `acme-http`), a maven coordinate keeps dotted
    form (`one.aughtone:types` -> `one.aughtone.types`)."""
    name = re.sub(r'^@', '', name).strip()
    if ':' in name and '/' not in name:
        return name.replace(':', '.')
    return name.replace('/', '-').replace(':', '-')

def split_frontmatter(text):
    m = re.match(r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n?', text, re.S)
    if not m:
        return None, text
    return m.group(1), text[m.end():]

def fm_get(block, key):
    if block is None:
        return ''
    m = re.search(rf'^{re.escape(key)}: *"?([^"\n]*?)"?[ \t]*$', block, re.M)
    return m.group(1).strip() if m else ''

def git_tracked(path):
    try:
        r = subprocess.run(['git', '-C', os.path.dirname(path) or '.',
                            'ls-files', '--error-unmatch', os.path.basename(path)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return r.returncode == 0
    except OSError:
        return False

def in_git_repo(path):
    try:
        r = subprocess.run(['git', '-C', path, 'rev-parse', '--is-inside-work-tree'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return r.returncode == 0
    except OSError:
        return False

GIT = in_git_repo(ROOT)

def is_jvm_module(d):
    try:
        return any(f in JVM_MARKERS for f in os.listdir(d))
    except OSError:
        return False

def jvm_resource_root(module):
    """Where a JVM/KMP module's packaged resources live, best effort."""
    for cand in ('src/commonMain/resources', 'src/main/resources',
                 'src/jvmMain/resources', 'resources'):
        if os.path.isdir(os.path.join(module, cand)):
            return os.path.join(module, cand)
    return os.path.join(module, 'src/commonMain/resources')

def strip_metainf(path):
    """Walk up out of a META-INF nesting to the thing that holds it."""
    while os.path.basename(path) in ('META-INF', 'agents', '.agents', 'skills',
                                     'ai-skills', '.ai-skills', 'resources'):
        path = os.path.dirname(path)
    return path

# ---------------------------------------------------------------- discovery

jobs = []          # (kind, src, dst, name, note)
seen_targets = {}

for base, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in SKIP]
    parent = os.path.basename(base)
    grandparent = os.path.basename(os.path.dirname(base))

    # --- v1 flat files: <holder>/{.,}ai-skills/<id>.ai-skill.md ------------
    if parent in ('ai-skills', '.ai-skills'):
        holder = os.path.dirname(base)               # <pkg> or <...>/META-INF
        under_metainf = os.path.basename(holder) == 'META-INF'
        for f in sorted(files):
            if not f.endswith('.ai-skill.md'):
                continue
            src = os.path.join(base, f)
            stem = f[:-len('.ai-skill.md')]
            try:
                text = open(src, encoding='utf-8').read()
            except OSError as e:
                print(f"error: cannot read {src}: {e}", file=sys.stderr)
                continue
            fm, _ = split_frontmatter(text)
            # The v1 FILENAME is the identity a v1 scaffold assigned, so it
            # beats the coordinate fields - `one.aughtone.types.ai-skill.md`
            # is exactly what a v2 scaffold would have called the directory.
            GENERIC = {'skill', 'index', 'ai-skill', 'readme', 'main'}
            cands = [fm_get(fm, 'name'),
                     '' if stem.lower() in GENERIC else stem,
                     fm_get(fm, 'library'), fm_get(fm, 'skill-id'), stem]
            raw = next((c for c in cands if c and not c.startswith('<')), stem)
            name = sanitize(raw) or sanitize(stem)
            note = ''
            if under_metainf:
                dst = os.path.join(os.path.dirname(holder), CANON_JVM, name, 'SKILL.md')
            else:
                pkg = holder
                if is_jvm_module(pkg):
                    # v1 at a JVM module root was never inside the artifact.
                    dst = os.path.join(jvm_resource_root(pkg), CANON_JVM, name, 'SKILL.md')
                    note = 'was outside resources - never shipped in the artifact'
                else:
                    dst = os.path.join(pkg, '.agents', 'skills', name, 'SKILL.md')
            jobs.append(['flat', src, dst, name, note])
        continue

    # --- near-miss JVM dirs: META-INF/skills/, META-INF/.agents/skills/ ----
    if grandparent == 'skills' and 'SKILL.md' in files:
        holder = os.path.dirname(os.path.dirname(base))      # the dir holding skills/
        hb = os.path.basename(holder)
        canon_parent = os.path.dirname(base)                 # .../skills
        if hb == 'META-INF':
            dst_dir = os.path.join(holder, 'agents', 'skills', parent)
        elif hb == '.agents' and os.path.basename(os.path.dirname(holder)) == 'META-INF':
            dst_dir = os.path.join(os.path.dirname(holder), 'agents', 'skills', parent)
        else:
            continue                                          # already canonical
        src = os.path.join(base, 'SKILL.md')
        dst = os.path.join(dst_dir, 'SKILL.md')
        if os.path.abspath(src) == os.path.abspath(dst):
            continue
        jobs.append(['jvmpath', src, dst, parent, 'JVM path normalised'])

if not jobs:
    print("No v1 library skills found - nothing to migrate.")
    sys.exit(0)

# ---------------------------------------------------------------- planning

conflicts, warnings, moves = [], [], []
for kind, src, dst, name, note in jobs:
    if os.path.exists(dst):
        conflicts.append((src, dst, 'a v2 skill already exists there'))
        continue
    prior = seen_targets.get(os.path.abspath(dst))
    if prior:
        conflicts.append((src, dst, f'collides with {os.path.relpath(prior, ROOT)}'))
        continue
    seen_targets[os.path.abspath(dst)] = src
    moves.append((kind, src, dst, name, note))

# ---------------------------------------------------------------- rewriting

def rewrite(text, name, src, dst):
    """v2 frontmatter: a `name` the spec requires, and a skill-url that
    still points at itself after the move."""
    fm, body = split_frontmatter(text)
    notes = []
    if fm is None:
        fm = (f'name: {name}\n'
              'description: <one line - what this library is for, and when a caller '
              'should reach for it instead of writing their own>')
        notes.append('no frontmatter - added a stub, fill in the description')
        return f'---\n{fm}\n---\n\n{text.lstrip()}', notes

    lines = fm.split('\n')
    keys = {}
    for i, ln in enumerate(lines):
        m = re.match(r'^([A-Za-z0-9_-]+): *(.*)$', ln)
        if m:
            keys.setdefault(m.group(1), i)

    if 'name' in keys:
        lines[keys['name']] = f'name: {name}'
    else:
        lines.insert(0, f'name: {name}')
        keys = {k: (v + 1) for k, v in keys.items()}

    if 'skill-id' in keys:            # v1 spelling, superseded by name
        lines[keys['skill-id']] = None

    desc = fm_get(fm, 'description')
    if not desc or desc.startswith('<'):
        notes.append('no description - the index cannot describe it until you add one')

    # keep skill-url pointing at this file, wherever it just moved to
    if 'skill-url' in keys:
        url = fm_get(fm, 'skill-url')
        old_rel = os.path.relpath(src, ROOT).replace(os.sep, '/')
        new_rel = os.path.relpath(dst, ROOT).replace(os.sep, '/')
        if url and not url.startswith('<'):
            if old_rel in url:
                lines[keys['skill-url']] = f'skill-url: {url.replace(old_rel, new_rel)}'
                notes.append('skill-url repointed at the new path')
            else:
                notes.append('skill-url does not match the old path - check it by hand')

    lines = [l for l in lines if l is not None]
    return '---\n' + '\n'.join(lines) + '\n---\n' + body, notes

# ---------------------------------------------------------------- execute

def move(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if GIT and git_tracked(src):
        r = subprocess.run(['git', '-C', ROOT, 'mv', os.path.relpath(src, ROOT),
                            os.path.relpath(dst, ROOT)],
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if r.returncode == 0:
            return 'git mv'
    os.replace(src, dst)
    return 'mv'

def prune_empty(d, stop):
    d = os.path.abspath(d); stop = os.path.abspath(stop)
    while d.startswith(stop) and d != stop:
        try:
            if os.listdir(d):
                return
            os.rmdir(d)
        except OSError:
            return
        d = os.path.dirname(d)

done, jvm_touched = [], False
for kind, src, dst, name, note in moves:
    try:
        text = open(src, encoding='utf-8').read()
    except OSError as e:
        print(f"error: cannot read {src}: {e}", file=sys.stderr)
        continue
    new_text, notes = rewrite(text, name, src, dst)
    if CANON_JVM.replace(os.sep, '/') in dst.replace(os.sep, '/'):
        jvm_touched = True
    if APPLY:
        how = move(src, dst)
        with open(dst, 'w', encoding='utf-8') as fh:
            fh.write(new_text)
        os.chmod(dst, 0o644)          # v1 scaffolds marked these executable
        prune_empty(os.path.dirname(src), ROOT)
    else:
        how = 'would move'
    done.append((src, dst, name, how, ([note] if note else []) + notes))

# ---------------------------------------------------------------- report

rel = lambda p: os.path.relpath(p, ROOT)
head = "Migrated" if APPLY else "Would migrate"
print(f"\n{head} {len(done)} v1 skill{'s' if len(done) != 1 else ''}:\n")
for src, dst, name, how, notes in done:
    print(f"  {rel(src)}\n    -> {rel(dst)}")
    for n in notes:
        print(f"       ! {n}")
print()

if conflicts:
    print(f"{len(conflicts)} left in place - resolve by hand:\n")
    for src, dst, why in conflicts:
        print(f"  {rel(src)}\n    x {why}: {rel(dst)}")
    print("\n  Two skills for one module means one of them is stale. Pick the")
    print("  one you want, delete the other, then re-run.\n")

if jvm_touched and not QUIET:
    print("JVM modules changed. Announce the skills in the jar manifest so")
    print("consumers do not have to scan the archive:\n")
    print('  tasks.jar { manifest { attributes("Agent-Skills" to '
          '"META-INF/agents/skills/") } }\n')
    print("  The path in that attribute must match where the skills actually")
    print("  are - a declared path that holds nothing makes them invisible.\n")

if APPLY:
    print("Next: re-run index-library-skills.sh, then review and commit.")
else:
    print("Nothing was written. Re-run with --apply to do it.")

sys.exit(2 if conflicts or any(any('no description' in n for n in notes)
                               for *_, notes in done) else 0)
PYEOF
