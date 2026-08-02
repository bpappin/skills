# Install guide

The short version is in the [README](../README.md). This is everything
else.

## The one-liner

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/bpappin/skills/main/bootstrap.sh)"
```

Clones the suite to `~/.agents/story-tools/src` and runs the wizard. That
clone is where projects get their skills from, so it stays put — re-run
the same line any time to update it.

**Why not `curl ... | bash`?** The wizard is interactive. Piping makes
stdin the script itself, so every prompt reads EOF and the whole thing
skips through with defaults. `bash -c "$(...)"` keeps your terminal on
stdin. The bootstrap detects the piped form and refuses rather than
letting it fail quietly.

## Without the one-liner

Reading before running is reasonable, and plenty of organisations ban
piped installers outright:

```bash
git clone https://github.com/bpappin/skills.git ~/.agents/story-tools/src
~/.agents/story-tools/src/scripts/install.sh
```

Any clone works — `~/Workspace/skills`, wherever. Whichever one you run
`scripts/install.sh` from becomes the source that projects install from.

Forked it? `STORY_TOOLS_REPO`, `STORY_TOOLS_BRANCH` and `STORY_TOOLS_SRC`
override the defaults.

## Requirements

`bash`, `git`, `curl`, and `python3` for the sync and index scripts.
macOS, Linux, WSL, and Git Bash on Windows. There is no PowerShell
installer — everything here is bash.

Per tracker: YouTrack needs Cloud or Server 2025.3+ and a token scoped to
YouTrack only. GitHub needs a PAT — fine-grained preferred, with Issues
read/write, Contents read/write (this covers the wiki), Pull requests
read, Metadata read, and organisation Projects read/write.

The wizard is the only place credentials are entered. No skill will ever
ask you for a token; if one appears to, something is wrong.

## What the wizard does

Asks which tracker (`youtrack`, `github`, or `none`), sets up a
connection, registers the MCP server in every agent it finds on your
machine — Claude Code, Gemini CLI, Antigravity, VS Code/Copilot, Copilot
CLI, Codex — copies the skills into the project, and writes a non-secret
pointer at `.agents/config/story-tools.json`.

Agents you do not have are skipped. Re-running is safe: it reviews every
stored value, refreshes the skills, and prunes ones the suite has
retired. In a project that is already bound it asks whether you want a
plain refresh or a full reconfigure.

Restart your agent afterwards so it picks up the new MCP server.

## Joining a project that already uses this

You do not need this repo. The project carries its own copy of the setup:

```bash
git clone <the project>
cd <the project>
./.agents/setup.sh
```

That sets up *your* credential and registers the tracker in *your*
agents. It never rebinds the project or changes anyone else's setup.

Do not want to connect to the tracker at all — no access, no interest,
not your call to make? Answer `n`. The workflow still runs in full: your
agent keeps a worklog at `.agents/offline/worklog.md`, and whoever is
connected replays it into the tracker later. Nothing is lost.

## Staying current

If the project has `updates.check` enabled, `.agents/setup.sh` compares
its installed skills against what this repo publishes in `VERSIONS.json`
and offers to update. It never updates without asking, and skills are
tracked files — so an update shows up as a diff for you to review and
commit.

To pin a project, set `updates.check` to `false` in its pointer.

As the maintainer, updating a project is just running the installer from
your clone and committing the result. Teammates then get it on `git
pull`.

## Adding a skill on its own

The skills outside the suite are self-contained — copy one in:

```bash
cp -R skills/engineering/tdd /path/to/project/.agents/skills/
```

Agents that read `.agents/skills/` (or the `.claude/skills` /
`.github/skills` symlinks the wizard creates) pick it up on restart.

## When something goes wrong

**Agent cannot see the tracker tools.** The MCP registration is missing
or holds a stale token. Re-run the installer, or
`.agents/setup.sh --register` to re-push the current token. Restart the
agent afterwards — registrations are read at start-up.

**"Could not authenticate."** The token is wrong, expired, or lacks
scope. Re-run setup and enter a new one; never paste a token into a chat
with an agent.

**Skills look out of date.** Compare `.agents/skills/MANAGED.md` against
[`VERSIONS.json`](../VERSIONS.json). Re-run the installer from your clone
to refresh them.

**A skill you edited reverted.** Installed skills are managed copies and
are overwritten on refresh. Improvements belong upstream in this repo —
that is discovered work, not a local edit.

**Moved your tracker to a different server.** The pointer follows, but
the docs sync state and the `docs/stories/` snapshot still reference the
old one. The project-docs skill has the recovery ritual; the installer
warns you when it detects a rebind.
