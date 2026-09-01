# Working in this repository

## This repository is public

Everything committed here is world-readable and permanent — a public git
history cannot be unpublished, only added to. Write for a stranger who
found this repo, not for the maintainer.

**Never commit personal details.** Concretely, that means no real names in
prose or code comments, no personal email addresses, no machine or
hostnames, no absolute home paths, no employer, client or private project
names, no internal tracker keys or instance URLs, and nothing about the
maintainer's business, billing, tax position or working habits. Verbatim
quotes from a working conversation are the most common way all of this
leaks at once — a design discussion is full of them.

The exceptions are deliberate and narrow: the copyright line in `LICENSE`
and `NOTICE.md`, maintainer attribution in `README.md`, the GitHub handle
and its `users.noreply.github.com` address as vendor in the YouTrack app
manifest, and the published Maven coordinates used as worked examples. Do
not add to that list without being asked, and do not strip what is on it.

Authorship of the tool is fine; identity beyond it is not. A GitHub handle
is the right granularity — it is already public, and it is the name the
project is known by.

**Document the pattern, not the person.** When a design came out of
someone's specific situation — how they work, what tools they pay for, what
their client expects — the reusable content is the *pattern*: this is a
common way developers work, here is why the obvious design fails against
it, here is how this one covers it. Written that way the reasoning survives
intact and nothing traces back to an individual. If a fact only makes sense
as "the maintainer does X", it does not belong here.

This applies hardest to documents an agent generates from a conversation —
RADs, ADRs, design notes, session summaries. Those are written while the
conversation is still in context, which is exactly when quoting feels
natural and is most dangerous.

**Examples use placeholders.** `acme`, `example.com`, `PROJ-123`,
`<instance>.youtrack.cloud`, `owner/repo`. Never a real project, org or
instance, even one that happens to be public — a real name in an example
reads as a live reference and invites someone to go look.

**Check before you commit.** Grep your own additions for names, emails,
hosts, home paths and project names before proposing them. If something is
borderline, leave it out and say so — it is far cheaper to add a detail
later than to remove one from a public history.

## Two skill sets, and they drift

`skills/` is the full package. `budget-skills/` is a parallel set for constrained places - a tight token budget, or an organisation whose review will not accept the sync tooling. It is **not** a subset: the documents there had to be written differently, and they are held to two rules the main set is not.

**No script in `budget-skills/` may touch the network or handle a credential.** That is what makes the set reviewable - it is confirmable with a grep instead of by reading transport code. A script that scaffolds a file, formats a document or checks a convention is fine. If a workflow needs the network, it does not belong in that set at all; do not write a smaller sync.

**Every skill there stands alone.** No dependency on another skill being installed, on a tracker, on an MCP server, or on a knowledge base existing. Those directories are copied into a project by hand, one at a time.

**When you change a skill in one set, check its counterpart in the other.** Nothing enforces this and the two will silently diverge. Guidance about how to think usually belongs in both; guidance about tooling usually belongs in only one. Say which you concluded and why, rather than copying the edit across by reflex - a change that is right for the full package is often wrong for a project with no tracker to sync to.
