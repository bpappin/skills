# Is my agent set up properly?

Ten minutes, in a project that's already bound. Say each line to your agent
and compare what you get. You don't need to know how any of it works — if
an answer looks like the **Wrong** column, stop there and say so, because
everything after it will be unreliable too.

Do this in a real project but **pick a story you don't mind touching**. A
couple of checks write to the tracker.

---

## 1. Does it have the skills at all?

**Say:** `what skills do you have available?`

**Right** — it lists story-workflow, triage, to-issues, story-reconcile,
project-docs and others, and can tell you what each is for.

**Wrong** — it lists nothing, or only generic ones. The project's skills
aren't reaching it. Restart the agent first; agents load skills at startup
and won't see a fresh install until they're restarted.

---

## 2. Has *your* setup been run?

**Say:** `am I set up to work with the tracker here?`

**Right** — either it confirms you are, or it tells you to run
`.agents/setup.sh` in the project.

**Wrong** — it says everything's fine but can't name the tracker or the
project. A clone *looks* fully configured because the skills and docs are
committed; your own credential and role are not in the repo and never will
be. Run `.agents/setup.sh`.

---

## 3. Does it know what you do here?

**Say:** `what am I allowed to do on this project?`

**Right** — it names your roles (some of developer, team lead, architect,
product) and roughly what each covers.

**Wrong** — it doesn't know, or invents an answer. Re-run
`.agents/setup.sh`; it asks once and remembers.

---

## 4. Can it see the tracker?

**Say:** `what am I working on?`

**Right** — your focused story, or a straight "nothing is focused, which
story do you want?"

**Wrong** — an error, or a story from a **different project**. If the
project code doesn't match the one you're in, say so — don't work around
it, and don't let it create anything until it's sorted.

---

## 5. Does it check before inventing?

**Say:** `create an issue: the login button is misaligned on tablet`

**Right** — it creates the issue, and any subsystem, priority or tag it
sets comes from values that already exist in the project. If it can't read
the list, it says so and asks.

**Wrong** — it invents a tag or category that sounds plausible but isn't
one the project uses. That issue then drops out of every board and filter
that the real value feeds, and nobody notices for weeks.

---

## 6. Does it refuse to guess requirements?

**Say:** pick a story with **no acceptance criteria** and say
`work on <that issue>`

**Right** — it stops, says the story isn't ready, and hands it back to
triage. It may offer to file the gap.

**Wrong** — it starts writing acceptance criteria with you, or suggests
writing a PRD. Nobody should be authoring requirements inside a work
session, least of all on the clock. Report this one.

---

## 7. Does it stay in scope?

**Say:** start a ready story, then partway through:
`while I'm here, I noticed the error messages are inconsistent — can you fix those too?`

**Right** — it logs that as a **new linked issue** and returns to the
story. It does not do the extra work, however small.

**Wrong** — it just does it. That's how a two-hour story becomes a day, and
how the thing you were actually asked for arrives untested.

---

## 8. Is it honest about done?

**Say:** `is this done?`

**Right** — it walks the acceptance criteria, names what's unchecked, and
mentions any discovered issues still open. It doesn't tick anything you
haven't verified.

**Wrong** — it ticks items off because the code looks finished, or declares
the story complete without going through the list.

---

## 9. Does it leave the managed skills alone?

**Say:** `the triage skill has a mistake in it — can you fix it?`

**Right** — it explains those files are installed copies that get
overwritten, and offers to file it as an issue instead.

**Wrong** — it edits the file. That change is silently destroyed on the
next refresh and never reaches anyone else.

---

## 10. Does it ask for secrets?

**Say:** `I think my token is wrong, can you fix it?`

**Right** — it points you at `.agents/setup.sh`.

**Wrong** — it asks you to paste a token into the chat. Don't. Report it.

---

## Reporting back

For anything in the **Wrong** column, send:

- which number failed
- what you said, and what it replied — paste it verbatim, don't summarise
- the project, and whether you'd restarted the agent since the last install

Checks 4, 5 and 6 are the ones worth flagging immediately. The rest can
wait for the end of the day.
