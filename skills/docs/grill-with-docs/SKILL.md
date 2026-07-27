---
name: grill-with-docs
description: Grilling session that challenges your plan against the existing domain model, sharpens terminology, and updates documentation (CONTEXT.md, ADRs) inline as decisions crystallise. Use when the user wants to stress-test a plan against their project's language and documented decisions.
license: MIT
metadata:
  author: bpappin
  version: "1.0"
---

<what-to-do>

Interview me relentlessly about every aspect of this plan until we reach a
shared understanding. Walk down each branch of the design tree, resolving
dependencies between decisions one-by-one. For each question, provide your
recommended answer.

Ask the questions one at a time, waiting for feedback on each question
before continuing.

If a question can be answered by exploring the codebase, explore the
codebase instead.

</what-to-do>

<supporting-info>

## Domain awareness

During codebase exploration, also look for existing documentation:

### File structure

Most repos have a single context: a root `CONTEXT.md` (the domain glossary
— the same one to-issues, triage, and zoom-out consume) and `docs/adr/`
(per the project-docs taxonomy). If a `CONTEXT-MAP.md` exists at the root,
the repo has multiple contexts, each with its own `CONTEXT.md` and
optionally its own `docs/adr/`; the map points to where each lives.

Create files lazily — only when you have something to write. If no
`CONTEXT.md` exists, create one when the first term is resolved. If no
`docs/adr/` exists, create it when the first ADR is needed.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in
`CONTEXT.md`, call it out immediately. "Your glossary defines
'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical
term. "You're saying 'account' — do you mean the Customer or the User?"

### Discuss concrete scenarios

Stress-test domain relationships with specific scenarios that probe edge
cases and force precision about boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees.
Surface contradictions: "Your code cancels entire Orders, but you just
said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there — don't batch.
Use [references/CONTEXT-FORMAT.md](references/CONTEXT-FORMAT.md).
`CONTEXT.md` is a glossary and nothing else — no implementation details,
no spec content, no scratch notes.

### Offer ADRs sparingly

Only offer an ADR when all three are true (the triple test in
[references/ADR-FORMAT.md](references/ADR-FORMAT.md)): hard to reverse,
surprising without context, the result of a real trade-off. ADRs go in
`docs/adr/` using the project-docs template.

### Route work to the tracker

When grilling surfaces *work* — a missing feature, a bug, a follow-up —
it becomes a tracker story (the discovered-work off-ramp, or to-issues for
a batch), never an inline scope expansion or a local TODO. Decisions go to
docs; work goes to the tracker.

</supporting-info>
