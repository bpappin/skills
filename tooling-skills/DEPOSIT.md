# Deposit for review: tooling-skills

Delete this file once the package is reviewed. It is a note to this repository's maintainers, not part of the package.

## What it is

A proposed new top-level package, parallel to `skills/` and `light-skills/`, for development tooling: skills that make keeping a codebase healthy easier, independent of the main package's tracking. It holds one skill so far, `update-libraries`, which updates a Gradle version catalog to versions that agree with each other.

It was written and tested in a Kotlin Multiplatform library repository that uses it day to day, after a dependency update there took Skiko at its newest Maven Central release instead of the version Compose Multiplatform brings, and broke every web test. The skill's core rule comes from that: a follower takes the version its leader's release asks for, read from the leader's published metadata, never its own newest. Nothing in it is specific to that repository: the project's facts live in its own `gradle/dependency-rules.toml`, which the skill sets up.

Nothing here is committed, and nothing outside `tooling-skills/` was changed.

## How it was tested

Against a real catalog of about 25 version keys, with its rules file:
- **Planning:** `versions.py plan` holds Skiko at the version Compose requires while reporting the newer Skiko on Central. It holds a two-member set when only one member has a new release. It follows a coroutines version from the library that requires it, and lists every pin with its reason.
- **A leader behind:** with a copy of the catalog at an older Compose, the plan moves Compose and moves Skiko to exactly what the newer Compose requires.
- **No rules file:** every key is treated as independent, with a warning, and the plan shows the naive updates the rules exist to stop.
- **A bad rules file:** a rule naming a key the catalog lacks is refused with exit 1.

Not done: `skills-ref validate` was not available where it was written. The frontmatter has only `name`, `description`, `license` and `metadata`; the description is 863 characters; `SKILL.md` is 67 lines.

## Decisions left to you

- **The package and its name.** `tooling-skills/` beside `light-skills/`, if that is where you want it.
- **A rule for the package in `AGENTS.md`**, as `light-skills/` has one. Proposed wording, since this set cannot follow light-skills' no-network rule:

  > **No script in `tooling-skills/` may send anything, handle a credential, or write outside the project it runs in.** A script may read public package metadata, because a tooling job often has to know what has been published; every request is a plain HTTPS GET to a public registry, confirmable with a grep. No skill here may depend on another being installed, on an issue tracker, or on the main package's configuration.

- **A `WORKFLOW.md` companion** like light-skills'. Left out: there is one skill, and its README section covers the people's side. Worth adding if the set grows.
- **A likely second member:** a privacy guard for repositories that are, or will become, public. It is a commit hook plus a CI check that blocks personal emails, home paths, private network names, secrets and tool attribution, with a denylist of private names kept outside the repository and supplied to CI as a secret. It exists in the same repository and generalizes the same way, with only its exempt list being project-specific.
