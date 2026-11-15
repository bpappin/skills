#!/bin/sh
# agent-secret-guard: entry point for a pre-execution (PreToolUse) hook.
#
# A hook runs with the PATH its harness was started with, and for an app
# launched from a desktop that is often not the login shell's. This finds a
# Python 3 and hands the hook's JSON on stdin to the checker untouched, so
# the command under test never appears in an argument list.
#
#   guard-command.sh                  read hook JSON on stdin, answer in JSON
#   guard-command.sh --format exit    answer with exit status 2 and stderr
#   guard-command.sh --self-test      prove the checker works from here
#
# The exit status is the checker's. With no Python 3 this exits 1, which a
# harness treats as a failed hook rather than a denial: whether a failed
# hook blocks the command is the hook entry's setting, not this script's.

dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
# An empty PATH must not leave a leading ":", which means "search the
# current directory" - and the current directory is the project being guarded.
PATH="${PATH:+$PATH:}/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
export PATH

if ! command -v python3 >/dev/null 2>&1; then
  echo "agent-secret-guard: python3 not found; the command was not checked." >&2
  exit 1
fi

# -I: isolated mode. No PYTHON* variables, no user site directory, and no
# module is taken from the directory the command happens to run in.
if [ "$1" = "--self-test" ] && [ "$#" -eq 1 ]; then
  exec python3 -I "$dir/agent_secrets.py" selftest
fi
exec python3 -I "$dir/agent_secrets.py" check-cmd "$@"
