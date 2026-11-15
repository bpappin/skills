# Security skills

Skills that protect the machine the work is done on: what an agent stores about its own sessions, and what leaves the machine when a project is committed, packaged or published. They guard the work without recording it, and nothing here needs a tracker, a knowledge base or the main package.

Copy the directories you want straight into a project's `.agents/skills/` (or `.claude/skills/`), or into the user-level skills directory to have them in every project. There is no installer and nothing to connect. Take one skill or all of them; none of them needs the others.

## Using them

Say what you want in plain language: "check my agent settings for secrets", "is this safe to publish", "stop the agent storing tokens". The skill audits and reports. It changes nothing by itself — a credential has to be rotated by the person who can, and a settings file is edited by the person it belongs to.

## What is different about this set

**No script here touches the network, handles or emits a credential, or writes outside the project it runs in.** A security tool is the last thing that should have to be taken on trust, so the rule is one a reviewer can confirm: no import of a network module, no request call, no file opened for writing. The scanners read; they print where a credential is and what kind of place it is in, and never the value, a fragment of it, its length or a digest of it.

**The one exception is installing a hook**, which has to write a settings file. A skill does that only with the user's explicit approval for that particular file, and only after proving the hook runs.

**Every skill stands alone.** No dependency on another skill, an MCP server or a service. A skill's scripts need Python 3 and its standard library, and nothing is installed.

**They report shapes, not contents.** A finding names a file, a position and a kind of sink. The report is still private — file and key names say which services a machine uses — and the skills say so, and keep it out of commits and trackers.

**Skills never ask for or accept a credential in conversation.** That holds across this repository and matters most here: a secret pasted in to be "checked" has just been leaked to the transcript.

## Relationship to the other packages

This set is independent of `skills/`, `light-skills/` and `tooling-skills/`, and installs beside any of them or none. It has no counterpart in them, so there is nothing to keep in step. `git-guardrails-claude-code` in the main package is a neighbour rather than a dependency: it stops destructive git commands, and installs its hook the same way.

## Contents

| Skill | What it does |
|---|---|
| `agent-secret-guard` | Audit the files an AI coding agent writes about itself — permission rules, MCP configuration, hooks, rules files, transcripts — for literal credentials, and install a hook that refuses a command carrying one before it can be approved and stored |

## Tests

`tests/` holds the scripts' test suite, kept outside the skill directories so it is not copied into a project with them. From the repository root:

```bash
python3 -m unittest discover -s security-skills/tests
```

Every credential-shaped value in the tests is assembled at run time, so the repository contains none and no scanner — this one included — has anything to find in it.
