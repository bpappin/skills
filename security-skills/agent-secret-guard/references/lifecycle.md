# What to do with a finding

A finding means a credential was written into a file an agent keeps. Removing the line is the last step, not the first: by the time it is in that file it has usually been somewhere else as well.

## 1. Rotate first

**Revoke or rotate the credential at its issuer before touching the file.** A value in a permission rule was in a command, so it is also in the session transcript; a value in a tracked file is in every clone; a value in a published package is in every mirror. None of those can be recalled, and deleting the line only removes the copy you can see. Rotation is the one step that makes the other copies worthless.

Only a person can do this. The agent does not hold the issuer's console, and must not be handed the new value to "put it back" — that is the same leak again. The agent's part is to say which credential, by the sink and file the report names, and to wait.

A default or development value (`postgres`, `root`) is reported as information for the same reason it is not blocking: there is nothing to rotate, and the question is only whether the thing it unlocks is reachable from anywhere that matters.

## 2. Find out how far it went

The report's last column says where the file stands:

| Standing | What it means |
|---|---|
| tracked by git | Assume it is in history. `scan --history` says which past versions carried it |
| not ignored by git | The next `git add .` takes it |
| ignored by git | Not committed from here — but see packaging below |
| user-level | Outside any repository; plaintext at rest on the machine |

**An ignore file is not a packaging rule.** The scan adds a note when an agent directory would be shipped anyway: a package manifest with no allowlist of files whose ignore rules do not cover the directory, or a container build that copies the whole context. A separate packaging ignore file *replaces* the VCS one rather than adding to it, which is how a directory that was never committed ends up in a published tarball. Check what a package would contain with the packager's own dry run before trusting either file.

Rewriting history removes a value from the repository, not from the clones, forks and caches made before the rewrite. Do it if the history must be clean; never count it as the fix.

## 3. Replace the literal with a reference

The credential should reach the program without ever being text in a command. In rough order of preference:

- **The tool reads it itself.** A credentials file the program already looks for (`~/.pgpass`, `~/.my.cnf`, `.netrc`, a cloud CLI's login profile), or a flag that names a file rather than a value (`--password-file`, `--env-file`, `@file`). The command carries nothing.
- **A secret manager fills it in.** `$(pass show acme/api)`, a keychain lookup, a vault read, or a `--password-stdin` flag fed from one of those — never from `echo`.
- **An environment variable set outside the session.** `"Authorization: Bearer $ACME_TOKEN"`, with the variable exported by the shell profile, a direnv file that is itself ignored, or the secret manager's own `run` wrapper. Set outside: `export ACME_TOKEN=…` typed into the agent's shell is a command, and is stored like one.

For MCP server configuration, use the harness's variable expansion in `env`, `headers` and `args` (`${ACME_TOKEN}`) or its helper-command mechanism where it has one, and keep the file that holds the real value out of the repository. Harnesses differ on which fields expand; check, and re-run the scan to confirm the literal is gone.

## 4. Remove the stored copy

- **Permission rule.** Delete the rule that carries the value. If the command is still wanted without a prompt, replace it with a rule that names the program and no credential. The skill proposes the edit and the user makes or approves it; it does not rewrite a permissions file itself.
- **Rules or memory file.** Rewrite the example with a placeholder (`<token>`, `$ACME_TOKEN`).
- **Script in an agent directory.** Move the value out as above; a script that needs a credential reads it from the environment and fails with a clear message when it is absent.

Then scan again. The ordinal for that credential should be gone from every file, not from one.

## 5. Keep it from coming back

- **Install the hook.** It denies a shell command that carries a literal credential before the approval prompt is shown, so there is nothing to approve and nothing to store. The denial tells the agent to pass the value by reference or stop and ask — and not to retry with the value encoded, split or moved.
- **Never approve a command "and don't ask again" when a credential is visible in it.** That one click is the whole leak.
- **Ignore per-machine agent files everywhere, not per project.** A global excludes file (`git config --global core.excludesFile`) listing the harness's local settings files covers every repository on the machine, including the ones cloned next month.
- **Give packages an allowlist.** An explicit list of what ships cannot be defeated by a directory nobody thought to exclude.
- **Scan what is staged.** `scan --staged` reads the index and suits a pre-commit hook.

## User-level configuration

`scan --user` reads the agent configuration in the home directory. Nothing there reaches a repository by itself, which is why it tends to accumulate literal tokens — an MCP server definition with a token pasted into a header is the usual one. It is still plaintext, readable by every process running as that user: every agent session, every package install script, every backup and sync client.

Treat a finding there as real but not urgent in the way a tracked file is. Move each value to a reference when next touching that server's configuration, and rotate any that has been in place long enough that nobody remembers where else it was pasted.

## Session transcripts

`--transcripts` reads the session logs a harness keeps. They record every command and every file shown to the model, so a credential that passed through a session is in one, whatever happened afterwards. It is slow — minutes on a machine with months of history — and opt-in.

A transcript cannot usefully be edited. What a finding there tells you is which credentials to rotate; once they are rotated the copy is harmless. Shortening the harness's transcript retention and deleting old logs reduces what is lying around, and both are the user's decision — the skill does not delete anything. Never attach a transcript to an issue or share one without scanning it first.

## When the scanner is wrong

A finding on something that is not a credential is a bug in the catalogue, not a reason to add an exception: there is no inline suppression and no allowlist, because a way to tell the scanner to ignore a line is a way to tell it to ignore a credential. Check what the value is, and if it is a false positive, report the *shape* — the sink and the kind of value — never the value. A credential the scanner missed is reported the same way.
