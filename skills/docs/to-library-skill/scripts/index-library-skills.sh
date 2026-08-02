#!/usr/bin/env bash
# Index every library AI-skill bundled in this repo.
#
# Scans for *.ai-skill.md at the ecosystem-standard locations
# (META-INF/ai-skills/ for JVM/KMP, .ai-skills/ for NPM and SPM) and
# writes a generated map so agents working INSIDE the repo can see which
# modules ship a skill and what each is for. Consumers discover skills
# through their dependency folder; this is the same discovery for the
# monorepo itself.
#
# Usage: index-library-skills.sh [ROOT] [-o OUT]
#   ROOT   repo root to scan (default: .)
#   -o     output file (default: <ROOT>/docs/library-skills.md)
#
# The output is GENERATED - never hand-edit it. Point AGENTS.md at it
# once; re-run when modules are added, removed, or renamed.
set -uo pipefail

ROOT="."; OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) OUT="$2"; shift 2;;
    --help|-h) awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/,""); print}' "$0"; exit 0;;
    *) ROOT="$1"; shift;;
  esac
done
ROOT="${ROOT%/}"; [[ -d "$ROOT" ]] || { echo "error: no such directory: $ROOT" >&2; exit 1; }
OUT="${OUT:-$ROOT/docs/library-skills.md}"

command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }
export ROOT OUT
python3 <<'EOF'
import os, re, sys, datetime

ROOT = os.environ['ROOT']; OUT = os.environ['OUT']
SKIP = {'.git', 'node_modules', 'build', 'out', 'dist', '.gradle', '.idea',
        'DerivedData', 'Pods', '_to_delete', '_archive'}

found = []
for base, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if d not in SKIP]
    parent = os.path.basename(base)
    grandparent = os.path.basename(os.path.dirname(base))
    is_new = grandparent == 'skills' and 'SKILL.md' in files      # <holder>/skills/<n>/
    is_legacy = parent in ('ai-skills', '.ai-skills')             # pre-convention
    if is_new:
        # `.agents/skills/` and `META-INF/agents/skills/` are unambiguous.
        # A PLAIN `skills/` (mise, Vercel) only counts as a library skill when
        # it sits beside a package manifest - otherwise it is just a repo's
        # own skills directory (this repo has one).
        holder_dir = os.path.dirname(os.path.dirname(base))
        if os.path.basename(holder_dir) not in ('agents', '.agents'):
            MANIFESTS = {'package.json', 'build.gradle', 'build.gradle.kts', 'pom.xml',
                         'Cargo.toml', 'go.mod', 'pyproject.toml', 'setup.py',
                         'Package.swift', 'composer.json'}
            sibs = set(os.listdir(holder_dir)) if os.path.isdir(holder_dir) else set()
            if not (sibs & MANIFESTS) and not any(
                    x.endswith(('.podspec', '.csproj')) for x in sibs):
                continue
    if not (is_new or is_legacy):
        continue
    for f in sorted(files):
        if not (f == 'SKILL.md' if is_new else f.endswith('.ai-skill.md')):
            continue
        path = os.path.join(base, f)
        rel = os.path.relpath(path, ROOT)
        text = ''
        try:
            with open(path, encoding='utf-8') as fh:
                text = fh.read(4000)
        except OSError:
            pass
        def field(name):
            m = re.search(rf'^{name}: *"?([^"\n]+)"?$', text, re.M)
            return (m.group(1).strip() if m else '')
        artifact = (field('library') or field('skill-id') or field('name')
                    or (parent if is_new else f[:-len('.ai-skill.md')]))
        # module root: strip the standard suffix from the path
        mod = rel
        holder = os.path.dirname(os.path.dirname(rel)) if is_new else os.path.dirname(rel)
        for suffix in ('/src/commonMain/resources/META-INF/agents/skills',
                       '/src/commonMain/resources/META-INF/skills',
                       '/resources/META-INF/skills', '/META-INF/skills',
                       '/.agents/skills', '/agents/skills', '/skills',
                       '/src/main/resources/META-INF/agents/skills',
                       '/resources/META-INF/agents/skills',
                       '/META-INF/agents/skills', '/.agents/skills',
                       '/src/commonMain/resources/META-INF/ai-skills',
                       '/src/main/resources/META-INF/ai-skills',
                       '/resources/META-INF/ai-skills',
                       '/META-INF/ai-skills', '/.ai-skills'):
            i = holder.find(suffix)
            if i >= 0:
                mod = holder[:i] or '.'
                break
        else:
            mod = holder
        # one-line purpose: description/summary field, else first prose line
        purpose = field('description') or field('summary')
        if not purpose:
            body = re.sub(r'^---.*?---', '', text, count=1, flags=re.S)
            for line in body.splitlines():
                line = line.strip()
                if line and not line.startswith('#'):
                    purpose = line; break
        purpose = re.sub(r'\s+', ' ', purpose)[:140] or '_(no description - add one to this skill)_'
        home = field('skill-url') or field('repository')
        if home.startswith('<'): home = ''
        found.append((mod, artifact, purpose, rel, home))

found.sort()
os.makedirs(os.path.dirname(OUT) or '.', exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as f:
    f.write(f"# Library AI-skills in this repo ({datetime.date.today()})\n\n")
    f.write("<!-- GENERATED by to-library-skill/scripts/index-library-skills.sh -"
            " do not edit. Re-run when modules change. -->\n\n")
    if not found:
        f.write("No bundled library skills found yet. A published module gets one\n"
                "via the scaffolds in the to-library-skill skill.\n")
    else:
        f.write("Each module below ships an AI-skill inside its published artifact.\n"
                "Working on code that CONSUMES one of these modules? Read its skill\n"
                "first - it is the module's own account of how it should be used.\n\n")
        f.write("| Module | Artifact | Use it when | Skill file |\n|---|---|---|---|\n")
        for mod, artifact, purpose, rel, home in found:
            f.write(f"| `{mod}` | {artifact} | {purpose} | `{rel}` |\n")
        f.write("\nConsuming projects discover these through their dependency "
                "folder (`.agents/skills/` at the package root, `META-INF/agents/"
                "skills/` inside a jar); this index is the same discovery from "
                "inside the repo.\n")
print(f"Wrote {OUT} ({len(found)} bundled skill{'s' if len(found) != 1 else ''})")
EOF
