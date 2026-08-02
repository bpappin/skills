#!/usr/bin/env bash
# Harvest library AI-skills from this project's dependencies.
#
# Ecosystem-agnostic. Two kinds of source, auto-detected from the
# project's own markers:
#
#   UNPACKED (node_modules, Pods, .build/checkouts, site-packages,
#   Go module cache, Cargo registry src, extracted NuGet) - a plain
#   directory walk. Everything present is genuinely installed, so
#   TRANSITIVE dependencies come free.
#
#   ARCHIVED (JVM: jars in the Gradle/Maven cache) - the only common
#   ecosystem that hides the file the standard expects agents to find.
#   Two filters keep it cheap: the cache path encodes coordinates, so
#   candidates are identified without opening a jar; and checking one
#   only LISTS its packaged entries (a jar is a zip - the entry list is
#   in the central directory), so nothing is unpacked to answer "does
#   this ship a skill?". Bodies are read only from jars that carry one.
#
# Usage: harvest-dependency-skills.sh [ROOT] [options]
#   ROOT            project root (default: .)
#   --source DIR    extra place to look, unpacked or archive (repeatable)
#   --all           JVM only: scan every cached jar instead of just the
#                   declared ones - slower, but catches transitives
#   --index-only    just index; don't save copies of the skill bodies
#   -o FILE         index file (default: <ROOT>/docs/library-skills.md)
#   --help
#
# Appends a "From dependencies" section to the index written by
# index-library-skills.sh (run that first; this preserves its content).
# Bodies are copied to docs/libraries/ with a provenance header.
set -uo pipefail

ROOT="."; OUT=""; ALL=0; EXTRACT=1; SOURCES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source|--cache) SOURCES+=("$2"); shift 2;;
    --all) ALL=1; shift;;
    --index-only) EXTRACT=0; shift;;
    -o) OUT="$2"; shift 2;;
    --help|-h) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0;;
    *) ROOT="$1"; shift;;
  esac
done
ROOT="${ROOT%/}"; [[ -d "$ROOT" ]] || { echo "error: no such directory: $ROOT" >&2; exit 1; }
OUT="${OUT:-$ROOT/docs/library-skills.md}"

command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }
export ROOT OUT ALL EXTRACT
: > "${TMPDIR:-/tmp}/.libskill-src.$$"
[[ ${#SOURCES[@]} -gt 0 ]] && printf '%s\n' "${SOURCES[@]}" > "${TMPDIR:-/tmp}/.libskill-src.$$"
export SRC_LIST="${TMPDIR:-/tmp}/.libskill-src.$$"
trap 'rm -f "$SRC_LIST"' EXIT

python3 <<'EOF'
import os, re, json, zipfile, datetime

ROOT = os.environ['ROOT']; OUT = os.environ['OUT']
ALL = os.environ['ALL'] == '1'; EXTRACT = os.environ['EXTRACT'] == '1'
HOME = os.path.expanduser('~')
extra = [l.strip() for l in open(os.environ['SRC_LIST']) if l.strip()]
PRUNE = {'.git', 'node_modules', 'build', 'out', 'dist', '.gradle', '_to_delete',
         '.venv', 'venv', 'Pods', '.build'}

# ---- which ecosystems is this project actually in? -------------------------
markers = set()
for base, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in PRUNE]
    for f in files:
        markers.add(f)
        if f.endswith(('.csproj', '.sln')):
            markers.add('*.csproj')

def has(*names):
    return any(n in markers for n in names)

unpacked, archives, ecos = [], [], []
def add_dirs(label, paths):
    real = [p for p in paths if os.path.isdir(p)]
    if real:
        ecos.append(label); unpacked.extend(real)

if has('package.json'):
    add_dirs('npm', [os.path.join(ROOT, 'node_modules')])
if has('Package.swift', 'Podfile'):
    add_dirs('swift', [os.path.join(ROOT, '.build', 'checkouts'),
                       os.path.join(ROOT, 'Pods')])
if has('pyproject.toml', 'requirements.txt', 'setup.py'):
    cands = []
    for venv in ('.venv', 'venv', 'env'):
        lib = os.path.join(ROOT, venv, 'lib')
        if os.path.isdir(lib):
            cands += [os.path.join(lib, py, 'site-packages') for py in os.listdir(lib)]
    add_dirs('python', cands)
if has('go.mod'):
    gp = os.environ.get('GOPATH') or os.path.join(HOME, 'go')
    add_dirs('go', [os.path.join(gp, 'pkg', 'mod')])
if has('Cargo.toml'):
    add_dirs('cargo', [os.path.join(HOME, '.cargo', 'registry', 'src')])
if has('*.csproj'):
    add_dirs('nuget', [os.path.join(HOME, '.nuget', 'packages')])
if has('build.gradle', 'build.gradle.kts', 'pom.xml', 'libs.versions.toml'):
    jvm = [p for p in (os.path.join(HOME, '.gradle', 'caches', 'modules-2', 'files-2.1'),
                       os.path.join(HOME, '.m2', 'repository')) if os.path.isdir(p)]
    if jvm:
        ecos.append('jvm'); archives.extend(jvm)

for p in extra:                      # user-supplied: guess by shape
    if not os.path.isdir(p):
        continue
    if 'files-2.1' in p or p.rstrip('/').endswith('repository'):
        archives.append(p); 'jvm' in ecos or ecos.append('jvm')
    else:
        unpacked.append(p); 'custom' in ecos or ecos.append('custom')

# ---- JVM only: what does the project declare? ------------------------------
declared_artifacts = set()
if archives and not ALL:
    BUILD = ('build.gradle', 'build.gradle.kts', 'settings.gradle',
             'settings.gradle.kts', 'pom.xml', 'libs.versions.toml')
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in PRUNE]
        for f in files:
            if f in BUILD:
                try:
                    t = open(os.path.join(base, f), encoding='utf-8', errors='ignore').read()
                except OSError:
                    continue
                for m in re.finditer(r'["\']([A-Za-z0-9_.\-]+):([A-Za-z0-9_.\-]+)(?::|["\'])', t):
                    declared_artifacts.add(m.group(2))
                for m in re.finditer(r'name\s*=\s*"([^"]+)"', t):
                    declared_artifacts.add(m.group(1))

# ---- shared parsing --------------------------------------------------------
def purpose_of(text):
    def field(n):
        m = re.search(rf'^{n}: *"?([^"\n]+)"?$', text, re.M)
        return (m.group(1).strip() if m else '')
    p = field('description') or field('summary')
    if not p:
        body = re.sub(r'^---.*?---', '', text, count=1, flags=re.S)
        for line in body.splitlines():
            line = line.strip()
            if line and not line.startswith('#'):
                p = line; break
    return re.sub(r'\s+', ' ', p)[:140] or '_(no description)_'

def home_of(text):
    def field(n):
        m = re.search(rf'^{n}: *"?([^"\n]+)"?$', text, re.M)
        v = (m.group(1).strip() if m else '')
        return '' if v.startswith('<') else v      # unfilled scaffold placeholder
    return field('skill-url') or field('repository')

def manifest_paths(z):
    """MANIFEST.MF Agent-Skills attribute -> declared skill roots.

    The proposal under test: a jar ANNOUNCES its skills in the manifest
    instead of making consumers pattern-match the whole archive.
      Agent-Skills: META-INF/agents/skills/
    Comma-separated for several roots. Manifest lines wrap at 72 bytes
    with a leading-space continuation, so unfold before matching."""
    try:
        raw = z.read('META-INF/MANIFEST.MF').decode('utf-8', 'replace')
    except (KeyError, OSError):
        return []
    unfolded = re.sub(r'\r?\n ', '', raw)
    m = re.search(r'^Agent-Skills: *(.+)$', unfolded, re.M | re.I)
    if not m:
        return []
    return [p.strip().rstrip('/') + '/' for p in m.group(1).split(',') if p.strip()]

def skill_id(text, filename, fallback=''):
    for key in ('library', 'skill-id', 'name'):
        m = re.search(rf'^{key}: *"?([^"\n]+)"?$', text, re.M)
        if m:
            return m.group(1).strip()
    if filename.endswith('.ai-skill.md'):
        return filename[:-len('.ai-skill.md')]
    return fallback

found, seen, scanned, opened, manifest_hits = [], set(), 0, 0, 0

# ---- unpacked dependency trees --------------------------------------------
for rootdir in unpacked:
    for base, dirs, files in os.walk(rootdir):
        dirs[:] = [d for d in dirs if d != '.git']
        parent = os.path.basename(base)
        is_new = os.path.basename(os.path.dirname(base)) == 'skills' and 'SKILL.md' in files
        if not (is_new or parent in ('ai-skills', '.ai-skills')):
            continue
        pkg = os.path.dirname(os.path.dirname(base)) if is_new else os.path.dirname(base)
        while os.path.basename(pkg) in ('META-INF', 'agents', '.agents', 'resources'):
            pkg = os.path.dirname(pkg)   # <pkg>/.agents/skills/, <pkg>/skills/,
                                         # and the META-INF nestings all land here
        version = ''
        pj = os.path.join(pkg, 'package.json')
        if os.path.isfile(pj):
            try:
                version = str(json.load(open(pj, encoding='utf-8')).get('version', '') or '')
            except Exception:
                pass
        if not version:                       # cargo/go/nuget encode it in the path
            m = re.search(r'[@\-](\d+\.\d+[\w.\-+]*)$', os.path.basename(pkg))
            version = m.group(1) if m else ''
        for f in sorted(files):
            if not (f == 'SKILL.md' if is_new else f.endswith('.ai-skill.md')):
                continue
            scanned += 1
            try:
                text = open(os.path.join(base, f), encoding='utf-8', errors='replace').read()
            except OSError:
                continue
            sid = skill_id(text, f, parent)
            if sid in seen:
                continue
            seen.add(sid)
            found.append((sid, version, purpose_of(text),
                          os.path.relpath(os.path.join(base, f), ROOT), text,
                          home_of(text)))

# ---- archived (JVM jars) ---------------------------------------------------
def coords(p):
    parts = p.split(os.sep)
    if 'files-2.1' in parts:
        i = parts.index('files-2.1')
        return tuple(parts[i+1:i+4]) if len(parts) >= i + 6 else None
    if 'repository' in parts:
        rest = parts[parts.index('repository')+1:-1]
        if len(rest) >= 3:
            return '.'.join(rest[:-2]), rest[-2], rest[-1]
    return None

for cache in archives:
    for base, dirs, files in os.walk(cache):
        for f in files:
            if not f.endswith('.jar') or f.endswith(('-sources.jar', '-javadoc.jar')):
                continue
            path = os.path.join(base, f); scanned += 1
            c = coords(path)
            if not c:
                continue
            group, artifact, version = c
            if f'{group}.{artifact}' in seen or artifact in seen:
                continue
            if not ALL and artifact not in declared_artifacts:
                continue
            opened += 1
            try:
                with zipfile.ZipFile(path) as z:
                    declared = manifest_paths(z)
                    if declared:
                        manifest_hits += 1
                        entries = [n for n in z.namelist()
                                   if n.endswith('/SKILL.md')
                                   and any(n.startswith(d) for d in declared)]
                    else:
                        entries = [n for n in z.namelist()
                                   if (n.endswith('/SKILL.md') and n.startswith(
                                       ('META-INF/agents/skills/', 'META-INF/skills/',
                                        'META-INF/.agents/skills/')))
                                   or (n.startswith('META-INF/ai-skills/')
                                       and n.endswith('.ai-skill.md'))]
                    for n in entries:
                        try:
                            text = z.read(n).decode('utf-8', 'replace')
                        except Exception:
                            continue
                        sid = (skill_id(text, os.path.basename(n), n.split('/')[-2])
                               or f'{group}.{artifact}')
                        if sid in seen:
                            continue
                        seen.add(sid)
                        found.append((sid, version, purpose_of(text),
                                      f'{os.path.basename(path)}!/{n}', text,
                                      home_of(text)))
            except (zipfile.BadZipFile, OSError):
                continue

# ---- save copies where agents will find them ------------------------------
copies = {}
if EXTRACT and found:
    dest = os.path.join(ROOT, 'docs', 'libraries')
    os.makedirs(dest, exist_ok=True)
    keep = set()
    for sid, version, purpose, origin, text, home in found:
        # skill-ids carry ecosystem punctuation (@scope/pkg, group:artifact) -
        # flatten to a safe filename, keep the real id in the index
        safe = re.sub(r'[^A-Za-z0-9._-]+', '-', sid.lstrip('@')).strip('-.') or 'unnamed'
        name = os.path.join(safe, 'SKILL.md'); keep.add(safe)
        os.makedirs(os.path.join(dest, safe), exist_ok=True)
        header = (f"<!-- COPIED from {sid}{' ' + version if version else ''} "
                  f"({origin}) by to-library-skill/scripts/harvest-dependency-skills.sh "
                  f"on {datetime.date.today()}. Do not edit - re-run to refresh. This is "
                  f"the library's own document and remains under ITS license, not this "
                  f"repo's."
                  + (f" Current version: {home}" if home else "") + " -->\n\n")
        with open(os.path.join(dest, name), 'w', encoding='utf-8') as fh:
            fh.write(header + text)
        copies[sid] = os.path.relpath(os.path.join(dest, name), ROOT)
    import shutil
    for stale in os.listdir(dest):
        full = os.path.join(dest, stale)
        if stale in keep:
            continue
        if os.path.isdir(full):
            shutil.rmtree(full)
        elif stale.endswith('.ai-skill.md'):      # copies from the old layout
            os.remove(full)

# ---- append the section to the index ---------------------------------------
MARK = '## From dependencies'
if os.path.isfile(OUT):
    head = open(OUT, encoding='utf-8').read().split(MARK)[0].rstrip() + '\n'
else:
    head = (f"# Library AI-skills in this repo ({datetime.date.today()})\n\n"
            "<!-- GENERATED - do not edit. -->\n")

found.sort()
os.makedirs(os.path.dirname(OUT) or '.', exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as f:
    f.write(head)
    f.write(f"\n{MARK}\n\n<!-- GENERATED by to-library-skill/scripts/"
            "harvest-dependency-skills.sh - do not edit. Re-run when dependencies"
            " change. -->\n\n")
    if not found:
        f.write("No dependency ships an AI-skill yet"
                f"{' (' + ', '.join(ecos) + ' checked)' if ecos else ''}.\n")
    else:
        f.write("These libraries ship their own AI-skill. Read one before writing\n"
                "code against that library - it is the library's own account of how\n"
                "it should be used.\n\n")
        f.write("| Library | Version | Use it when | Read it |\n|---|---|---|---|\n")
        for sid, version, purpose, origin, _, home in found:
            where = f"`{copies[sid]}`" if sid in copies else f"`{origin}`"
            if home:
                where += f" ([current]({home}))"
            f.write(f"| `{sid}` | {version or '-'} | {purpose} | {where} |\n")
        if any(h for *_, h in found):
            f.write("\nA `current` link means that library publishes its skill at a"
                    " known URL - the copy here matches the version you actually"
                    " depend on, so prefer it; fetch the current one only when you"
                    " are upgrading or nothing is bundled.\n")
        if copies:
            f.write("\nCopies in `docs/libraries/` are GENERATED from the dependencies -"
                    " do not edit them, and note each remains under its own library's"
                    " license.\n")

print(f"Ecosystems: {', '.join(ecos) or 'none detected'}. "
      f"Checked {scanned} candidate(s), opened {opened} jar(s), found {len(found)} skill(s) -> {OUT}")
if manifest_hits:
    print(f"  {manifest_hits} jar(s) DECLARED their skills via the MANIFEST.MF "
          "Agent-Skills attribute (no pattern scan needed)")
if archives and not ALL:
    print("  note: JVM transitive dependencies are not matched - re-run with --all to include them")
EOF
