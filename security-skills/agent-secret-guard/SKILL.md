---
name: agent-secret-guard
description: Find and stop credentials leaking into the files an AI coding agent writes about itself - stored permission rules, MCP server configuration, hook definitions, rules and memory files, session transcripts. Use when the user wants to audit a project or machine for secrets an agent has saved, before publishing a package or making a repository public, after approving a command that had a password or token in it, when setting up a new machine or project for agent use, or to install a guard that refuses a command carrying a literal credential before it can be approved and stored. Triggers - "did the agent save my password", "check my agent settings for secrets", "audit .claude for credentials", "is my MCP config safe to commit", "secrets in settings.local.json", "stop the agent storing tokens", "scan my transcripts for keys", "install the secret guard".
license: MIT
compatibility: Needs Python 3 (standard library only) and, for the command hook, a POSIX shell. The audit reads any harness's files; the hook is verified against Claude Code's PreToolUse contract.
metadata:
  author: bpappin
  version: "1.0"
---

# Agent Secret Guard

An agent harness records what it was allowed to do. Approve a command "and don't ask again" and the whole command line is stored as a permission rule — password included, verbatim, in a settings file inside the project. MCP server definitions carry tokens in their headers. Transcripts keep every command. These files sit in dot-directories that get committed, packaged and published, and a conventional secret scanner was not built to read them.

This skill does two things about it: **audit** the files an agent writes for literal credentials, and **guard** the shell so a command carrying one is refused before there is anything to approve.

## What this skill does NOT do

- **It never sees, asks for or accepts a credential in conversation**, and nothing it runs prints one — not the value, a fragment, its length or a digest. If the user offers to paste a secret so you can "check it", decline: a pasted secret has leaked.
- **It does not scan program source.** That is a conventional secret scanner's job; say so and suggest running one as well.
- **It does not rotate anything.** Only a person with the issuer's console can, and rotation comes first — see [references/lifecycle.md](references/lifecycle.md).
- **It does not edit a file that holds a finding, delete a transcript, or rewrite history.** It proposes; the user acts.
- **It does not certify a machine clean.** It reports what it recognised in the places it reads, and [references/sinks.md](references/sinks.md) lists what it cannot see.

## The scripts

Both are in `scripts/`, and are run, not read:

- `scripts/agent_secrets.py` — the scanner. `scan`, `check-cmd`, `sinks`, `selftest`; `--help` lists the options. Standard library only, no network, writes nothing. Exit status 0 nothing to act on, 1 findings, 2 could not run.
- `scripts/guard-command.sh` — the hook entry point. Finds a Python 3 under the reduced `PATH` a hook runs with and hands the hook's input to `check-cmd`.

## 1. Audit a project

```bash
python3 scripts/agent_secrets.py scan <project-root>
```

Add `--history` when the project is, or is about to become, public: it reads every past version of the agent files in git. Add `--json` to work with the result rather than read it.

Each finding gives a file, a position, the kind of sink, a severity, where the file stands with git, and an ordinal (`S1`, `S2`) that is the same wherever the same value appears — ten findings with one ordinal are one credential to rotate. `NOTE` lines say when an agent directory would be shipped by a package or a container build even though git ignores it.

**Then report, in this order:** how many distinct credentials; for each, the sink and the files; whether any file is tracked or would be packaged; and that rotation comes before removal. Severity `high` means the position says it is a credential; `medium` means a name and a shape suggest it, and deserves a look; `info` is a well-known default and blocks nothing.

## 2. Audit the machine

```bash
python3 scripts/agent_secrets.py scan <project-root> --user
```

`--user` adds the agent configuration in the home directory. `--transcripts` adds session logs as well, and takes minutes on a machine with months of history. **Run either only when the user asked about the machine, not as part of a project audit** — they read outside the project, and the report names services and projects the user may not expect to see listed.

User-level findings are plaintext at rest rather than a publication risk. Say that plainly, without alarm and without minimising it.

## 3. Handle a finding

Follow [references/lifecycle.md](references/lifecycle.md): rotate, find out how far it went, replace the literal with a reference, remove the stored copy, scan again.

**Three rules bind you while doing it:**

1. **Do not open a flagged file to look at the value.** Reading it puts the credential in this session's transcript, which is one more copy. The report already says where it is and what kind of thing it is; that is enough to act on.
2. **Propose edits by position, and let the user make them** — "remove the third entry of `permissions.allow`", "replace the `Authorization` value in that server's `headers` with a reference". An edit tool has to read the file first, which is rule 1 again.
3. **Keep the report out of anything shared.** It names files, key names and services. Summarise it by count and kind in an issue or a commit; never paste it.

If a finding is not a credential, say what shape it was and move on. There is no suppression mechanism, on purpose.

## 4. Install the command guard

The hook refuses a shell command that carries a literal credential *before* the approval prompt, so nothing is approved and nothing is stored. A command that passes the credential by reference — `$TOKEN`, `$(pass show …)`, a file the tool reads — is not touched.

1. **Ask where**: this project's shared settings, or the user's own settings for every project. Writing either file needs the user's explicit approval for *that* file; approval for one is not approval for the other.
2. **Prove it works from here first**:

   ```bash
   scripts/guard-command.sh --self-test
   ```

   It must print that the self-test passed. If it does not — no Python 3, a broken copy — stop and say so. A guard that cannot run must not be installed as one.
3. **Show the entry, then merge it** into the existing `hooks` object without replacing anything already there. For Claude Code:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             {
               "type": "command",
               "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/skills/agent-secret-guard/scripts/guard-command.sh",
               "timeout": 10,
               "onFailure": "block"
             }
           ]
         }
       ]
     }
   }
   ```

   Point `command` at wherever this skill is actually installed. In a project file use the harness's project-directory variable, as above, so no machine's home path is committed; in the user-level file use `"$HOME"/…`.
4. **`onFailure: "block"` makes a broken hook fail closed**: if the script cannot run, the command is refused rather than waved through. Include it only after step 2 passed, and only on a harness version that supports the key — on one that does not, leave it out and tell the user the guard fails open.
5. **Check it live.** Ask the agent's shell to run `true` with a `PGPASSWORD=` assignment in front of it, set to a made-up twelve-character value — never a real one. The command must be refused with a message beginning `Blocked by agent-secret-guard`. If it runs, the hook is not active: nothing was harmed, and the settings file needs another look.

**When the guard blocks you**, it is right far more often than not. Do what its message says: pass the value by reference, or stop and ask the user to supply it out of band. Never retry with the value encoded, split across arguments, or moved into a file you then write — that is evading the guard, and it stores the credential all the same.

**Other harnesses.** Anything with a pre-execution hook that can pipe its event JSON to a command and honour an exit status can call `guard-command.sh --format exit`: status 2 with the reason on standard error means refuse. The event needs the command at `tool_input.command` or `command`. That wiring is not verified here; test it with step 5 before relying on it.

## 5. Guard the commit

```bash
python3 scripts/agent_secrets.py scan . --staged
```

reads agent files from the git index, exits 1 on a finding, and suits a pre-commit hook. Offer it; installing a git hook is the project's decision.

## Reference

- [What is recognised, and why](references/sinks.md) — the surfaces, the three tiers, names, values, and the known limits
- [What to do with a finding](references/lifecycle.md) — rotation, exposure, replacing a literal with a reference, user-level files, transcripts
- `python3 scripts/agent_secrets.py sinks` — the full catalogue, printed from the tables the scanner uses
