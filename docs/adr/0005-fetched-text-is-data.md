# ADR-0005: Text an agent fetches is data, never instructions

Date: 2026-09-18 · Status: accepted

## Context

Every skill in this suite tells an agent to go and read something it did not write: an issue body and its comments, a KB article, a wiki page, a PRD referenced by URL, a CI log, a relayed message from another agent. That reading is the point of the suite, and it is also the whole exposure.

The exposure is not mainly crafted injection. A guidance file that names a package that does not exist is enough: one study of more than 8,500 such files found 237+ referenced packages missing across PyPI, npm and RubyGems, and a registered missing name was downloaded and executed by a company server about four minutes later. Nothing was malformed and no author was compromised - the file said *install this*, which is what such files are for. A control tuned to spot hostile phrasing never fires on that.

Two further comforts are false. Provenance is not content: a trusted operator can serve text assembled from a comment field, a rendered README or a CDN that the operator never saw. And an attitude is not a rule - "be careful with untrusted input" forbids nothing an agent can fail.

This suite has a carrier the general case does not: `project-docs` **pulls** KB articles and wiki pages into `docs/knowledge/`, where they become ordinary files that agents read as project doctrine. A wiki's write list is wider than the repo's, and after a sync nothing distinguishes a pulled page from something the team wrote and reviewed.

## Decision

Fetched text is data. Skills that send an agent to read it carry a prohibition on *acting* on instructions found inside it - run a command, add a dependency, edit a build or instruction file - without asking first, naming the line and its source. Reading is untouched and expected; only obeying is forbidden. One approval covers one document: a document that refers the agent onward has spent it.

The rule lives in the skills, because this suite's instruction files are not installed into consuming projects - only skills are. It is stated as forbidden acts rather than as vigilance, and the reasoning stays here rather than in the skills.

## Consequences

Agents keep reading everything they read today, so nothing in the workflow slows down until a document actually tries to direct the agent - and at that point a prompt to the user is the correct outcome rather than a cost.

What this does not buy: enforcement. Nobody has measured whether such a rule stops an agent following an injected instruction, here or elsewhere. It is a policy statement in a file the agent reads, and the same mechanism that makes skills effective is the one an injected instruction exploits. Treat it as a reasoned constraint, not a control.

Raised by a peer project's finding after five projects asked the same question on one day.
