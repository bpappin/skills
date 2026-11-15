# What is recognised, and why

The scanner does not look for strings that seem random. It looks for a value sitting somewhere a credential is *passed* — an argument to `mysql -p`, an `Authorization` header, a `PGPASSWORD=` assignment — and then asks whether that value is the credential itself or a reference to one. That is what lets it catch a short, low-entropy password that an entropy scanner walks past, and stay quiet on a long hash that an entropy scanner flags.

The authoritative list is the script's own: `python3 scripts/agent_secrets.py sinks` prints every name, program and token prefix it knows. This page explains the structure that list fits into.

## Where it reads

**The files an agent harness writes about itself, not the project's source.** Program source is a conventional secret scanner's job, and a good one already exists for it.

| Surface | What goes wrong there |
|---|---|
| Permission rules (`permissions.allow` and its equivalents) | Approving a command "and don't ask again" stores the whole command line verbatim, credential included |
| MCP server configuration | `env`, `headers`, `args` and the server URL routinely carry a token, in a file that is often committed so a team shares the server list |
| Hook and command definitions | A hook is a stored shell command |
| Rules and memory files (`CLAUDE.md`, `AGENTS.md`, `.cursorrules` and the like) | A working command gets pasted in as an example; an agent appends what it learned |
| Scripts and config inside agent directories | Setup scripts with a token inlined "for now" |
| Session transcripts (opt-in) | Every command run and every file shown is kept, in plaintext, indefinitely |

Agent directories and filenames for the common harnesses are built in; `scan --user` adds the user-level configuration in the home directory, and `--transcripts` adds session logs. Dependency, build and VCS directories are pruned.

## The three tiers

**Structural sinks — severity high.** The position itself says the value is a credential, so shape is not consulted: a six-character password is a finding.

- A flag or positional argument of a known program: `mysql -p…`, `docker login -p`, `curl -u user:pass`, `psql` connection strings, `kubectl --token`, and about 150 others. A flag that closes a cluster of short ones (`curl -sSu user:pass`) is the same flag.
- An environment assignment with a credential name, as a command prefix, after `export`, in `env`, or passed with `-e` / `--env` / `--build-arg`.
- A credential-bearing HTTP header, wherever one is written: `-H`, a `headers` object, an MCP server definition. A cookie counts when its name says session or token, or its value is long and generated; `theme=dark` does not.
- A password in URL userinfo: `scheme://user:password@host`.
- A value echoed, printed or here-stringed into something that reads a credential from standard input: `echo … | docker login --password-stdin`, `vault login -`, `openssl passwd -stdin`, `curl -K -`.
- A JSON, TOML or YAML key with a credential name.
- A `command` in a configuration file, read as the command it is — whether it is written as one string, a string with an `args` list, or the whole argument list.

**A command that runs another command is read for the one it runs.** `ssh host mysql -p…`, `docker exec db mysql -p…` and `kubectl exec pod -- redis-cli -a …` hand the credential to the program at the end, and so do `sudo`, `env`, `bash -c '…'`, `env -S '…'` and `npx -c '…'`.

**Known-prefix tokens — severity high.** Tokens whose issuer gave them a recognisable shape are a finding anywhere, in any position, including prose: cloud access key ids, source-host tokens, model-provider keys, payment keys, chat webhooks, private key blocks. A JSON Web Token is medium, because many are short-lived or public. A private key header is a finding only with a body after it — the header alone is what a document about key formats contains. A match that is only words and short numbers joined by hyphens or underscores is a slug — a branch named `sk-refactor-the-payment-module` — and is not a token.

**Embedded pairs — severity medium.** `name=value` or `"name": "value"` found inside a larger string — a request body, a heredoc, a line of a script — and an `Authorization: Bearer …` line in a YAML file. The sink is a guess here, so the value must look the part: one token, not a phrase, not a call or attribute access, not an identifier.

In a Markdown file, the lines of a fence marked as shell (or not marked at all) are also read as commands, and what that reading finds is capped at medium: a command in a document is an example until shown otherwise. A known-prefix token is high wherever it sits, fence or prose.

## Names

A name is split into words (`DB_PASSWORD`, `dbPassword` and `db-password` are the same name) and classed:

- **Strong** — `password`, `secret`, `token`, `apikey` and their relatives, and pairs such as `api key`, `client secret`, `signing key`, `service role key`, `sdk key`. Fused names (`PGPASSWORD`, `MYSQL_PWD`) count.
- **Weak** — `auth`, `session`, `cookie`, `credentials`, and a name that ends on `key` with a qualifier that says nothing about what it unlocks. These name a credential about as often as they name something else, so the value must also be at least 16 characters and mix letter case or digits, and must not be a UUID or a digest. A weak word counts only when the name ends on it.
- **Not a credential** — names that end by saying they are about a credential rather than being one (`token_file`, `password_prompt`, `secret_name`, `api_key_env`, `token_count`, `passwordValidator`), names that start with an action (`max_tokens`, `show_password`), and names marked public (`publishable_key`, `anon_key`). The same goes for a credential word that is doing another job: a token that says where a listing stopped (`next_token`, `page_token`, `continuation_token`), a key that names, sorts or routes something (`routing_key`, `sort_key`, `cache_key`, `kms_key_id`, git's `user.signingKey`), a pass that is a stage (`compiler_pass`), and a flag that names a stored secret rather than giving one (`gcloud --secret=…`). A key written with spaces is a label when it is a short noun phrase (`AWS Secret Access Key`, the way a vault export or an API collection writes it) and is not a name at all when it reads as a clause — more than five words, a question mark, or a question word, an article or an auxiliary verb in it. That is a question stored with its answer.

## Values

Only a **literal** is a finding. Everything else is how a credential is supposed to travel, and is never reported:

| Class | Examples |
|---|---|
| Environment reference | `$TOKEN`, `${TOKEN}`, `%TOKEN%`, `"Bearer $TOKEN"`, `{{ secrets.TOKEN }}` — but not a `$` inside single quotes or after a backslash, which the shell leaves alone and which is therefore part of a literal |
| Command substitution | `$(pass show acme)`, backticks, `<(…)` |
| File or store reference | `@token.txt`, `-`, a path, `op://…`, `vault:…`, `file:…` |
| Placeholder | `<token>`, `YOUR_API_KEY`, `changeme`, `xxxx`, `REDACTED`, an upper-snake name with no sigil, words that name their own kind (`dev-signing-key`) |
| Wildcard | `*`, `:*` — the tail of a permission rule |
| Well-known default | `postgres`, `root`, `admin`, `password` — reported as information, never blocking |

## What a finding says

File, position, sink and severity — and an ordinal (`S1`, `S2`) that is the same wherever the same value appears in one run, so one leaked credential in ten places reads as one credential. **Never the value, a fragment of it, its length or a digest of it.** A digest of a short password is the password to anyone with a wordlist; a length narrows a search. The ordinals are keyed per run and mean nothing afterwards.

**The report is still private.** It names files, key names and flags, and on a real machine those say which services are in use and what the projects are called. Read it, act on it, and do not paste it into an issue, a commit or a shared channel.

## Known limits

- **It reads agent files, not source.** Run a conventional secret scanner over the code as well.
- **Unknown programs get the generic pass only**: credential-named flags, environment assignments, headers, URLs and known-prefix tokens. A bespoke CLI that takes a password as its second positional argument is not caught until it is in the table.
- **A flag it does not know takes a value can shift positional counting** for programs matched by position.
- **A password flag whose value is optional is read as taking the next word** unless that word is itself a flag. `mongosh -p analytics` is reported even where the author meant a prompt and a database name, because the program reads it as a password too.
- **A carrier's own options are not modelled.** After `ssh`, `docker exec` or `kubectl exec` the carried command is what follows `--`, or failing that whatever starts at one of the next few words that names a known program. A carried command that starts with an unknown program gets no table.
- **A weak name with a short or single-case value is not reported**, by design.
- **A random value with no digits can read as a name.** Where the scanner has to decide whether something is a name or a value — what sits before the `=` in `fly secrets set`, a cookie, a segment after a leading slash — it calls it a value when letters and digits interleave or when mixed case breaks into one- and two-letter pieces. About one random 16-letter mixed-case value in five does neither, and a single-case one never does.
- **A value hidden by encoding is not decoded.** Base64 of a password under a neutral name is invisible.
- **Git history is capped** at 3,000 blobs of agent files; the report says when the cap was reached.
- **Ignore-file matching is deliberately simple**: it answers "would this agent directory be committed or packaged" without negation patterns.
- **The hook is verified against one harness's PreToolUse contract.** Others can call `check-cmd --format exit` from whatever pre-execution hook they offer, but that wiring is theirs to test.
