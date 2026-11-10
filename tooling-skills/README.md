# Tooling skills

Skills for the development setup itself: the build, its dependencies, the checks that keep a codebase healthy. They make the work easier without recording it. Tracking work is what the main package is for, and nothing here needs it.

Copy the directories you want straight into a project's `.agents/skills/` (or `.claude/skills/`). There is no installer and nothing to connect. A skill that needs to know something about the project keeps it in a file beside what it describes, and sets that file up the first time it runs. Take one skill or all of them; none of them needs the others.

## Using them

Say what you want in plain language, and the agent picks the skill that fits: "update the libraries", "are our dependencies out of date", "we just released". A skill does the work and reports. How that work is recorded (an issue, a ticket number in the commit, nothing) is the project's convention, written in its own `AGENTS.md`, and the agent follows that anyway.

Each skill changes the project only after the maintainer approves a plan. The plan comes first, because these skills touch build files, and a build file changed on the strength of something read from the network is exactly what a careful project refuses.

### Where the project's knowledge lives

A skill here knows how to do a job, not what a particular project needs. What a project needs lives in the project, in a file beside what it describes, so a person or a CI check can read it without the skill:

| Skill | Project file | What it holds |
|---|---|---|
| `update-libraries` | `gradle/dependency-rules.toml` | Which versions follow which, which are pinned and why, which move only as a set, and what proves a round |

The skill sets the file up from what the project already says about itself, such as the comments in its version catalog and its vendoring scripts, and the maintainer confirms every entry. After that, the file is the project's. A skill that wrote these facts into its own instructions would be one more copy of them to go stale.

## What is different about this set

**Every skill stands alone.** No skill here depends on another being installed, on an issue tracker, on the main package's configuration, or on an MCP server. Removing any one directory breaks nothing.

**A script may read public metadata over the network, and do nothing else with it.** That is the job: `update-libraries` has to know what Maven Central and npm have published. So the rule here is not light-skills' "no network". It is narrower and just as checkable: a script reads public package metadata, sends nothing, handles no credential, and writes nothing outside the project it runs in. Every request is a plain HTTPS GET, confirmable with a grep for the URLs and the request calls.

**Project facts never live in a skill.** If a skill needs to know that one version follows another in this project, that fact goes in the project's file, with its reason, and the skill reads it.

## Relationship to the other packages

This set is independent of both `skills/` and `light-skills/`, and installs beside either or neither. It has no counterpart in them, so there is nothing to keep in step. If a tooling job turns out to need tracking, the tracking belongs in the main package, and the tooling stays here.

## Contents

| Skill | What it does |
|---|---|
| `update-libraries` | Update a Gradle version catalog to versions that agree with each other (followers at their leader's version, pins held, sets moved together), verify the build, and set aside what cannot move |
