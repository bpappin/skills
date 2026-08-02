# Attribution

This repository contains skills authored here, and skills derived from
other people's work. All are MIT licensed; the copyright notices below
travel with them as MIT requires.

## Upstream sources

- **[mattpocock/skills](https://github.com/mattpocock/skills)** — MIT,
  © 2026 Matt Pocock. This suite was originally set up by borrowing
  heavily from that repo. Skills that remain close to the original name
  him as author (`source:`); skills that have since been rewritten for
  the tracker workflow carry `derived-from: ... - heavily modified` and
  are authored here.
- **[JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman)** —
  MIT, © 2026 Julius Brussee. **Not vendored here.** See "External
  skills" below.

## External skills — used, not vendored

Independent skills that stand on their own. This repo does not carry a
copy and the installer never installs them: take the current version
from upstream, so it stays current and stays theirs.

| Skill | Upstream | Install |
|---|---|---|
| caveman | [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) (MIT, © 2026 Julius Brussee) | `npx skills add JuliusBrussee/caveman`, or copy `skills/caveman/` into `~/.claude/skills/` |

Vendoring one of these would mean freezing someone else's work at a
version we then have to maintain. Don't.

## This repository

- **[bpappin/skills](https://github.com/bpappin/skills)** — MIT,
  © 2026 Brill Pappin. Everything without a `source:` or `derived-from:`
  line in its frontmatter.

Per-skill provenance lives in each `SKILL.md` frontmatter. When adding a
skill from elsewhere, record it there and here — and never stamp it with
this repo's authorship.
