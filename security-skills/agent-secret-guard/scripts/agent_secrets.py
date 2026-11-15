#!/usr/bin/env python3
"""Find literal credentials in the files an AI coding agent writes about itself.

An agent harness records what it was allowed to do: approved commands become
permission rules, MCP servers carry their environment, transcripts keep every
command line. A credential typed into any of those is stored verbatim, in a
file that conventional secret scanners were not built to read.

Four subcommands:

  scan       audit the agent files of a project (and optionally the user's own)
  check-cmd  PreToolUse hook: refuse a command that carries a literal credential
  sinks      print the catalogue of places this tool looks
  selftest   prove the checker denies a literal and passes a reference

Guarantees, which the tests hold it to:

  * standard library only, no network, no subprocess other than read-only git
  * nothing is written to disk
  * no credential, fragment, length or digest of one is ever printed; findings
    name the file, the position and the kind of sink, never the value
"""

import hashlib
import hmac
import json
import os
import re
import stat
import subprocess
import sys

try:  # tomllib is 3.11+; without it TOML falls back to the text tier.
    import tomllib
except ImportError:  # pragma: no cover
    tomllib = None

VERSION = "1.0"

HIGH, MEDIUM, INFO = "high", "medium", "info"

# --------------------------------------------------------------------------
# Key classification: does this NAME say its value is a credential?
# --------------------------------------------------------------------------

_STRONG_SINGLE = {
    "password", "passwd", "passphrase", "pass", "secret", "token", "apikey",
    "authtoken", "accesstoken", "secretkey", "privatekey", "authkey", "psk",
    "apitoken", "clientsecret", "secrets", "tokens", "passwords",
}
_STRONG_PAIRS = {
    ("api", "key"), ("access", "key"), ("secret", "key"), ("private", "key"),
    ("auth", "key"), ("account", "key"), ("master", "key"),
    ("encryption", "key"), ("signing", "key"), ("app", "key"),
    ("license", "key"), ("client", "secret"), ("service", "key"),
    ("deploy", "key"), ("webhook", "secret"), ("role", "key"),
    ("restricted", "key"), ("admin", "key"), ("application", "key"),
    ("sdk", "key"), ("server", "key"), ("write", "key"), ("rest", "key"),
    ("pass", "phrase"), ("pass", "word"),
}
_WEAK_SINGLE = {
    "auth", "authorization", "bearer", "cookie", "session", "jwt",
    "credential", "credentials", "dsn", "pat", "creds", "cred",
}
# "key" alone is weak, and only when nothing says it is some other kind of key.
_KEY_NOT_CREDENTIAL = {
    "cache", "sort", "primary", "foreign", "public", "ssh", "partition",
    "index", "map", "dict", "object", "row", "group", "order", "idempotency",
    "dedupe", "s3", "storage", "blob", "config", "json", "lookup", "search",
    "hot", "shortcut", "keyboard", "binding", "routing", "shard", "sharding",
    "translation", "i18n", "locale", "issue", "project", "tag", "label",
    "host", "kms", "gpg", "pgp", "message", "item", "entity", "document",
    "doc", "column", "field", "feature", "query", "bucket", "hash", "range",
    "composite", "natural", "surrogate", "unique", "candidate", "join",
    "grouping", "aggregation", "path", "registry", "metric", "event",
    "resource", "record", "table", "queue", "topic", "stream", "node",
}
# A token that says where a listing stopped, or which run to cancel.
_TOKEN_NOT_CREDENTIAL = {
    "next", "continuation", "continue", "starting", "start", "page", "paging",
    "pagination", "sync", "resume", "cancel", "cancellation", "cursor",
}
# "pass" is a password in DB_PASS and a stage or a result in these.
_PASS_BEFORE = {
    "compiler", "optimization", "optimizer", "opt", "llvm", "test", "tests",
    "first", "second", "multi", "single", "two", "one", "render", "shader",
    "lint", "by", "band", "high", "low", "boarding", "season", "final",
}
_PASS_AFTER = {
    "list", "lists", "count", "rate", "through", "thru", "manager", "fail",
    "failed", "by", "pipeline", "order", "number", "num", "one", "two",
    "plugin", "plugins", "stage", "stages",
}
# A name ending in one of these describes where or how, not the secret itself.
# Words that make a spaced key a clause rather than a label. Only consulted
# for a name written with spaces: `isToken` and `--if-token` are names.
_CLAUSE_WORDS = {
    "what", "why", "how", "when", "where", "who", "whose", "which", "is",
    "are", "was", "were", "do", "does", "did", "can", "could", "should",
    "would", "will", "shall", "must", "the", "a", "an", "to", "if",
}
_TAIL_EXCLUDE = {
    "file", "files", "path", "dir", "directory", "sock", "socket", "name",
    "names", "id", "ids", "url", "uri", "endpoint", "host", "port", "type",
    "ttl", "expiry", "expires", "expiration", "length", "len", "limit", "max",
    "min", "prompt", "cmd", "command", "helper", "policy", "env", "stdin",
    "fd", "method", "budget", "hash", "count", "size", "format", "version",
    "enabled", "required", "regex", "pattern", "field", "header", "var",
    "variable", "scope", "scopes", "store", "manager", "provider", "location",
    "timeout", "lifetime", "age", "algorithm", "alg", "rotation", "source",
    "mode", "kind", "label", "prefix", "suffix", "usage", "used", "date",
    "time", "timestamp", "at", "status", "state", "duration", "index",
    "total", "cost", "rate", "window", "threshold", "estimate", "counter",
    "src", "origin", "hint", "help", "message", "msg", "description", "desc",
    "error", "errors", "warning", "title", "text",
    # Adjectives and flags about a credential, and the code that handles one.
    "visible", "hidden", "valid", "invalid", "missing", "present", "exists",
    "set", "needed", "optional", "changed", "updated", "created", "expired",
    "param", "parameter", "arg", "flag", "option", "options", "repository",
    "repo", "emulator", "service", "client", "handler", "controller",
    "factory", "builder", "resolver", "validator", "generator", "parser",
    "reader", "writer", "loader", "class", "interface", "impl", "test",
    "tests", "spec", "mock", "stub",
}
# A name starting with one of these is an action or a switch.
_HEAD_EXCLUDE = {
    "no", "ask", "prompt", "with", "show", "print", "generate", "create",
    "revoke", "list", "get", "use", "require", "enable", "disable", "skip",
    "max", "min", "num", "count", "total", "has", "is", "allow", "deny",
    "without", "ignore", "check", "validate", "verify", "rotate", "reset",
    "forgot", "change", "input", "output", "completion", "prompt",
}
_ANY_EXCLUDE = {"public", "publishable", "pub", "anon", "anonymous", "example"}

_FUSED_SUFFIX = ("password", "passwd", "passphrase", "secret", "token", "apikey")

_CAMEL = re.compile(r"[A-Z]+(?=[A-Z][a-z])|[A-Z]?[a-z]+|[A-Z]+|\d+")


def name_tokens(name):
    """Split a flag, variable or JSON key into lower-case words."""
    out = []
    for part in re.split(r"[^A-Za-z0-9]+", name):
        if not part:
            continue
        if part.isupper() or part.islower():
            out.append(part.lower())
        else:
            out.extend(m.group(0).lower() for m in _CAMEL.finditer(part))
    return out


def key_class(name, url_query=False):
    """Return 'strong', 'weak' or None for a key, flag or variable name.

    `url_query` admits `sig` and `signature`, which are credentials in a
    signed URL and ordinary fields everywhere else (a transcript is full of
    signature fields that are not secrets).

    The word that makes a name a credential is also the last word of many
    names that are not one, and those are declined here by what stands
    beside it: a token that says where a listing stopped (`next_token`,
    `page_token`), a key that names, sorts or routes something
    (`routing_key`, `sort_key`, `kms_key_id`, git's `user.signingKey`), a
    pass that is a stage (`compiler_pass`). A qualified key is strong when
    the qualifier says what it unlocks (`service_role_key`, `sdk_key`) and
    weak when it says nothing, as long as the name ends on `key`.

    A name written with spaces is a label when it is a short noun phrase
    (`AWS Secret Access Key`, as a vault export or an API collection
    writes it) and is not classed when it reads as a clause: more than
    five words, a question mark, or a question word, an article or an
    auxiliary verb among them. That is a question stored with its answer.
    """
    toks = name_tokens(name)
    if not toks or len(toks) > 8:
        return None
    spaced = len(name.split())
    if spaced > 1 and (spaced > 5 or "?" in name or set(toks) & _CLAUSE_WORDS):
        return None  # a clause used as a key - a question and its answer
    if any(t in _ANY_EXCLUDE for t in toks):
        return None
    if toks[-1] in _TAIL_EXCLUDE:
        return None
    if len(toks) > 1 and toks[0] in _HEAD_EXCLUDE:
        return None
    if toks == ["pwd"]:  # the shell variable, not a password
        return None
    tokset = set(toks)
    if toks == ["user", "signing", "key"]:
        return None  # git's user.signingKey names a key; it does not hold one
    named = {t for t in toks if t in _STRONG_SINGLE or t.endswith(_FUSED_SUFFIX)}
    if named and named <= {"token", "tokens"} and tokset & _TOKEN_NOT_CREDENTIAL:
        return None  # --next-token: where a listing stopped
    if "pwd" in tokset and len(toks) > 1:
        return "strong"
    # Fused names carry no separator to split on: PGPASSWORD, dbpasswd.
    if any(t.endswith(_FUSED_SUFFIX) for t in toks) or "sshpass" in tokset:
        return "strong"
    strong = tokset & _STRONG_SINGLE
    if strong == {"pass"}:
        at = toks.index("pass")
        if (at and toks[at - 1] in _PASS_BEFORE) or \
                (at + 1 < len(toks) and toks[at + 1] in _PASS_AFTER):
            strong = set()
    if strong:
        # "tokens" as a count ("max_tokens") is excluded by head/tail above;
        # a bare plural with a numeric neighbour is a quantity.
        return "strong"
    for a, b in zip(toks, toks[1:]):
        if (a, b) in _STRONG_PAIRS:
            return "strong"
    if "hmac" in tokset and "key" in tokset:
        return "strong"
    # A weak word names the value only when the name ends on it: "auth" and
    # "basic_auth" may hold one, "authUserLookup" is a thing that does auth.
    if toks[-1] in _WEAK_SINGLE:
        return "weak"
    # A longer name that ends on "key" is a vendor's name for one
    # (ACME_SERVICE_ROLE_KEY); a longer name with "key" inside it is not.
    if "key" in tokset and (len(toks) <= 2 or toks[-1] == "key") \
            and not (tokset & _KEY_NOT_CREDENTIAL):
        return "weak"
    if url_query and tokset & {"sig", "signature"}:
        return "weak"
    return None


def safe_name(name):
    """A key or flag name that is safe to print: bounded, plain characters.

    A name is printed in findings, so anything that is not shaped like a
    name is withheld whole. It is never cut or filtered into something
    printable: a value mis-parsed into name position would come out as a
    fragment that no longer matches the value, and so could not be scrubbed.
    """
    cleaned = re.sub(r"[^A-Za-z0-9_.\-]", "", name)
    if not cleaned or len(cleaned) > 40 or looks_random(name):
        return "<name>"
    return cleaned


def looks_random(s):
    """Token-shaped rather than name-shaped. Either of two tells is enough.

    Letters and digits interleaved: `OAUTH2_CLIENT_ID` and `sha256sum`
    change kind once or twice, a generated value does it over and over.

    Mixed case that breaks into scraps: a camelCase name splits into words
    (`maxOutputTokens`), random mixed case and base64 split into pieces of
    one and two letters. Three such pieces is the line - `getIdOfUser` has
    two. About one random 16-letter value in five has fewer and reads as
    a name; nothing here can tell those apart, and every caller treats
    "random" as the cautious answer.
    """
    if len(s) < 8:
        return False
    flips = sum(1 for a, b in zip(s, s[1:])
                if a.isalnum() and b.isalnum() and a.isdigit() != b.isdigit())
    if flips >= 4:
        return True
    scraps = 0
    for seg in re.split(r"[^A-Za-z0-9]+", s):
        if seg.islower() or seg.isupper():
            continue
        scraps += sum(1 for m in _CAMEL.finditer(seg)
                      if m.group(0).isalpha() and len(m.group(0)) <= 2)
    return scraps >= 3


# --------------------------------------------------------------------------
# Value classification: is this VALUE a literal, or a reference to one?
# --------------------------------------------------------------------------

LITERAL = "literal"
ENV_REF = "env-ref"
COMMAND_SUB = "command-sub"
FILE_REF = "file-ref"
PLACEHOLDER = "placeholder"
WILDCARD = "wildcard"
DEFAULT = "default"
EMPTY = "empty"

_DEFAULT_VALUES = {
    "postgres", "password", "passwd", "pass", "root", "admin", "changeme",
    "change-me", "changeit", "secret", "test", "testing", "guest", "user",
    "example", "demo", "default", "none", "null", "nil", "true", "false",
    "yes", "no", "foo", "bar", "baz", "qwerty", "letmein", "mysql", "redis",
    "mongo", "docker", "localhost", "dev", "development", "local", "token",
    "key", "apikey", "string", "value", "undefined", "todo", "tbd", "n/a",
    "on", "off", "enabled", "disabled", "basic", "bearer", "anonymous",
}
_PLACEHOLDER_WORDS = re.compile(
    r"(?i)(redacted|example|dummy|placeholder|changeme|your[_\-]|"
    r"(?<![a-z])x{3,}(?![a-z])|\*\*\*+|\.\.\.|fake|sample|insert|replace|"
    r"<[a-z][\w \-]*>|\bhere\b|notreal|not[_\-]a[_\-]real|"
    r"(?<![a-z])todo(?![a-z])|masked|hidden|elided|omitted)"
)
# What the shell lexer puts where a quoted or escaped "$" or backquote stood.
# Inside single quotes the shell expands nothing, so the character is part of
# the value; these keep it from being read as the start of a reference. They
# are private-use code points and are turned back before a hit leaves the
# command scanner.
_LIT_DOLLAR, _LIT_TICK = "\ue000", "\ue001"


def _lit(s):
    """Mark every `$` and backquote in `s` as literal text."""
    return s.replace("$", _LIT_DOLLAR).replace("`", _LIT_TICK)


def _unlit(s):
    """Undo `_lit`. Applied to every sink and value before it is returned,
    and to a nested command string before it is lexed again."""
    return s.replace(_LIT_DOLLAR, "$").replace(_LIT_TICK, "`")


_QUOTED_REF = re.compile(
    r"(?<![A-Za-z0-9])(?:\$\{[A-Za-z_]\w*\}|\$[A-Z_][A-Z0-9_]*)(?![A-Za-z0-9])")


def _path_shaped(v):
    """A leading "/" is a path only if the rest reads like one. Base64 can
    start with a slash too, and it gives itself away by its padding, its
    "+" or a short run of segments that look random."""
    if re.search(r"[+=]", v):
        return False
    segs = [seg for seg in v.split("/") if seg]
    return len(segs) > 2 or not any(looks_random(seg) for seg in segs)


_SELF_NAMING = {"key", "secret", "token", "password", "passphrase", "credential",
                "credentials", "apikey", "passwd"}
_ENV_REF = re.compile(
    r"^(\$[A-Za-z_][A-Za-z0-9_]*|\$\{[^}]*\}|%[A-Za-z_][A-Za-z0-9_]*%|"
    r"\$\{\{.*\}\}|\{\{.*\}\}|\$env:[A-Za-z_]\w*|env:[A-Za-z_]\w*|\$\d|\$[@*#?!])$"
)
_KEYFILE_EXT = (
    ".pem", ".key", ".crt", ".cer", ".p12", ".pfx", ".jks", ".json", ".txt",
    ".env", ".toml", ".yaml", ".yml", ".conf", ".cfg", ".ini", ".netrc",
    ".asc", ".gpg", ".pub", ".kdbx",
)
AUTH_SCHEME = re.compile(
    r"^(?:Bearer|Basic|Token|Digest|Negotiate|ApiKey|Api-Key|Key|SSWS|OAuth|JWT|PRIVATE-TOKEN)(?:[ :=]+|$)",
    re.I,
)
_SECRET_SCHEMES = (
    "op://", "vault:", "file:", "env:", "keychain:", "pass:", "aws-sm:",
    "gcp-sm:", "azure-kv:", "sops:", "doppler:", "bw:", "keyring:",
)


def value_class(value):
    """Classify a value that sits in a credential-bearing position.

    Only LITERAL is a finding. Everything else is how a credential is meant
    to be passed, or is plainly not a real one.
    """
    v = value.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
        v = v[1:-1].strip()
    if not v:
        return EMPTY
    if _LIT_DOLLAR in v or _LIT_TICK in v:
        # Single-quoted or escaped, so nothing here is expanded. The one
        # thing still read as a reference is a value that is nothing but a
        # conventionally named variable: a quoting slip, not a credential.
        plain = _unlit(v)
        if (plain.startswith("$(") and plain.endswith(")")) or \
                (len(plain) > 2 and plain[0] == plain[-1] == "`"):
            return COMMAND_SUB
        bare = AUTH_SCHEME.sub("", plain)
        if re.match(r"^\$[A-Za-z_]+$", bare):
            return ENV_REF
        rest = _QUOTED_REF.sub("", plain)
        if rest != plain and \
                len(re.sub(r"[^A-Za-z0-9]", "", AUTH_SCHEME.sub("", rest.strip()))) < 6:
            return ENV_REF
    # A harness may store an approved command with its parentheses escaped.
    v = v.replace("$\\(", "$(").replace("<\\(", "<(")
    if v in ("*", ":*", "**", "*:*") or v.endswith(":*") and len(v) <= 3:
        return WILDCARD
    if v.startswith("$(") or v.startswith("`") or v.startswith("<("):
        return COMMAND_SUB
    if _ENV_REF.match(v):
        return ENV_REF
    # A value that is mostly a reference with decoration: "Bearer $TOKEN".
    stripped = re.sub(r"\$\{[^}]*\}|\$\([^)]*\)|`[^`]*`|\$[A-Za-z_]\w*|\{\{[^}]*\}\}", "", v)
    stripped = AUTH_SCHEME.sub("", stripped.strip())
    if stripped != v and len(re.sub(r"[^A-Za-z0-9]", "", stripped)) < 6:
        return ENV_REF if "$(" not in v and "`" not in v else COMMAND_SUB
    low = v.lower()
    if v == "-" or low.startswith(_SECRET_SCHEMES):
        return FILE_REF
    if v[0] == "@" and len(v) > 1:
        return FILE_REF
    if v.startswith(("/dev/", "~/", "./", "../")) and " " not in v:
        return FILE_REF
    if v[0] == "/" and " " not in v and _path_shaped(v):
        return FILE_REF
    if re.match(r"^[A-Za-z]:[\\/]", v):
        return FILE_REF
    if low.endswith(_KEYFILE_EXT) and re.match(r"^[\w.\-/\\~]+$", v):
        return FILE_REF
    if len(set(v)) == 1 or not set(re.sub(r"[^A-Za-z0-9]", "", v)) - set("xX"):
        return PLACEHOLDER
    # A date or a timestamp sitting under a credential-sounding name
    # ("tokenIssued", "passwordChanged") is bookkeeping, not the credential.
    if re.match(r"^\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+\-]\d{2}:?\d{2})?)?$", v):
        return PLACEHOLDER
    if (v.startswith("<") and v.endswith(">")) or (v.startswith("__") and v.endswith("__")):
        return PLACEHOLDER
    if (v.startswith("[") and v.endswith("]")) or (v.startswith("{") and v.endswith("}")):
        return PLACEHOLDER
    if _PLACEHOLDER_WORDS.search(v):
        return PLACEHOLDER
    # Plain words that say what they stand for: dev-signing-key,
    # some_api_token. A passphrase of words does not name its own kind.
    if re.match(r"^[a-z]+(?:[-_][a-z]+)+$", v) and _SELF_NAMING & set(re.split(r"[-_]", v)):
        return PLACEHOLDER
    # An upper-snake name where a value should be is a variable written
    # without its sigil, or a template slot: TOKEN, API_KEY, GITHUB_TOKEN.
    # A long unbroken run with digits scattered through it is not a name:
    # that is the shape of a cloud access key id or a base32 seed.
    if re.match(r"^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$", v) and not re.search(r"\d{3,}", v):
        if "_" in v or len(v) < 16 or sum(c.isdigit() for c in v) < 2:
            return PLACEHOLDER
    if low in _DEFAULT_VALUES or re.match(r"^\d{1,6}$", v):
        return DEFAULT
    return LITERAL


def char_classes(v):
    return sum(bool(re.search(p, v)) for p in (r"[a-z]", r"[A-Z]", r"\d", r"[^A-Za-z0-9]"))


# A UUID, or a short tag and a digest ("v1:9f2c..."), under a vague name is
# an identifier or a content hash.
_IDENTIFIER_SHAPE = re.compile(
    r"(?i)^(?:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|\w{1,8}:[0-9a-f]{16,})$"
)


def plausible_secret(v, strength):
    """Shape guard for the embedded tier, where the sink itself is a guess."""
    v = v.strip("'\"")
    if strength == "strong":
        return len(v) >= 6
    # Separators are not entropy: "my.feature.enabled" is a name, and a
    # name is what usually sits under a key as vague as "key" or "auth".
    if _IDENTIFIER_SHAPE.match(v):
        return False
    mixed = sum(bool(re.search(p, v)) for p in (r"[a-z]", r"[A-Z]", r"\d"))
    return len(v) >= 16 and mixed >= 2 and " " not in v


# --------------------------------------------------------------------------
# Known-prefix tokens: a credential recognisable with no context at all.
# --------------------------------------------------------------------------

_B = r"(?<![A-Za-z0-9_\-])"
_E = r"(?![A-Za-z0-9_\-])"
_PREFIX_PATTERNS = [
    ("Anthropic API key", r"sk-ant-[A-Za-z0-9_\-]{20,}"),
    ("OpenAI API key", r"sk-(?:proj-|svcacct-|admin-)?[A-Za-z0-9_\-]{32,}"),
    ("GitHub token", r"gh[pousr]_[A-Za-z0-9]{30,}"),
    ("GitHub fine-grained token", r"github_pat_[A-Za-z0-9_]{40,}"),
    ("GitLab token", r"gl(?:pat|dt|rt|cbt|ptt|soat)-[A-Za-z0-9_\-]{20,}"),
    ("Slack token", r"xox[abeoprs]-[A-Za-z0-9\-]{10,}"),
    ("Slack app token", r"xapp-\d-[A-Za-z0-9\-]{20,}"),
    ("AWS access key id", r"(?:AKIA|ASIA|ABIA|ACCA)[A-Z2-7]{16}"),
    ("Google API key", r"AIza[A-Za-z0-9_\-]{35}"),
    ("Google OAuth token", r"ya29\.[A-Za-z0-9_\-]{20,}"),
    ("npm token", r"npm_[A-Za-z0-9]{36}"),
    ("PyPI token", r"pypi-AgE[A-Za-z0-9_\-]{40,}"),
    ("Stripe live key", r"[sr]k_live_[A-Za-z0-9]{20,}"),
    ("Stripe webhook secret", r"whsec_[A-Za-z0-9]{24,}"),
    ("SendGrid key", r"SG\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}"),
    ("Hugging Face token", r"hf_[A-Za-z0-9]{30,}"),
    ("DigitalOcean token", r"do[por]_v1_[a-f0-9]{40,}"),
    ("Tailscale key", r"tskey-[a-z]+-[A-Za-z0-9\-]{16,}"),
    ("Docker Hub token", r"dckr_pat_[A-Za-z0-9_\-]{20,}"),
    ("YouTrack permanent token", r"perm[:\-][A-Za-z0-9+/=._\-]{24,}"),
    ("Linear API key", r"lin_api_[A-Za-z0-9]{30,}"),
    ("Notion token", r"(?:secret|ntn)_[A-Za-z0-9]{40,}"),
    ("Vercel token", r"vc[pkiar]_[A-Za-z0-9]{24,}"),
    ("Cloudflare API token", r"cfut_[A-Za-z0-9_\-]{30,}"),
    ("Shopify token", r"shp(?:at|ca|pa|ss)_[a-fA-F0-9]{32}"),
    ("Twilio key", r"SK[a-f0-9]{32}"),
    ("Mailgun key", r"key-[a-f0-9]{32}"),
    ("Databricks token", r"dapi[a-f0-9]{32}"),
    ("Sentry token", r"sntr[ysu]_[A-Za-z0-9_\-=]{30,}"),
    ("Supabase access token", r"sbp_[a-f0-9]{40}"),
    ("Supabase secret key", r"sb_secret_[A-Za-z0-9_\-]{20,}"),
    ("Vault token", r"hv[sbr]\.[A-Za-z0-9_\-]{20,}"),
    ("Groq API key", r"gsk_[A-Za-z0-9]{48,}"),
    ("Perplexity API key", r"pplx-[A-Za-z0-9]{40,}"),
    ("Replicate token", r"r8_[A-Za-z0-9]{36,}"),
    ("age secret key", r"AGE-SECRET-KEY-1[A-Z0-9]{50,}"),
]
PREFIX_TOKENS = [(label, re.compile(_B + pat + _E)) for label, pat in _PREFIX_PATTERNS]
# A prefix followed by words is a branch, a table or a rule that happens to
# start the same way: sk-refactor-the-parser. A generated token is not made
# of lower-case words.
_SLUG = re.compile(r"^[A-Za-z]+(?:[-_.:](?:[a-z]+|\d{1,4}))*$")
_PEM_HEAD = r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY(?: BLOCK)?-----"
# The header alone is what a detector's own pattern list or a document about
# key formats contains. A key has a body after it.
_PEM = re.compile(_PEM_HEAD + r"""(?:\\[nr]|[\s"',+])*(?:[A-Za-z0-9+/=]{24,}|Proc-Type|Version:|Comment:)""")
_PEM_START = re.compile(_PEM_HEAD + r"\s*$")
_JWT = re.compile(_B + r"eyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}" + _E)
_WEBHOOK = re.compile(
    r"https://(?:hooks\.slack\.com/services/T[A-Za-z0-9]+/B[A-Za-z0-9]+/[A-Za-z0-9]{16,}"
    r"|(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_\-]{30,})"
)


def prefix_hits(text):
    """Yield (label, severity, matched_value) for recognisable tokens in text.

    A match made only of words and short numbers joined by separators is
    a slug - a branch or a table that happens to start with a vendor's
    prefix - and is not yielded.
    """
    if len(text) < 12:
        return
    for label, rx in PREFIX_TOKENS:
        for m in rx.finditer(text):
            if value_class(m.group(0)) == LITERAL and not _SLUG.match(m.group(0)):
                yield label, HIGH, m.group(0)
    for m in _PEM.finditer(text):
        yield "PEM private key", HIGH, text[m.start():m.start() + 160]
    for m in _WEBHOOK.finditer(text):
        yield "webhook URL with embedded secret", HIGH, m.group(0)
    for m in _JWT.finditer(text):
        yield "JSON Web Token", MEDIUM, m.group(0)


# --------------------------------------------------------------------------
# Shell lexer: enough of POSIX sh to find words, commands and substitutions.
# It never executes or expands anything, and it tolerates truncated input,
# because a stored permission rule is often a prefix cut mid-quote.
# --------------------------------------------------------------------------

def _match_paren(s, i):
    """Index of the ')' closing a group whose body starts at i, or len(s)."""
    depth, n = 1, len(s)
    while i < n:
        c = s[i]
        if c == "\\":
            i += 2
            continue
        if c == "'":
            j = s.find("'", i + 1)
            i = n if j < 0 else j + 1
            continue
        if c == '"':
            i += 1
            while i < n and s[i] != '"':
                i += 2 if s[i] == "\\" else 1
            i += 1
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return n


def _new_cmd(sep):
    return {"words": [], "sep": sep, "stdin": None, "heredoc": None}


def split_commands(s, subs=None):
    """Split a command line into simple commands.

    Returns a list of {"words", "sep", "stdin", "heredoc"}; `sep` is the
    operator that preceded the command ("|" marks a pipeline stage). Command
    and process substitutions stay raw inside their word, and their bodies
    are appended to `subs` for the caller to scan in turn.

    Quotes are removed, as the shell removes them, with one thing kept: a
    "$" or backquote that was single-quoted or escaped comes back as a
    private marker (see `_lit`), so `'Pa$$w0rd'` is not later mistaken for
    a reference to a variable.
    """
    if subs is None:
        subs = []
    cmds, cmd = [], _new_cmd("")
    cur, has, pending = [], False, None  # pending: None | "redir" | "herestring" | "heredoc"
    heredocs = []
    i, n = 0, len(s)

    def end_word():
        nonlocal cur, has, pending
        if not has:
            return
        word = "".join(cur)
        cur, has = [], False
        if pending == "redir":
            pass
        elif pending == "herestring":
            cmd["stdin"] = word
        elif pending == "heredoc":
            heredocs.append((word.lstrip("-"), cmd))
        else:
            cmd["words"].append(word)
        pending = None

    def end_cmd(sep):
        nonlocal cmd
        end_word()
        if cmd["words"] or cmd["stdin"] or cmd["heredoc"]:
            cmds.append(cmd)
        cmd = _new_cmd(sep)

    while i < n:
        c = s[i]
        if c in " \t":
            end_word()
            i += 1
        elif c == "\n":
            end_word()
            i += 1
            for delim, owner in heredocs:
                body = []
                while i < n:
                    j = s.find("\n", i)
                    line = s[i:] if j < 0 else s[i:j]
                    i = n if j < 0 else j + 1
                    if line.strip() == delim:
                        break
                    body.append(line)
                owner["heredoc"] = "\n".join(body)
            heredocs = []
            end_cmd(";")
        elif c == ";":
            end_cmd(";")
            i += 2 if s[i:i + 2] == ";;" else 1
        elif c == "|":
            if s[i:i + 2] == "||":
                end_cmd("||")
                i += 2
            else:
                end_cmd("|")
                i += 2 if s[i:i + 2] == "|&" else 1
        elif c == "&":
            if s[i:i + 2] == "&&":
                end_cmd("&&")
                i += 2
            elif s[i:i + 2] == "&>":
                end_word()
                pending = "redir"
                i += 3 if s[i:i + 3] == "&>>" else 2
            else:
                end_cmd("&")
                i += 1
        elif c in "()" and not has:
            end_cmd("(")
            i += 1
        elif c == ")":
            end_cmd("(")
            i += 1
        elif c == "#" and not has:
            j = s.find("\n", i)
            i = n if j < 0 else j
        elif c in "<>":
            if s[i + 1:i + 2] == "(":  # process substitution
                j = _match_paren(s, i + 2)
                subs.append(s[i + 2:j])
                cur.append(s[i:j + 1])
                has = True
                i = j + 1
                continue
            if has and "".join(cur).isdigit():
                cur, has = [], False
            end_word()
            if s[i:i + 3] == "<<<":
                pending, i = "herestring", i + 3
            elif s[i:i + 2] == "<<":
                pending, i = "heredoc", i + 2
                if s[i:i + 1] == "-":
                    i += 1
            else:
                pending = "redir"
                i += 1
                while i < n and s[i] in "<>&|":
                    i += 1
                # "2>&1": the fd after >& is part of the operator.
                if s[i - 1:i] == "&":
                    while i < n and (s[i].isdigit() or s[i] == "-"):
                        i += 1
                    pending = None
        elif c == "\\":
            if s[i + 1:i + 2] == "\n":
                i += 2
            else:
                cur.append(_lit(s[i + 1:i + 2]))
                has = True
                i += 2
        elif c == "'":
            j = s.find("'", i + 1)
            if j < 0:
                j = n
            cur.append(_lit(s[i + 1:j]))
            has = True
            i = j + 1
        elif s[i:i + 2] == "$'":
            # ANSI-C quoting: a single-quoted string that honours backslash.
            j = i + 2
            while j < n and s[j] != "'":
                j += 2 if s[j] == "\\" else 1
            body = re.sub(r"\\(['\"\\])", r"\1", s[i + 2:j])
            cur.append(_lit(body))
            has = True
            i = j + 1
        elif s[i:i + 2] == '$"':
            i += 1  # locale quoting: an ordinary double-quoted string
        elif c == '"':
            has = True
            i += 1
            while i < n and s[i] != '"':
                if s[i] == "\\" and i + 1 < n:
                    if s[i + 1] in '"\\$`\n':
                        if s[i + 1] != "\n":
                            cur.append(_lit(s[i + 1]))
                    else:
                        cur.append(s[i:i + 2])
                    i += 2
                elif s[i:i + 2] == "$(":
                    j = _match_paren(s, i + 2)
                    subs.append(s[i + 2:j])
                    cur.append(s[i:j + 1])
                    i = j + 1
                elif s[i] == "`":
                    j = s.find("`", i + 1)
                    if j < 0:
                        j = n
                    subs.append(s[i + 1:j])
                    cur.append(s[i:j + 1])
                    i = j + 1
                else:
                    cur.append(s[i])
                    i += 1
            i += 1
        elif s[i:i + 2] == "$(":
            j = _match_paren(s, i + 2)
            subs.append(s[i + 2:j])
            cur.append(s[i:j + 1])
            has = True
            i = j + 1
        elif s[i:i + 2] == "${":
            j = s.find("}", i)
            if j < 0:
                j = n - 1
            cur.append(s[i:j + 1])
            has = True
            i = j + 1
        elif c == "`":
            j = s.find("`", i + 1)
            if j < 0:
                j = n
            subs.append(s[i + 1:j])
            cur.append(s[i:j + 1])
            has = True
            i = j + 1
        else:
            cur.append(c)
            has = True
            i += 1
    end_cmd("")
    return cmds


# --------------------------------------------------------------------------
# Program table: flags and positions that carry a credential by definition.
#
# A short flag is a sink only through this table. `-p` is a password to
# `docker login` and a port to `docker run`, and `-u` is a credential to curl
# and a timezone to date, so no short flag is ever guessed at.
#
# Value kinds:
#   value     the whole argument is the credential
#   userpass  user:password        (curl -u)
#   certpass  certificate:password (curl -E); a bare path carries none
#   pct       user%password        (smbclient -U)
#   comma     user,password        (lftp -u)
#   slash     user/password@db     (sqlplus)
#   passarg   openssl's pass:VALUE; env:, file:, fd: and stdin are references
#   header    an HTTP header line, scanned for credential-bearing headers
#   cookie    name=value pairs are literal cookies; anything else is a file
#   kv        NAME=value, a sink only when NAME says credential
#   anykv     NAME=value, a sink whatever the name (a secret store's own CLI)
#
# An entry applies only when every flag in `requires` is present and none in
# `unless` is: `htpasswd file user password` takes a password only with -b,
# and -n removes the file argument and moves it one place left. A flag that
# closes a cluster of short flags (`curl -sSu`) is matched as if it stood
# alone, and a flag-shaped next word is never taken as a value.
# --------------------------------------------------------------------------

PROGRAMS = {}


def _P(names, when=(), flags=None, attached=(), attached_only=(), eq_only=(),
       booleans=(), valflags=(), positional=None, rest=None, requires=(),
       unless=(), prefix=None):
    entry = {
        "when": tuple(when), "flags": flags or {}, "attached": set(attached),
        "attached_only": set(attached_only), "eq_only": set(eq_only),
        "booleans": set(booleans), "valflags": set(valflags),
        "positional": positional or {}, "rest": rest,
        "requires": tuple(requires.split()) if isinstance(requires, str) else tuple(requires),
        "unless": tuple(unless.split()) if isinstance(unless, str) else tuple(unless),
        "prefix": prefix or {},
    }
    for name in names.split():
        PROGRAMS.setdefault(name, []).append(entry)


_P("curl", flags={
    "-u": "userpass", "--user": "userpass", "-U": "userpass",
    "--proxy-user": "userpass", "--oauth2-bearer": "value", "--pass": "value",
    "--proxy-pass": "value", "-E": "certpass", "--cert": "certpass",
    "-H": "header", "--header": "header", "--proxy-header": "header",
    "-b": "cookie", "--cookie": "cookie", "--aws-sigv4": None,
}, attached={"-u", "-U", "-E", "-H", "-b"})
_P("wget", flags={
    "--password": "value", "--http-password": "value", "--ftp-password": "value",
    "--proxy-password": "value", "--header": "header",
})
_P("http https xh", flags={"-a": "userpass", "--auth": "userpass"},
   valflags={"--auth-type", "-A"})
_P("mysql mysqldump mysqladmin mysqlimport mysqlcheck mysqlshow mysqlsh "
   "mariadb mariadb-dump mariadb-admin mycli",
   flags={"-p": "value", "--password": "value"},
   attached_only={"-p"}, eq_only={"--password"})
_P("psql pg_dump pg_dumpall pg_restore pg_basebackup pg_isready createdb "
   "dropdb createuser dropuser pgbench vacuumdb reindexdb clusterdb pgcli",
   booleans={"--password", "-W", "--no-password", "-w"})
_P("sshpass", flags={"-p": "value"}, attached={"-p"})
_P("redis-cli valkey-cli", flags={"-a": "value", "--pass": "value"})
_P("mongosh mongo mongodump mongorestore mongoexport mongoimport mongostat mongotop",
   flags={"-p": "value", "--password": "value", "--awsSecretAccessKey": "value",
          "--awsSessionToken": "value"})
_P("docker podman nerdctl", when=("login",),
   flags={"-p": "value", "--password": "value"}, attached={"-p"},
   valflags={"--config", "-H", "--host", "--context", "-c", "-l", "--log-level"})
_P("docker podman nerdctl", flags={
    "-e": "kv", "--env": "kv", "--build-arg": "kv", "--secret": None,
}, attached={"-e"})
_P("docker-compose", flags={"-e": "kv", "--env": "kv", "--build-arg": "kv"})
_P("helm", when=("registry", "login"), flags={"-p": "value", "--password": "value"})
_P("helm", flags={"--password": "value", "--set": "kv", "--set-string": "kv"})
_P("kubectl oc", flags={
    "--from-literal": "anykv", "--token": "value", "--password": "value",
    "--docker-password": "value",
})
_P("gh", when=("secret", "set"), flags={"-b": "value", "--body": "value"},
   valflags={"-R", "--repo"})
_P("gh", when=("variable", "set"), flags={})
_P("gh glab", flags={"-H": "header", "--header": "header"})
_P("openssl", flags={
    "-passin": "passarg", "-passout": "passarg", "-pass": "passarg",
    "-password": "passarg", "-k": "value", "-K": "value",
})
_P("zip unzip", flags={"-P": "value", "--password": "value"}, attached={"-P"})
_P("7z 7za 7zr 7zz", flags={"-p": "value"}, attached_only={"-p"})
_P("rar unrar", flags={"-p": "value", "-hp": "value"}, attached_only={"-p", "-hp"})
_P("htpasswd", requires="-b", unless="-n", positional={2: "value"})
# -n prints the result instead of writing a file, so no file is named.
_P("htpasswd", requires="-b -n", positional={1: "value"})
_P("mosquitto_pub mosquitto_sub mosquitto_rr", flags={"-P": "value", "--pw": "value"})
_P("smbclient smbmap rpcclient", flags={"-U": "pct", "--user": "pct",
                                         "--password": "value", "-p": None})
_P("ldapsearch ldapadd ldapmodify ldapdelete ldapwhoami ldappasswd",
   flags={"-w": "value", "-s": None})
_P("sqlcmd bcp isql tsql", flags={"-P": "value"}, attached={"-P"})
_P("lftp", flags={"-u": "comma", "--user": "comma", "--password": "value"})
_P("sqlplus sqlldr expdp impdp rman", positional={0: "slash"}, valflags={"-L"})
_P("vault", when=("login",), positional={0: "value"},
   valflags={"-method", "-path", "-address", "-namespace"})
_P("vault", when=("kv", "put"), rest=(1, "anykv"), valflags={"-mount", "-cas"})
_P("vault", when=("kv", "patch"), rest=(1, "anykv"), valflags={"-mount", "-cas"})
_P("vault", when=("write",), rest=(1, "anykv"))
_P("cargo", when=("login",), positional={0: "value"}, valflags={"--registry"})
_P("ngrok", when=("authtoken",), positional={0: "value"})
_P("ngrok", when=("config", "add-authtoken"), positional={0: "value"})
_P("npm pnpm yarn", when=("config", "set"), positional={0: "name", 1: "namevalue"},
   rest=(0, "kv"))
_P("npm pnpm yarn", when=("set",), positional={0: "name", 1: "namevalue"}, rest=(0, "kv"))
_P("aws", when=("configure", "set"), positional={0: "name", 1: "namevalue"},
   valflags={"--profile", "--region"})
_P("poetry", when=("config",), positional={0: "name", 1: "namevalue"})
_P("pip pip3 uv", flags={"--index-url": None, "--extra-index-url": None})
_P("netlify", when=("env:set",), positional={1: "value"})
_P("heroku", when=("config:set",), rest=(0, "anykv"), valflags={"-a", "--app", "-r"})
_P("fly flyctl", when=("secrets", "set"), rest=(0, "anykv"),
   valflags={"-a", "--app", "-c", "--config"})
_P("doppler", when=("secrets", "set"), rest=(0, "anykv"), positional={1: "value"},
   valflags={"-p", "--project", "-c", "--config"})
_P("supabase", when=("secrets", "set"), rest=(0, "anykv"), valflags={"--project-ref"})
_P("railway", when=("variables", "set"), rest=(0, "anykv"))
_P("railway", when=("variables",), flags={"--set": "anykv"})
_P("vercel", when=("env", "add"), positional={})
_P("twine", flags={"-p": "value", "--password": "value"})
_P("poetry", when=("publish",), flags={"-p": "value", "--password": "value"})
_P("mc mcli", when=("alias", "set"), positional={2: "value", 3: "value"})
_P("mc mcli", when=("config", "host", "add"), positional={2: "value", 3: "value"})
_P("rabbitmqctl", when=("add_user",), positional={1: "value"})
_P("rabbitmqctl", when=("change_password",), positional={1: "value"})
_P("rabbitmqadmin", flags={"-p": "value", "--password": "value"})
_P("plink pscp psftp putty", flags={"-pw": "value"})
_P("xfreerdp xfreerdp3 wlfreerdp", prefix={"/p:": "value", "/gp:": "value"})
_P("rdesktop", flags={"-p": "value"})
_P("az", when=("login",), flags={"-p": "value", "--password": "value",
                                 "--federated-token": "value"})
_P("az", flags={"--password": "value", "--client-secret": "value",
                "--account-key": "value", "--sas-token": "value",
                "--connection-string": "value", "--admin-password": "value"})
# --secret and --set-secrets name a stored secret; they do not carry one.
_P("gcloud", flags={"--password": "value", "--access-token-file": None,
                    "--cred-file": None, "--secret": None, "--secrets": None,
                    "--set-secrets": None, "--update-secrets": None,
                    "--remove-secrets": None})
_P("etcdctl", flags={"--user": "userpass", "--password": "value"})
_P("influx", flags={"-t": "value", "--token": "value", "-p": "value",
                    "--password": "value"})
_P("cqlsh", flags={"-p": "value", "--password": "value"})
_P("dotnet", when=("nuget", "push"), flags={"-k": "value", "--api-key": "value",
                                            "-sk": "value", "--symbol-api-key": "value"})
_P("dotnet", when=("nuget",), flags={"-p": "value", "--password": "value"})
_P("nuget", flags={"-p": "value", "-Password": "value", "-password": "value",
                   "-ApiKey": "value", "-apikey": "value"})
_P("nuget", when=("setapikey",), positional={0: "value"})
_P("conan", when=("user",), flags={"-p": "value", "--password": "value"})
_P("conan", when=("remote", "login"), flags={"-p": "value", "--password": "value"})
_P("snowsql", flags={"--private-key-path": None})
_P("net", when=("use",), positional={2: "value"}, prefix={"/user:": None})
_P("expect", flags={})
_P("git", flags={"-c": "kv"})
_P("ansible ansible-playbook", flags={"-e": "kv", "--extra-vars": "kv"})
_P("terraform tofu", flags={"-var": "kv"})
_P("gradle gradlew mvn mvnw", prefix={"-P": "kv", "-D": "kv"})
_P("java node python python3 ruby php", prefix={"-D": "kv"})
_P("wrangler", when=("secret", "put"), positional={})
_P("restic borg rclone", flags={"--password": "value", "--pass": "value",
                                "--password-file": None, "--password-command": None})
_P("jfrog jf", flags={"--password": "value", "--access-token": "value",
                      "--apikey": "value"})
_P("sonar-scanner", prefix={"-Dsonar.login=": "value", "-Dsonar.token=": "value",
                            "-Dsonar.password=": "value"})

_P("security", when=("add-generic-password",), flags={"-w": "value"})
_P("security", when=("add-internet-password",), flags={"-w": "value"})

# Programs whose arguments are patterns or scripts, where key=value text is
# what is being searched for, not something being supplied.
PATTERN_TOOLS = {
    "grep", "egrep", "fgrep", "rg", "ag", "ack", "sed", "awk", "gawk", "jq",
    "yq", "find", "fd", "git-grep", "perl", "tr", "cut", "sort", "uniq",
    "wc", "head", "tail", "less", "more", "cat", "bat", "ls", "test", "[",
    "[[", "man", "which", "type", "whereis", "locate", "xmllint", "comm",
}
# Flags whose value is prose. Only the known-prefix tier reads prose.
MESSAGE_FLAGS = {
    "-m", "--message", "--title", "--description", "--notes", "--comment",
    "--subject", "--reason", "--summary", "--label", "--name", "--prompt",
}
WRAPPERS = {
    "sudo": {"-u", "-g", "-C", "-p", "-h", "-D", "-R", "-T", "-U", "-r", "-t"},
    "doas": {"-u", "-C"}, "env": {"-u", "-C", "-S", "--unset", "--chdir"},
    "command": set(), "exec": {"-a"}, "builtin": set(), "nohup": set(),
    "time": {"-o", "-f"}, "nice": {"-n"}, "ionice": {"-c", "-n", "-p"},
    "timeout": {"-s", "-k", "--signal", "--kill-after"}, "gtimeout": {"-s", "-k"},
    "xargs": {"-I", "-n", "-P", "-d", "-L", "-s", "-E", "-a", "-J", "-R"},
    "npx": {"-p", "--package", "-c"}, "bunx": {"-p"}, "uvx": {"--from", "--with", "-p"},
    "pnpx": {"-p"}, "watch": {"-n", "-d"}, "stdbuf": {"-i", "-o", "-e"},
    "caffeinate": {"-t", "-w"}, "eval": set(), "setsid": set(), "chronic": set(),
    "unbuffer": set(), "strace": {"-o", "-e", "-p", "-s"}, "ltrace": {"-o", "-e"},
    "arch": set(), "noglob": set(),
}
SHELL_KEYWORDS = {"if", "then", "else", "elif", "fi", "do", "done", "while",
                  "until", "for", "!", "{", "}", "case", "esac", "function"}
STDIN_CONSUMERS = ("--password-stdin", "--token-stdin", "--with-token",
                   "--pass-stdin", "--stdin-password", "--passphrase-fd")


# --------------------------------------------------------------------------
# Sink passes. Each appends (sink, severity, value) to `hits`; the value
# stays in memory for de-duplication and is never part of any output.
# --------------------------------------------------------------------------

def _judge(hits, sink, value, tier="strong", strength="strong", cap=None):
    vc = value_class(value)
    if vc == LITERAL:
        if tier == "strong" and strength == "strong":
            sev = HIGH
        elif plausible_secret(value, strength):
            sev = MEDIUM
        else:
            return
    elif vc == DEFAULT and tier == "strong" and strength == "strong":
        sev = INFO
    else:
        return
    if cap == MEDIUM and sev == HIGH:
        sev = MEDIUM
    hits.append((sink, sev, value.strip("'\"")))


_HEADER = re.compile(r"^\s*([A-Za-z][A-Za-z0-9\-_]{1,60})\s*:\s*(.+?)\s*$", re.S)
_CRED_HEADERS = {
    "authorization", "proxy-authorization", "x-api-key", "api-key", "apikey",
    "x-auth-token", "private-token", "x-vault-token", "x-goog-api-key",
    "x-functions-key", "ocp-apim-subscription-key", "x-amz-security-token",
}


def _cookie_secret(value):
    """True if one of the cookies is a session or a token, and not a
    preference: its name says so, or its value is long and generated."""
    for part in value.split(";"):
        name, eq, val = part.strip().partition("=")
        if not eq or value_class(val) != LITERAL:
            continue
        if (key_class(name) and len(val) >= 8) or (len(val) >= 16 and looks_random(val)):
            return True
    return False


def header_hit(hits, text, cap=None):
    """Judge one `Name: value` header line. True if it was a header at all."""
    m = _HEADER.match(text)
    if not m:
        return False
    name, val = m.group(1), m.group(2)
    low = name.lower()
    if low in ("cookie", "set-cookie"):
        if _cookie_secret(val):
            hits.append(("Cookie header", MEDIUM, val))
        return True
    kc = "strong" if low in _CRED_HEADERS else key_class(name)
    if not kc:
        return False
    _judge(hits, safe_name(name) + " header", AUTH_SCHEME.sub("", val), strength=kc, cap=cap)
    return True


_URL = re.compile(
    r"([A-Za-z][A-Za-z0-9+.\-]{1,20})://([^\s/:@?#'\"]*)(?::([^\s@/?#'\"]*))?@([^\s/:?#'\"]+)"
)
_QUERY = re.compile(r"[?&]([A-Za-z_][\w.\-]{0,40})=([^&\s#'\"]+)")
_LOOPBACK = re.compile(r"^(localhost|127\.\d+\.\d+\.\d+|\[?::1\]?|0\.0\.0\.0|host\.docker\.internal)$", re.I)


def url_hits(hits, text, cap=None):
    if "://" in text:
        for m in _URL.finditer(text):
            _scheme, user, pw, host = m.groups()
            # The host decides how bad a finding is, never whether it is one,
            # and only its class is reported.
            target = "loopback" if _LOOPBACK.match(host) else "remote"
            if pw:
                _judge(hits, "URL userinfo password (%s)" % target, pw, cap=cap)
            elif re.match(r"^[0-9a-f]{32}$", user):
                pass  # a telemetry DSN: the public half, published by design
            elif user:
                _judge(hits, "URL userinfo token (%s)" % target, user,
                       tier="embedded", strength="weak", cap=cap)
    if "=" in text and ("?" in text or "&" in text):
        for m in _QUERY.finditer(text):
            kc = key_class(m.group(1), url_query=True)
            if kc:
                _judge(hits, "URL query parameter " + safe_name(m.group(1)), m.group(2),
                       tier="embedded", strength=kc, cap=cap)


_EMBED = re.compile(
    r"""(?<![A-Za-z0-9_\-$])["']?([A-Za-z_][A-Za-z0-9_.\-]{1,50})["']?\s*([=:])\s*"""
    r"""(?:"((?:[^"\\]|\\.)*)"|'([^']*)'|([^\s&;,'"{}()\[\]]+))"""
)
# An unquoted value that is attribute access is code reading a credential,
# not a credential: os.environ, process.env.TOKEN, settings.api_key.
_ATTR_PATH = re.compile(r"^[A-Za-z_]+(\.[A-Za-z_]\w*)+$")


def embedded_hits(hits, text, cap=None):
    """key=value and "key": "value" pairs found inside a larger argument."""
    pos = 0
    while True:
        m = _EMBED.search(text, pos)
        if not m:
            return
        pos = m.end(1)  # resume inside the match: a value may itself be k=v
        kc = key_class(m.group(1))
        if not kc:
            continue
        if text[max(0, m.start() - 2):m.start()] == "${":
            continue  # ${TOKEN:-fallback} is an expansion, not a pair
        bare = m.group(5)
        if bare is not None:
            rest = text[m.end():]
            if rest[:1] in ("(", "[") or _ATTR_PATH.match(bare):
                continue  # a call, an index or attribute access
            if m.group(2) == ":" and AUTH_SCHEME.match(bare + " "):
                # YAML writes a header unquoted: `Authorization: Bearer VALUE`.
                # One word after the scheme and nothing else is the value.
                one = re.match(r"[ \t]+(\S+)[ \t]*(?=[\r\n]|$)", rest)
                if one:
                    _judge(hits, "embedded key " + safe_name(m.group(1)), one.group(1),
                           tier="embedded", strength=kc, cap=cap)
                    continue
            if m.group(2) == ":" and re.match(r"[ \t]+[^\s#]", rest):
                continue  # "Token: where to find one" is a sentence
        val = next(g for g in m.groups()[2:] if g is not None)
        val = AUTH_SCHEME.sub("", val)
        if bare is None and re.search(r"\s", val.strip()):
            continue  # a quoted phrase; the embedded tier wants one token
        _judge(hits, "embedded key " + safe_name(m.group(1)), val,
               tier="embedded", strength=kc, cap=cap)


def text_hits(hits, text, cap=None, keyed=True):
    """The context-free tier: tokens, URLs, and optionally key=value pairs."""
    for label, sev, val in prefix_hits(text):
        hits.append(("known-prefix token (%s)" % label, sev, val))
    url_hits(hits, text, cap)
    if keyed:
        embedded_hits(hits, text, cap)


def _apply_kind(hits, kind, value, sink, cap=None):
    if kind == "value":
        _judge(hits, sink, value, cap=cap)
    elif kind in ("userpass", "certpass", "pct", "comma"):
        sep = {"userpass": ":", "certpass": ":", "pct": "%", "comma": ","}[kind]
        if kind == "certpass" and re.match(r"^[A-Za-z]:[\\/]", value):
            value = value[2:]
        _head, found, pw = value.partition(sep)
        if found and pw:
            _judge(hits, sink + " password", pw, cap=cap)
    elif kind == "slash":
        m = re.match(r"^[^/@\s]+/([^@\s]+)(?:@.*)?$", value)
        if m:
            _judge(hits, sink + " password", m.group(1), cap=cap)
    elif kind == "passarg":
        if value.startswith("pass:"):
            _judge(hits, sink, value[5:], cap=cap)
    elif kind == "header":
        header_hit(hits, value, cap)
    elif kind == "cookie":
        if _cookie_secret(value):
            hits.append((sink + " cookie", MEDIUM, value))
    elif kind in ("kv", "anykv"):
        name, found, val = value.partition("=")
        if not found:
            return
        if kind == "anykv" and not (_PLAIN_NAME.match(name) and not looks_random(name)):
            # NAME=value with the name left off, and a value that has an "="
            # of its own (base64 padding): the whole argument is the value,
            # and what sits in name position is part of it.
            _judge(hits, sink, value, cap=cap)
            return
        kc = "strong" if kind == "anykv" else key_class(name)
        if kc:
            _judge(hits, "%s %s" % (sink, safe_name(name)), val, strength=kc, cap=cap)


_PLAIN_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_.\-]{0,39}$")


# --------------------------------------------------------------------------
# Command analysis
# --------------------------------------------------------------------------

_ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\+?=(.*)$", re.S)
_DECLARERS = {"export", "declare", "local", "readonly", "typeset"}
MAX_DEPTH = 4

# Every flag the table names per program, whatever the subcommand.
PROGRAMS_FLAGS = {p: set().union(*(e["flags"].keys() for e in es))
                  for p, es in PROGRAMS.items()}


def prog_name(word):
    base = re.split(r"[\\/]", word)[-1].lower()
    return base[:-4] if base.endswith(".exe") else base


def _env_hit(hits, name, value, cap):
    kc = key_class(name)
    if kc:
        _judge(hits, "environment assignment " + safe_name(name), value, strength=kc, cap=cap)


def _positionals(args, entry):
    """(index, word) for the arguments that are not flags or flag values."""
    takes = {f for f in entry["flags"]
             if f not in entry["booleans"] and f not in entry["eq_only"]
             and f not in entry["attached_only"]} | entry["valflags"]
    out, i = [], 0
    while i < len(args):
        a = args[i]
        if a.startswith("-") and len(a) > 1:
            if "=" not in a and a in takes:
                i += 1
        else:
            out.append((i, a))
        i += 1
    return out


def _has_flag(args, flag):
    """True for `-b`, and for `-b` folded into a cluster such as `-cb`."""
    letter = flag[1:]
    return any(a == flag or (len(letter) == 1 and re.match(r"^-[A-Za-z]+$", a) and letter in a)
               for a in args)


_FLAG_SHAPED = re.compile(r"^(?:-[A-Za-z]|--[A-Za-z][A-Za-z0-9\-]+(?:=.*)?)$")


def _is_flag(word):
    """`mongosh -p --host db`: the password is prompted for, and `--host`
    is the next option, not the value."""
    return bool(_FLAG_SHAPED.match(word)) and not looks_random(word.split("=")[0])


def _cluster(entry, args, i, hits, label, cap):
    """`curl -sSu user:pw`: a table flag that closes a cluster of short
    flags takes the next argument, exactly as it would standing alone.
    Returns the index of the last argument consumed.

    Not applied to a program whose table has single-dash long options
    (`-passin`, `-pw`), where a run of letters is a name and not a cluster.
    """
    a = args[i]
    if not re.match(r"^-[A-Za-z]{2,}$", a) or a in entry["flags"] \
            or any(re.match(r"^-[A-Za-z]{2,}", f) for f in entry["flags"]):
        return i
    last = "-" + a[-1]
    kind = entry["flags"].get(last)
    if not kind or last in entry["attached_only"] or last in entry["booleans"] \
            or last in entry["eq_only"]:
        return i
    if i + 1 < len(args) and not args[i + 1].startswith("-"):
        _apply_kind(hits, kind, args[i + 1], "%s %s" % (label, last), cap)
        return i + 1
    return i


def _table_pass(prog, args, hits, cap):
    """Apply the program table. Returns the flags it owns, so the generic
    pass does not judge them a second time by name alone."""
    owned = set()
    for entry in PROGRAMS.get(prog, ()):
        owned |= entry["booleans"] | entry["eq_only"]
        pos = _positionals(args, entry)
        when = entry["when"]
        if [w for _, w in pos[:len(when)]] != list(when):
            continue
        if not all(_has_flag(args, f) for f in entry["requires"]) \
                or any(_has_flag(args, f) for f in entry["unless"]):
            continue
        label = " ".join((prog,) + tuple(when))
        short = set(entry["attached"]) | set(entry["attached_only"])
        i = 0
        while i < len(args):
            a = args[i]
            flag, eq, val = a.partition("=")
            if a.startswith("-") and flag in entry["flags"]:
                owned.add(flag)
                kind, value = entry["flags"][flag], None
                if eq:
                    value = val
                elif flag in entry["eq_only"] or flag in entry["attached_only"] \
                        or flag in entry["booleans"]:
                    pass
                elif i + 1 < len(args) and not _is_flag(args[i + 1]):
                    i += 1
                    value = args[i]
                if kind and value is not None:
                    _apply_kind(hits, kind, value, "%s %s" % (label, flag), cap)
            elif not a.startswith("--"):
                for sf in short:
                    if a.startswith(sf) and len(a) > len(sf):
                        kind = entry["flags"].get(sf)
                        if kind:
                            _apply_kind(hits, kind, a[len(sf):].lstrip("="),
                                        "%s %s" % (label, sf), cap)
                        break
                else:
                    i = _cluster(entry, args, i, hits, label, cap)
                for pf, kind in (entry["prefix"] or {}).items():
                    if kind and a.startswith(pf) and len(a) > len(pf):
                        _apply_kind(hits, kind, a[len(pf):], "%s %s" % (label, pf), cap)
            i += 1
        name = ""
        for n, (_idx, w) in enumerate(pos[len(when):]):
            kind = (entry["positional"] or {}).get(n)
            if kind == "name":
                # A scoped key such as `//host/:_authToken` is judged by
                # its last segment; the host in front is not part of the name.
                name = [seg for seg in re.split(r"[/:]", w) if seg][-1:] or [""]
                name = name[0]
            elif kind == "namevalue":
                kc = key_class(name)
                if kc:
                    _judge(hits, "%s %s" % (label, safe_name(name)), w, strength=kc, cap=cap)
            elif kind:
                _apply_kind(hits, kind, w, "%s argument %d" % (label, n + 1), cap)
            if entry["rest"] and n >= entry["rest"][0] and "=" in w:
                _apply_kind(hits, entry["rest"][1], w, label, cap)
    return owned


_SINGLE_DASH_LONG = re.compile(r"^-([a-z][a-z\-]{3,})$")


def _generic_pass(prog, args, owned, hits, cap, depth):
    """Judge what the table did not own: credential-named flags and
    assignments, headers, URLs and tokens, in any program. An argument
    that is itself a command line (`bash -c`, `env -S`, `npx -c`) is
    scanned as one."""
    pattern_tool = prog in PATTERN_TOOLS
    table_flags = PROGRAMS_FLAGS.get(prog, ())
    prose = False
    for i, a in enumerate(args):
        text_hits(hits, a, cap, keyed=False)
        if prose:  # the value of -m/--message: tokens only, no key=value
            prose = False
            continue
        if a.startswith("-") and len(a) > 1:
            flag, eq, val = a.partition("=")
            if flag in MESSAGE_FLAGS and not eq:
                prose = True
                continue
            if flag in table_flags:
                continue
            name = None
            if flag.startswith("--"):
                name = flag[2:]
            elif _SINGLE_DASH_LONG.match(flag) and key_class(flag) == "strong":
                name = flag[1:]
            kc = key_class(name) if name else None
            if kc:
                sink = "flag " + ("--" if flag.startswith("--") else "-") + safe_name(name)
                if eq:
                    _judge(hits, sink, val, strength=kc, cap=cap)
                elif flag not in owned and i + 1 < len(args) and not args[i + 1].startswith("-"):
                    _judge(hits, sink, args[i + 1], strength=kc, cap=cap)
            elif eq and not pattern_tool:
                if not header_hit(hits, val, cap):
                    embedded_hits(hits, val, cap)
            continue
        if pattern_tool:
            continue
        if header_hit(hits, a, cap):
            continue
        embedded_hits(hits, a, cap)
        if re.search(r"\s", a) and depth < MAX_DEPTH:
            # A quoted argument that is itself a command line: bash -c,
            # ssh host '...', eval. The sink is inferred, so it is capped.
            hits.extend(scan_command(_unlit(a), depth + 1, MEDIUM, _dedupe=False))


# Wrapper options whose value is a whole command line in one string.
_COMPOSER_TOKENS = {"github-oauth", "gitlab-oauth", "gitlab-token", "bearer",
                    "bitbucket-oauth"}


def _composer_auth(args, hits, cap):
    """`composer config http-basic.<host> <user> <password>`, and the forms
    that take a token. The setting names the host, so it is not printed."""
    pos = [a for a in args if not a.startswith("-")]
    if pos[:1] != ["config"] or len(pos) < 3:
        return
    kind = pos[1].split(".")[0]
    if kind == "http-basic" and len(pos) >= 4:
        _judge(hits, "composer config http-basic password", pos[3], cap=cap)
    elif kind in _COMPOSER_TOKENS:
        _judge(hits, "composer config %s token" % kind, pos[-1], cap=cap)


_STRING_COMMANDS = {("env", "-S"), ("env", "--split-string"), ("npx", "-c"),
                    ("npx", "--call"), ("pnpx", "-c"), ("bunx", "-c")}
# Programs that run another command given to them unquoted: after "--", or
# as the words that follow a host, a container or a pod.
_DASH_CARRIERS = {
    "kubectl", "oc", "docker", "podman", "nerdctl", "docker-compose", "ssh",
    "op", "doppler", "infisical", "aws-vault", "chamber", "dotenv", "sops",
    "devcontainer", "limactl", "multipass", "lxc", "vagrant", "flock",
}
_WORD_CARRIERS = {
    "ssh", "mosh", "autossh", "docker", "podman", "nerdctl", "docker-compose",
    "chroot", "nsenter", "flock", "lxc", "limactl", "multipass", "toolbox",
    "distrobox",
}
_CARRIED_HEADS = {"sudo", "doas", "env", "nohup"}


def _carried_commands(prog, args):
    """The commands another program is asked to run, written unquoted.

    `ssh host mysql -pVALUE` and `kubectl exec pod -- redis-cli -a VALUE`
    hand the credential to mysql and redis-cli, and the program in front
    hides that from a table keyed on the first word. After "--" the rest
    is the command. Without one, every later word that names a program
    this file knows may start it, since the options of the carrier are not
    modelled and its host or container name could be anything.
    """
    if prog in _DASH_CARRIERS and "--" in args:
        return [args[args.index("--") + 1:]]
    out = []
    if prog in _WORD_CARRIERS:
        for j in range(1, len(args)):
            base = prog_name(args[j])
            if not args[j].startswith("-") and (base in PROGRAMS or base in _CARRIED_HEADS):
                out.append(args[j:])
                if len(out) == 3:
                    break
    return out


def _scan_simple(words, hits, cap, depth):
    wrapped = False
    while words and words[0] in SHELL_KEYWORDS:
        words = words[1:]
    while words:
        m = _ASSIGN.match(words[0])
        if m:
            _env_hit(hits, m.group(1), m.group(2), cap)
            text_hits(hits, m.group(2), cap, keyed=False)
            words = words[1:]
            continue
        base = prog_name(words[0])
        if base in _DECLARERS:
            for w in words[1:]:
                m = _ASSIGN.match(w)
                if m:
                    _env_hit(hits, m.group(1), m.group(2), cap)
                    text_hits(hits, m.group(2), cap, keyed=False)
            return
        if base in WRAPPERS:
            takes = WRAPPERS[base]
            words = words[1:]
            wrapped = True
            while words and words[0].startswith("-") and len(words[0]) > 1:
                flag, words = words[0], words[1:]
                name, eq, inline = flag.partition("=")
                if (base, name) in _STRING_COMMANDS and depth < MAX_DEPTH:
                    # env -S "...", npx -c "...": the string is a command.
                    carried = inline if eq else (words[0] if words else "")
                    hits.extend(scan_command(_unlit(carried), depth + 1, cap, _dedupe=False))
                if flag in takes and words:
                    words = words[1:]
            if base in ("timeout", "gtimeout") and words:
                words = words[1:]
            continue
        break
    if not words:
        return
    if wrapped and len(words) == 1 and re.search(r"\s", words[0]) and depth < MAX_DEPTH:
        # eval '...', watch '...': the one remaining word is a command line.
        hits.extend(scan_command(_unlit(words[0]), depth + 1, cap, _dedupe=False))
        return
    prog, args = prog_name(words[0]), words[1:]
    text_hits(hits, words[0], cap, keyed=False)
    owned = _table_pass(prog, args, hits, cap)
    _generic_pass(prog, args, owned, hits, cap, depth)
    if prog == "composer":
        _composer_auth(args, hits, cap)
    if depth < MAX_DEPTH:
        for rest in _carried_commands(prog, args):
            _scan_simple(rest, hits, cap, depth + 1)


def _reads_secret_from_stdin(words):
    """True if this command line takes a credential from standard input,
    so that a literal echoed, printed or here-stringed into it is one."""
    if any(w.split("=")[0] in STDIN_CONSUMERS for w in words):
        return True
    bare = [w for w in words if not w.startswith("-")]
    progs = [prog_name(w) for w in bare[:1]]
    if progs == ["sudo"] and _has_flag(words[1:], "-S"):
        return True
    tail = bare[1:3]
    if progs == ["wrangler"] and tail == ["secret", "put"]:
        return True
    if progs == ["vercel"] and tail == ["env", "add"]:
        return True
    if progs == ["gh"] and tail == ["secret", "set"]:
        return not any(w.split("=")[0] in ("-b", "--body", "-f", "--env-file") for w in words)
    if progs == ["vault"]:
        return words[-1:] == ["-"] or any(w.endswith("=-") for w in words)
    if progs == ["openssl"]:
        return "-stdin" in words or any(
            a in ("-pass", "-passin", "-passout") and b == "stdin"
            for a, b in zip(words, words[1:]))
    if progs in (["passwd"], ["mkpasswd"]):
        return "--stdin" in words or "-s" in words
    if progs == ["htpasswd"]:
        return _has_flag(words[1:], "-i")
    if progs in (["pass"], ["gopass"]):
        return tail[:1] == ["insert"]
    if progs == ["secret-tool"]:
        return tail[:1] == ["store"]
    if progs in (["docker"], ["podman"]) and tail == ["secret", "create"]:
        return words[-1:] == ["-"]
    return progs in (["chpasswd"], ["kinit"])


def _dedupe_hits(hits):
    """One hit per distinct value, keeping the most severe description."""
    rank = {HIGH: 0, MEDIUM: 1, INFO: 2}
    best = {}
    for sink, sev, val in hits:
        cur = best.get(val)
        if cur is None or rank[sev] < rank[cur[1]]:
            best[val] = (sink, sev, val)
    return list(best.values())


_PRINTF_ONLY_FORMAT = re.compile(r"^(?:%[-0-9.]*[sdqb]|\\[nrt]|\s)+$")


def _curl_config_on_stdin(words):
    """True for `curl -K -` in any spelling: the input is a config file."""
    if not words or prog_name(words[0]) != "curl":
        return False
    return any(w in ("-K-", "--config=-") for w in words) or any(
        a in ("-K", "--config") and b == "-" for a, b in zip(words, words[1:]))


def _curl_config_hits(hits, body, cap):
    """`curl -K -`: each line of the input is an option without its dashes,
    so a credential there is in the same sink as one on the command line."""
    for line in body.splitlines():
        m = re.match(r"^\s*-{0,2}([A-Za-z][A-Za-z0-9\-]*)\s*(?:[=:]|\s)\s*(.*?)\s*$", line)
        if not m:
            continue
        name, val = m.group(1), m.group(2)
        if len(val) >= 2 and val[0] == val[-1] == '"':
            val = val[1:-1]
        flag = ("-" if len(name) == 1 else "--") + name
        for entry in PROGRAMS["curl"]:
            kind = entry["flags"].get(flag)
            if kind:
                _apply_kind(hits, kind, val, "curl config " + flag, cap)


def scan_command(cmdline, depth=0, cap=None, _dedupe=True):
    """Find literal credentials in one shell command line.

    Returns [(sink, severity, value)]. The value is for the caller to
    correlate and discard; no caller in this file prints it.
    """
    hits = []
    if depth > MAX_DEPTH or not cmdline or not cmdline.strip():
        return hits
    subs = []
    cmds = split_commands(cmdline, subs)
    for k, cmd in enumerate(cmds):
        words = cmd["words"]
        _scan_simple(words, hits, cap, depth)
        consumer = _reads_secret_from_stdin(words)
        for src in ("stdin", "heredoc"):
            body = cmd[src]
            if not body:
                continue
            if consumer:
                _judge(hits, "input fed to a credential prompt", body.strip(), cap=cap)
            if _curl_config_on_stdin(words):
                _curl_config_hits(hits, body, cap)
            text_hits(hits, body, cap)
        if consumer and k > 0 and cmd["sep"] == "|":
            prev = cmds[k - 1]["words"]
            if prev and prog_name(prev[0]) in ("echo", "printf"):
                operands = [a for a in prev[1:] if not (a.startswith("-") and len(a) <= 3)]
                if prog_name(prev[0]) == "printf" and operands and \
                        (len(operands) > 1 or _PRINTF_ONLY_FORMAT.match(operands[0])):
                    operands = operands[1:]  # the format, not what it prints
                for a in operands:
                    _judge(hits, "value piped to a credential prompt", a, cap=cap)
    for body in subs:
        hits.extend(scan_command(body, depth + 1, cap, _dedupe=False))
    hits = [(_unlit(sink), sev, _unlit(val)) for sink, sev, val in hits]
    return _dedupe_hits(hits) if _dedupe else hits


# --------------------------------------------------------------------------
# File walkers
# --------------------------------------------------------------------------
#
# Each returns [(where, sink, severity, value)]. `where` is a JSON path or a
# line number: enough to find the entry, never a copy of it.

_RULE = re.compile(
    r"^(?:Bash|Shell|PowerShell|run_shell_command|shell|exec|terminal|execute_command)"
    r"\((.*)\)\s*$", re.S)
_COMMAND_KEYS = {"command", "cmd", "script", "run"}
_ENV_KEYS = {"env", "environment", "envvars", "env_vars"}
_HEADER_KEYS = {"headers", "requestheaders", "http_headers", "httpheaders"}
MAX_FILE_BYTES = 20 * 1024 * 1024


def _strip_jsonc(text):
    """Drop // and /* */ comments and trailing commas, leaving strings alone."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
            out.append(c)
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        else:
            if c in "}]":
                # A trailing comma, found here rather than by a pattern over
                # the result: a pattern cannot tell ",}" inside a string.
                k = len(out) - 1
                while k >= 0 and out[k] in " \t\r\n":
                    k -= 1
                if k >= 0 and out[k] == ",":
                    del out[k]
            out.append(c)
        i += 1
    return "".join(out)


def _seg(key):
    """A path segment that is safe to print: a key can itself be a token."""
    if "://" in key:
        return "<url>"
    probe = []
    text_hits(probe, key)
    if probe:
        return "<key>"
    # A key that is a filesystem path (a per-project table keyed by checkout)
    # prints as its last component: the rest is somebody's home directory.
    if "/" in key or "\\" in key:
        tail = re.split(r"[\\/]", key.rstrip("/\\"))[-1]
        return "<path>/" + safe_name(tail)
    return safe_name(key)


def _emit(out, where, hits):
    for sink, sev, val in _dedupe_hits(hits):
        out.append((where, sink, sev, val))


def _string_hits(value, hits):
    m = _RULE.match(value)
    if m:
        inner = re.sub(r"(?::\*|\s\*)$", "", m.group(1))
        hits.extend(scan_command(inner, _dedupe=False))
    else:
        text_hits(hits, value, None, keyed=False)


def _argv_head(v):
    """True if `v` can be a command: a string, or a list of strings whose
    first element is the program and the rest its arguments."""
    return isinstance(v, str) or (
        isinstance(v, list) and bool(v) and all(isinstance(a, str) for a in v))


def _walk(node, path, out, depth=0):
    """Walk parsed JSON, TOML or YAML and emit what each position holds.

    A key decides how its value is read: an `env` or `headers` object by
    its names, a `command` or `cmd` as a command - one string, a string
    with an `args` list beside it, or the whole argv as a list - and any
    other key by its own name. A key is itself scanned for tokens, since a
    credential is sometimes used as one.
    """
    if depth > 80:
        return
    if isinstance(node, list):
        for i, v in enumerate(node):
            p = "%s[%d]" % (path, i)
            if isinstance(v, str):
                hits = []
                _string_hits(v, hits)
                _emit(out, p, hits)
            else:
                _walk(v, p, out, depth + 1)
        return
    if not isinstance(node, dict):
        return
    has_command = any(_argv_head(node.get(ck)) for ck in ("command", "cmd"))
    for k, v in node.items():
        k = str(k)
        low = k.lower()
        p = (path + "." if path else "") + _seg(k)
        hits = []
        text_hits(hits, k, None, keyed=False)
        if isinstance(v, dict) and low in _ENV_KEYS:
            for name, val in v.items():
                if isinstance(val, str):
                    _env_hit(hits, str(name), val, None)
                    text_hits(hits, val, None, keyed=False)
                    _emit(out, p + "." + _seg(str(name)), hits)
                    hits = []
                else:
                    _walk(val, p + "." + _seg(str(name)), out, depth + 1)
        elif isinstance(v, dict) and low in _HEADER_KEYS:
            for name, val in v.items():
                if isinstance(val, str):
                    if not header_hit(hits, "%s: %s" % (name, val)):
                        text_hits(hits, val, None, keyed=False)
                    _emit(out, p + "." + _seg(str(name)), hits)
                    hits = []
        elif isinstance(v, str) and low in _COMMAND_KEYS:
            args = node.get("args")
            if low in ("command", "cmd") and isinstance(args, list) \
                    and all(isinstance(a, str) for a in args):
                # An argv, not a command line: the arguments are never
                # re-split, so a space inside one stays inside it.
                cmds = split_commands(v)
                head = cmds[0]["words"] if len(cmds) == 1 else [v]
                _scan_simple(head + args, hits, None, 0)
                hits[:] = [(_unlit(a), b, _unlit(c)) for a, b, c in hits]
            else:
                hits.extend(scan_command(v, _dedupe=False))
        elif low in ("command", "cmd") and isinstance(v, list) and _argv_head(v):
            # The whole argv as a list, with or without "args" beside it.
            args = node.get("args")
            more = args if isinstance(args, list) and \
                all(isinstance(a, str) for a in args) else []
            _scan_simple(v + more, hits, None, 0)
            hits[:] = [(_unlit(a), b, _unlit(c)) for a, b, c in hits]
        elif low == "args" and has_command and isinstance(v, list) \
                and all(isinstance(a, str) for a in v):
            pass  # judged with its command above
        elif isinstance(v, str):
            kc = key_class(k)
            if kc:
                _judge(hits, "key " + safe_name(k), v, strength=kc)
            _string_hits(v, hits)
        else:
            _emit(out, p, hits)
            _walk(v, p, out, depth + 1)
            continue
        _emit(out, p, hits)


_SHELL_FENCES = {"", "sh", "bash", "zsh", "fish", "shell", "console", "terminal",
                 "shellsession", "shell-session", "powershell", "pwsh", "cmd", "bat"}


def _text_tier(text, out, keyed, prefix=""):
    """Line by line, for formats with no structure to walk. In Markdown,
    lines inside a code fence are also read as commands, capped at medium."""
    fenced = shell = False
    lines = text.splitlines()
    for n, line in enumerate(lines, 1):
        if len(line) > 20000:
            line = line[:20000]
        hits = []
        stripped = line.strip()
        if stripped.startswith("```") or stripped.startswith("~~~"):
            fenced = not fenced
            # Only a fence that says it is shell, or says nothing, is read
            # as commands; markup and source in a fence are not.
            lang = stripped.lstrip("`~").strip().split(" ")[0].lower()
            shell = fenced and lang in _SHELL_FENCES
            continue
        text_hits(hits, line, None, keyed=keyed)
        if _PEM_START.search(line):
            # A key written across lines: judge the header with what follows.
            for label, sev, val in prefix_hits("\n".join(lines[n - 1:n + 3])):
                if label == "PEM private key":
                    hits.append(("known-prefix token (%s)" % label, sev, val))
        if shell and not keyed and stripped and stripped[0] not in "#<{[":
            hits.extend(scan_command(stripped.lstrip("$> "), 0, MEDIUM, _dedupe=False))
        _emit(out, "%sline %d" % (prefix, n), hits)


def scan_text(name, text):
    """Scan one file's contents, choosing the walker by its name."""
    out = []
    low = name.lower()
    if low.endswith(".jsonl") or low.endswith(".ndjson"):
        for n, line in enumerate(text.splitlines(), 1):
            if not line.strip():
                continue
            try:
                _walk(json.loads(line), "line %d: " % n, out)
            except (ValueError, RecursionError):
                _text_tier(line, out, False, "line %d, " % n)
        return _collapse(out)
    if low.endswith(".json") or low.endswith(".jsonc") or low.endswith(".code-workspace"):
        for candidate in (text, _strip_jsonc(text)):
            try:
                _walk(json.loads(candidate), "", out)
                return _collapse(out)
            except (ValueError, RecursionError):
                out = []
        out.append(("file", "unparseable JSON, read as plain text", INFO, ""))
        _text_tier(text, out, True)
        return _collapse(out)
    if low.endswith(".toml") and tomllib is not None:
        try:
            _walk(tomllib.loads(text), "", out)
            return _collapse(out)
        except (ValueError, RecursionError):
            out = []
    markdown = low.endswith((".md", ".mdx", ".mdc", ".markdown", ".txt"))
    _text_tier(text, out, keyed=not markdown)
    return _collapse(out)


def _collapse(out):
    """One finding per (where, value), keeping the most severe."""
    rank = {HIGH: 0, MEDIUM: 1, INFO: 2}
    best = {}
    for where, sink, sev, val in out:
        key = (where, val)
        if key not in best or rank[sev] < rank[best[key][2]]:
            best[key] = (where, sink, sev, val)
    return list(best.values())


# --------------------------------------------------------------------------
# The agent surface: which files an agent writes credentials into
# --------------------------------------------------------------------------

AGENT_DIRS = {
    ".claude", ".cursor", ".gemini", ".codex", ".specstory", ".continue",
    ".roo", ".cline", ".windsurf", ".kiro", ".amazonq", ".agents",
    ".opencode", ".zed", ".junie", ".augment", ".goose",
}
AGENT_FILES = {
    ".mcp.json", ".claude.json", "claude_desktop_config.json", "mcp.json",
    "mcp_config.json", "opencode.json", ".cursorrules", ".clinerules",
    ".windsurfrules", ".roomodes", ".goosehints",
    # Rules and memory files: an agent appends to these, and people paste
    # a working command into them.
    "CLAUDE.md", "CLAUDE.local.md", "AGENTS.md", "AGENTS.override.md",
    "GEMINI.md", "copilot-instructions.md",
}
VSCODE_FILES = {"mcp.json", "settings.json"}
PRUNE_DIRS = {
    "node_modules", ".git", ".hg", ".svn", ".venv", "venv", "__pycache__",
    "build", "dist", "target", ".gradle", ".idea", "Pods", "DerivedData",
    ".next", ".cache", "vendor", "worktrees",
}
# Settings, rules, transcripts and hook scripts. Program source is another
# scanner's job; a megabyte of bundled JavaScript is not an agent's memory.
SURFACE_EXT = {
    ".json", ".jsonc", ".jsonl", ".ndjson", ".toml", ".yaml", ".yml", ".md",
    ".mdx", ".mdc", ".txt", ".env", ".local", ".ini", ".conf", ".cfg", ".sh",
    ".bash", ".zsh", ".ps1", ".log", "",
}
USER_FILES = (
    ".claude/settings.json", ".claude/settings.local.json", ".claude.json",
    ".cursor/mcp.json", ".cursor/cli-config.json", ".gemini/settings.json",
    ".gemini/antigravity/mcp_config.json", ".gemini/config/mcp_config.json",
    ".config/goose/config.yaml", ".codex/config.toml",
    ".codeium/windsurf/mcp_config.json", ".continue/config.json",
    ".continue/config.yaml", ".config/opencode/opencode.json",
    ".config/zed/settings.json", ".aider.conf.yml",
    ".config/Claude/claude_desktop_config.json",
    "Library/Application Support/Claude/claude_desktop_config.json",
    "AppData/Roaming/Claude/claude_desktop_config.json",
    ".config/Code/User/mcp.json", ".config/Code/User/settings.json",
    "Library/Application Support/Code/User/mcp.json",
    "Library/Application Support/Code/User/settings.json",
    "AppData/Roaming/Code/User/mcp.json", "AppData/Roaming/Code/User/settings.json",
)
MAX_FILES = 20000


def _surface_ext(name):
    return os.path.splitext(name)[1].lower() in SURFACE_EXT


def is_surface(relpath):
    """True when a repository-relative path belongs to the agent surface."""
    parts = re.split(r"[\\/]", relpath)
    name = parts[-1]
    if any(p in PRUNE_DIRS for p in parts[:-1]):
        return False
    if any(p in AGENT_DIRS for p in parts[:-1]):
        return _surface_ext(name)
    if len(parts) >= 2 and parts[-2] == ".vscode":
        return name in VSCODE_FILES
    return name in AGENT_FILES or name.startswith(".aider")


def discover(root):
    """Yield the surface files under `root`, without following links."""
    count = 0
    for base, dirs, files in os.walk(root, followlinks=False):
        rel = os.path.relpath(base, root)
        rel = "" if rel == "." else rel
        dirs[:] = sorted(d for d in dirs if d not in PRUNE_DIRS
                         and not os.path.islink(os.path.join(base, d)))
        for name in sorted(files):
            relpath = os.path.join(rel, name) if rel else name
            # A link or a pipe is still yielded, so that it is reported as
            # skipped; read_text is what declines to open it.
            if is_surface(relpath):
                count += 1
                if count > MAX_FILES:
                    return
                yield relpath


def discover_user(home, transcripts=False):
    """User-level agent configuration, and transcripts only when asked."""
    for rel in USER_FILES:
        if os.path.isfile(os.path.join(home, rel)):
            yield rel
    if transcripts:
        base = os.path.join(home, ".claude", "projects")
        for d, _dirs, files in os.walk(base, followlinks=False):
            for name in sorted(files):
                if name.endswith(".jsonl"):
                    yield os.path.relpath(os.path.join(d, name), home)


def read_text(path, follow=False):
    """(text, None) or (None, reason). Never raises, never blocks.

    Only a regular file is read. Inside a project a symbolic link is not
    followed, since it can point anywhere on the machine; `follow` is for
    user-level configuration, which a dotfiles manager routinely links.
    The checks are made on the open descriptor, so a file swapped for a
    pipe between the listing and the read is still declined.
    """
    try:
        if not follow and stat.S_ISLNK(os.lstat(path).st_mode):
            return None, "symbolic link, not followed"
        flags = os.O_RDONLY | getattr(os, "O_NONBLOCK", 0) | getattr(os, "O_CLOEXEC", 0)
        if not follow:
            flags |= getattr(os, "O_NOFOLLOW", 0)
        fd = os.open(path, flags)
        with os.fdopen(fd, "rb") as fh:
            st = os.fstat(fh.fileno())
            if not stat.S_ISREG(st.st_mode):
                return None, "not a regular file"
            if st.st_size > MAX_FILE_BYTES:
                return None, "larger than %d MB" % (MAX_FILE_BYTES // (1024 * 1024))
            raw = fh.read(MAX_FILE_BYTES + 1)
    except OSError:
        return None, "unreadable"
    if b"\x00" in raw[:8192]:
        return None, "binary"
    return raw.decode("utf-8", "replace"), None


# --------------------------------------------------------------------------
# Git context. Read-only: no command here writes to the repository.
# --------------------------------------------------------------------------

def _git(cwd, *args, data=None):
    env = dict(os.environ, GIT_OPTIONAL_LOCKS="0", GIT_TERMINAL_PROMPT="0")
    try:
        r = subprocess.run(("git", "-C", cwd) + args, input=data, env=env,
                           capture_output=True, timeout=60)
        return r.returncode, r.stdout
    except (OSError, subprocess.SubprocessError):
        return 127, b""


def git_state(root, relpath):
    """'tracked', 'untracked', 'ignored' or 'no-git' for one file."""
    cwd = os.path.dirname(os.path.join(root, relpath)) or root
    name = os.path.basename(relpath)
    rc, _ = _git(cwd, "rev-parse", "--is-inside-work-tree")
    if rc != 0:
        return "no-git"
    if _git(cwd, "ls-files", "--error-unmatch", "--", name)[0] == 0:
        return "tracked"
    if _git(cwd, "check-ignore", "-q", "--", name)[0] == 0:
        return "ignored"
    return "untracked"


GIT_LABEL = {
    "tracked": "tracked by git: assume it is in history and rotate",
    "untracked": "not ignored by git: the next `git add` takes it",
    "ignored": "ignored by git",
    "no-git": "not in a git repository",
    "user-level": "user-level file",
}


def staged_files(root):
    """[(relpath, text)] for staged agent-surface files, read from the index."""
    rc, out = _git(root, "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR")
    if rc != 0:
        return None
    result = []
    for rel in out.decode("utf-8", "replace").split("\0"):
        if rel and is_surface(rel):
            rc, blob = _git(root, "show", ":" + rel)
            if rc == 0 and b"\x00" not in blob[:8192] and len(blob) <= MAX_FILE_BYTES:
                result.append((rel, blob.decode("utf-8", "replace")))
    return result


MAX_HISTORY_BLOBS = 3000


def history_files(root):
    """[(label, text)] for every past version of an agent-surface file."""
    rc, out = _git(root, "rev-list", "--all", "--objects")
    if rc != 0:
        return None, False
    seen, result = set(), []
    for line in out.decode("utf-8", "replace").splitlines():
        sha, _, path = line.partition(" ")
        if not path or sha in seen or not is_surface(path):
            continue
        seen.add(sha)
        if len(seen) > MAX_HISTORY_BLOBS:
            return result, True
        rc, blob = _git(root, "cat-file", "blob", sha)
        if rc != 0 or b"\x00" in blob[:8192] or len(blob) > MAX_FILE_BYTES:
            continue
        rc, commit = _git(root, "log", "--all", "--format=%h", "--find-object=" + sha, "--", path)
        first = commit.decode("ascii", "replace").split()
        label = "%s (history, commit %s)" % (path, first[-1] if first else "unknown")
        result.append((label, blob.decode("utf-8", "replace")))
    return result, False


# --------------------------------------------------------------------------
# Packaging: the routes by which an ignored file is published anyway
# --------------------------------------------------------------------------

def _ignore_covers(lines, dirname):
    """A deliberately small reading of an ignore file: does a line name
    this directory, or every dot-directory? Negations are not modelled."""
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("!"):
            continue
        pat = re.sub(r"(/\*\*?|/)$", "", line.lstrip("/"))
        pat = re.sub(r"^\*\*/", "", pat)
        if pat in (dirname, ".*", "*"):
            return True
    return False


def _lines(path):
    text, _ = read_text(path)
    return text.splitlines() if text else None


def packaging_notes(root):
    """Notes on packaging rules that would ship an agent directory."""
    notes = []
    present = sorted(d for d in AGENT_DIRS if os.path.isdir(os.path.join(root, d)))
    if not present:
        return notes
    text, _ = read_text(os.path.join(root, "package.json"))
    if text:
        try:
            pkg = json.loads(text)
        except ValueError:
            pkg = None
        if isinstance(pkg, dict) and not pkg.get("private") and "files" not in pkg:
            npmignore = _lines(os.path.join(root, ".npmignore"))
            rules, source = (npmignore, ".npmignore") if npmignore is not None \
                else (_lines(os.path.join(root, ".gitignore")) or [], ".gitignore")
            exposed = [d for d in present if not _ignore_covers(rules, d)]
            if exposed:
                why = "an .npmignore replaces .gitignore entirely" \
                    if source == ".npmignore" else "nothing excludes it"
                notes.append("npm would publish %s: package.json has no `files` allowlist "
                             "and %s (%s)." % (", ".join(exposed), why, source))
    try:
        names = sorted(os.listdir(root))
    except OSError:
        names = []
    for name in names:
        if not (name == "Dockerfile" or name.startswith("Dockerfile.")
                or name.endswith(".Dockerfile") or name == "Containerfile"):
            continue
        body = _lines(os.path.join(root, name)) or []
        if not any(re.match(r"^\s*(COPY|ADD)\s+(--\S+\s+)*\.\s", ln, re.I) for ln in body):
            continue
        rules = _lines(os.path.join(root, ".dockerignore")) or []
        exposed = [d for d in present if not _ignore_covers(rules, d)]
        if exposed:
            notes.append("%s copies the whole build context and .dockerignore does not "
                         "exclude %s: the image would carry it." % (name, ", ".join(exposed)))
    return notes


# --------------------------------------------------------------------------
# Emission. Nothing below prints a value, a fragment, a length or a digest.
# --------------------------------------------------------------------------

class Ordinals:
    """S1, S2... per distinct value, so the same credential in three files
    reads as one credential. The key lives in memory for one run and the
    digest is never printed, so an ordinal cannot be reversed or compared
    across runs."""

    def __init__(self):
        self._key = os.urandom(32)
        self._seen = {}

    def of(self, value):
        d = hmac.new(self._key, value.encode("utf-8", "replace"), hashlib.sha256).digest()
        return "S%d" % self._seen.setdefault(d, len(self._seen) + 1)

    def distinct(self):
        return len(self._seen)


def _scrub(text, values):
    """Last line of defence: no blocking value survives into output, even
    where a path or a key name happened to contain it."""
    for v in values:
        if v in text:
            text = text.replace(v, "<redacted>")
        # The same value as a name filter would have left it.
        plain = re.sub(r"[^A-Za-z0-9_.\-]", "", v)
        if len(plain) >= 6 and plain in text:
            text = text.replace(plain, "<redacted>")
    for _label, _sev, v in list(prefix_hits(text)):
        text = text.replace(v, "<redacted>")
    return text


def build_report(scanned, raw, notes, skipped):
    """Turn [(file, git, where, sink, severity, value)] into printable rows."""
    ordinals = Ordinals()
    blocking = [v for *_x, sev, v in raw if sev in (HIGH, MEDIUM) and len(v) >= 6]
    rank = {HIGH: 0, MEDIUM: 1, INFO: 2}
    rows = []
    for file, git, where, sink, sev, value in sorted(raw, key=lambda r: (rank[r[4]], r[0], r[2])):
        rows.append({
            "severity": sev,
            "file": _scrub(file, blocking),
            "where": _scrub(where, blocking),
            "sink": _scrub(sink, blocking),
            "credential": ordinals.of(value) if value and sev != INFO else None,
            "git": git,
        })
    return {
        "tool": "agent-secret-guard", "version": VERSION, "scanned": scanned,
        "distinct_credentials": ordinals.distinct(),
        "findings": rows,
        "notes": [_scrub(n, blocking) for n in notes],
        "skipped": [{"file": _scrub(f, blocking), "reason": r} for f, r in skipped],
    }


def print_report(report, out=sys.stdout):
    rows = report["findings"]
    block = [r for r in rows if r["severity"] in (HIGH, MEDIUM)]
    for r in rows:
        tail = ""
        if r["credential"]:
            tail += "  [%s]" % r["credential"]
        if r["git"] in GIT_LABEL and r["severity"] != INFO:
            tail += "  (%s)" % GIT_LABEL[r["git"]]
        out.write("%-6s %s  %s  %s%s\n" % (r["severity"].upper(), r["file"], r["where"],
                                           r["sink"], tail))
    for n in report["notes"]:
        out.write("NOTE   %s\n" % n)
    for s in report["skipped"]:
        out.write("SKIP   %s  (%s)\n" % (s["file"], s["reason"]))
    if rows or report["notes"] or report["skipped"]:
        out.write("\n")
    out.write("%d file(s) scanned, %d finding(s) to act on, %d distinct credential(s).\n"
              % (report["scanned"], len(block), report["distinct_credentials"]))
    if any(r["git"] != "user-level" for r in block):
        out.write("Rotate each credential before removing it: a value that reached a "
                  "file an agent wrote may already be in a transcript or a commit.\n")
    if any(r["git"] == "user-level" for r in block):
        out.write("User-level files do not reach a repository by themselves, but they hold "
                  "these values in plaintext for every agent and process running as this "
                  "user. Where the tool supports it, replace the literal with a reference "
                  "to an environment variable or a credential helper.\n")


# --------------------------------------------------------------------------
# Subcommands
# --------------------------------------------------------------------------

def _display_home(rel):
    return "~/" + rel.replace(os.sep, "/")


def cmd_scan(opts):
    root = os.path.abspath(opts["root"])
    if not os.path.isdir(root):
        sys.stderr.write("agent-secret-guard: not a directory\n")
        return 2
    raw, notes, skipped, scanned = [], [], [], 0
    states = {}

    def state(rel):
        if rel not in states:
            states[rel] = git_state(root, rel)
        return states[rel]

    def take(label, git, text):
        for where, sink, sev, value in scan_text(label, text):
            raw.append((label, git() if callable(git) else git, where, sink, sev, value))

    if opts["staged"]:
        staged = staged_files(root)
        if staged is None:
            sys.stderr.write("agent-secret-guard: --staged needs a git repository\n")
            return 2
        for rel, text in staged:
            scanned += 1
            take(rel + " (staged)", "staged", text)
    else:
        for rel in discover(root):
            text, why = read_text(os.path.join(root, rel))
            if text is None:
                skipped.append((rel, why))
                continue
            scanned += 1
            take(rel, lambda rel=rel: state(rel), text)
            # A per-machine settings file is where an approved command is
            # stored verbatim. It should never be something git can take.
            if os.path.basename(rel).endswith(".local.json") and state(rel) in ("tracked", "untracked"):
                notes.append("%s is a per-machine agent file and is %s."
                             % (rel, GIT_LABEL[state(rel)].split(":")[0]))
        if scanned + len(skipped) >= MAX_FILES:
            notes.append("Stopped at %d files; the rest of the tree was not read." % MAX_FILES)
        notes.extend(packaging_notes(root))
    if opts["history"]:
        past, truncated = history_files(root)
        if past is None:
            sys.stderr.write("agent-secret-guard: --history needs a git repository\n")
            return 2
        for label, text in past:
            scanned += 1
            take(label, "tracked", text)
        if truncated:
            notes.append("History scan stopped at %d file versions; older ones were not read."
                         % MAX_HISTORY_BLOBS)
    if opts["user"] or opts["transcripts"]:
        home = os.path.expanduser("~")

        def user_state(rel):
            # A home directory kept in git (a dotfiles repository) changes
            # the answer: say so instead of calling the file merely local.
            st = git_state(home, rel)
            return st if st in ("tracked", "untracked") else "user-level"
        for rel in discover_user(home, opts["transcripts"]):
            text, why = read_text(os.path.join(home, rel), follow=True)
            if text is None:
                skipped.append((_display_home(rel), why))
                continue
            scanned += 1
            take(_display_home(rel), lambda rel=rel: user_state(rel), text)
    report = build_report(scanned, raw, notes, skipped)
    if opts["json"]:
        json.dump(report, sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        print_report(report)
    return 1 if any(r["severity"] in (HIGH, MEDIUM) for r in report["findings"]) else 0


DENY_ADVICE = (
    "Approving it would store the credential verbatim in the agent's permission "
    "file and in the session transcript. Run it with the credential passed by "
    "reference instead: an environment variable that is already set outside this "
    "session ($NAME), a file the tool reads itself (--password-file, ~/.pgpass, "
    ".netrc, --env-file), or a secret-manager lookup. If the value is not available "
    "that way, stop and ask the user to provide it out of band. Do not retry with "
    "the value encoded, split, quoted differently or moved to another argument."
)


def cmd_check(opts):
    """PreToolUse hook: read the hook's JSON on stdin, deny a command that
    carries a literal credential. Reads nothing from argv, so the command
    is never copied into a process list."""
    try:
        event = json.load(sys.stdin)
        if not isinstance(event, dict):
            raise ValueError
    except (ValueError, RecursionError):
        sys.stderr.write("agent-secret-guard: could not read the hook input; "
                         "refusing rather than guessing.\n")
        return 2
    tool_input = event.get("tool_input")
    command = tool_input.get("command") if isinstance(tool_input, dict) else None
    if not isinstance(command, str):
        command = event.get("command") if isinstance(event.get("command"), str) else None
    if not command:
        return 0
    hits = [h for h in scan_command(command) if h[1] in (HIGH, MEDIUM)]
    if not hits:
        return 0
    values = [v for _s, _sev, v in hits]
    sinks = sorted({_scrub(s, values) for s, _sev, _v in hits})
    reason = "Blocked by agent-secret-guard: this command carries a literal credential (%s). %s" % (
        "; ".join(sinks[:4]) + ("; and %d more" % (len(sinks) - 4) if len(sinks) > 4 else ""),
        DENY_ADVICE)
    if opts["format"] == "exit":
        sys.stderr.write(reason + "\n")
        return 2
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    }}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def cmd_sinks(_opts):
    """Print the catalogue from the tables the scanner actually uses."""
    w = sys.stdout.write
    w("agent-secret-guard %s: sink catalogue\n\n" % VERSION)
    w("Names that mark a value as a credential (strong):\n  %s\n" % ", ".join(sorted(_STRONG_SINGLE)))
    w("  pairs: %s\n" % ", ".join(sorted("%s %s" % p for p in _STRONG_PAIRS)))
    w("  fused endings: %s\n" % ", ".join(_FUSED_SUFFIX))
    w("Names that need a secret-shaped value as well (weak):\n  %s\n" % ", ".join(sorted(_WEAK_SINGLE)))
    w("\nPrograms with known credential arguments (%d):\n" % len(PROGRAMS))
    for prog in sorted(PROGRAMS):
        parts = []
        for e in PROGRAMS[prog]:
            sub = " ".join(e["when"])
            flags = sorted(k for k, v in e["flags"].items() if v) + sorted(k for k, v in e["prefix"].items() if v)
            pos = ["argument %d" % (n + 1) for n, k in sorted(e["positional"].items()) if k != "name"]
            if e["rest"]:
                pos.append("key=value arguments")
            if flags or pos:
                parts.append((sub + ": " if sub else "") + ", ".join(flags + pos))
        if parts:
            w("  %-18s %s\n" % (prog, " | ".join(parts)))
    w("\nCredential headers:\n  %s\n" % ", ".join(sorted(_CRED_HEADERS)))
    w("\nFlags that read a credential from standard input:\n  %s\n" % ", ".join(sorted(STDIN_CONSUMERS)))
    w("\nToken formats recognised anywhere (%d):\n  %s\n"
      % (len(_PREFIX_PATTERNS), ", ".join(sorted({p[0] for p in _PREFIX_PATTERNS}))))
    return 0


def cmd_selftest(_opts):
    """Prove, where the hook will actually run, that a literal is denied and
    a reference is not. The literal is assembled here so that no
    credential-shaped text ships in this file or in a fixture beside it."""
    fake = "x".join(("Qw3", "rT8", "zL5", "pN2"))
    blocking = lambda cmd: any(h[1] in (HIGH, MEDIUM) for h in scan_command(cmd))
    ok = (blocking("mysql -u app -p%s acme" % fake)
          and blocking("curl -H 'Authorization: Bearer %s' https://example.com" % fake)
          and not blocking('mysql -u app -p"$DB_PASSWORD" acme')
          and not blocking("curl -H \"Authorization: Bearer $ACME_TOKEN\" https://example.com"))
    if not ok:
        sys.stderr.write("agent-secret-guard: self-test FAILED; do not install the hook.\n")
        return 2
    sys.stdout.write("agent-secret-guard %s: self-test passed "
                     "(literal denied, reference allowed).\n" % VERSION)
    return 0


USAGE = """usage: agent_secrets.py scan [ROOT] [--user] [--transcripts] [--staged] [--history] [--json]
       agent_secrets.py check-cmd [--format json|exit]     (hook JSON on stdin)
       agent_secrets.py sinks
       agent_secrets.py selftest

scan       audit the files AI coding agents write: permission rules, MCP
           configuration, hook definitions, rules files, transcripts
  --user         also the user-level agent configuration in the home directory
  --transcripts  also session transcripts (large; implies reading the home directory)
  --staged       only what is staged in git, read from the index (for a pre-commit hook)
  --history      also every past version of those files in git history
  --json         machine-readable report
check-cmd  PreToolUse hook: deny a shell command that carries a literal credential
sinks      print the catalogue of what is recognised
selftest   check that a literal is denied and a reference allowed, before
           the hook is installed

Exit status: 0 nothing to act on, 1 findings, 2 could not run.
No credential, fragment of one, length or digest is ever printed.
"""


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] in ("-h", "--help", "help"):
        sys.stdout.write(USAGE)
        return 0 if argv else 2
    if argv[0] == "--version":
        sys.stdout.write(VERSION + "\n")
        return 0
    sub, rest = argv[0], argv[1:]
    if sub == "scan":
        opts = {"root": ".", "user": False, "transcripts": False, "staged": False,
                "history": False, "json": False}
        roots = []
        for a in rest:
            if a.startswith("--") and a[2:] in opts and a != "--root":
                opts[a[2:]] = True
            elif a.startswith("-"):
                sys.stderr.write("agent-secret-guard: unknown option for scan\n" + USAGE)
                return 2
            else:
                roots.append(a)
        if len(roots) > 1:
            sys.stderr.write("agent-secret-guard: scan takes one directory\n")
            return 2
        if roots:
            opts["root"] = roots[0]
        return cmd_scan(opts)
    if sub == "check-cmd":
        fmt = "json"
        if rest[:1] == ["--format"] and rest[1:2] in (["json"], ["exit"]) and len(rest) == 2:
            fmt = rest[1]
        elif rest:
            # Deliberately no way to pass the command as an argument.
            sys.stderr.write("agent-secret-guard: check-cmd reads the hook JSON on stdin only\n")
            return 2
        return cmd_check({"format": fmt})
    if sub == "sinks" and not rest:
        return cmd_sinks({})
    if sub == "selftest" and not rest:
        return cmd_selftest({})
    sys.stderr.write("agent-secret-guard: unknown command\n" + USAGE)
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        sys.exit(1)
