"""Tests for agent-secret-guard.

Run from the repository root:

    python3 -m unittest discover -s security-skills/tests

Every credential-shaped fixture is assembled at run time from pieces, so
this file never contains a string that a scanner - this one or anybody
else's - would read as a secret.
"""
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.join(HERE, os.pardir, "agent-secret-guard", "scripts")
SCRIPT = os.path.join(SCRIPTS, "agent_secrets.py")
sys.path.insert(0, SCRIPTS)

import agent_secrets as A  # noqa: E402

# A password-shaped value and a few vendor-shaped ones, never written whole.
S = "".join(["Zq7", "vK2", "mXw", "9Rt", "4Lp", "8Nd"])
S2 = "".join(["Jh5", "yB1", "cFu", "6Gs", "3Wa", "0Ee"])
GH = "gh" + "p_" + "a1B2c3D4e5" * 4
AWS = "AK" + "IA" + "Q2W3E4R5T6Y7U2I3"
JWT = ".".join(["ey" + "J" + "hbGciOiJIUzI1NiJ9", "ey" + "J" + "zdWIiOiIxMjM0NTY3ODkwIn0", "c2lnbmF0dXJlLXZhbHVl"])
GC = "git " + "commit"

ACT = (A.HIGH, A.MEDIUM)


def acted(cmd):
    return [h for h in A.scan_command(cmd) if h[1] in ACT]


def fragments(value, n=6):
    return {value[i:i + n] for i in range(len(value) - n + 1)}


class KeyNames(unittest.TestCase):
    def test_strong(self):
        for name in ("password", "PGPASSWORD", "apiKey", "api_key", "client-secret", "DB_PASS",
                     "authToken", "GITHUB_TOKEN", "secretAccessKey", "private_key", "_authToken"):
            self.assertEqual(A.key_class(name), "strong", name)

    def test_weak(self):
        for name in ("auth", "credentials", "cookie", "session", "dsn"):
            self.assertEqual(A.key_class(name), "weak", name)

    def test_a_weak_word_counts_only_at_the_end(self):
        for n in ("auth", "basic_auth", "sessionCookie", "X-Session"):
            self.assertEqual(A.key_class(n), "weak", n)
        for n in ("authUserLookup", "APP_AUTH_EMULATOR", "apiKeyVisible", "tokenValidator",
                  "passwordResetService", "TOKEN_SRC", "secretMissing"):
            self.assertIsNone(A.key_class(n), n)

    def test_not_a_credential(self):
        for name in ("maxTokens", "max_tokens", "tokenizer", "passive", "public_key", "keyboard",
                     "apiKeyHelper", "password_file", "token_path", "PUBLISHABLE_KEY", "secret_name",
                     "primaryKey", "sort_key", "author", "bypass"):
            self.assertIsNone(A.key_class(name), name)


class Values(unittest.TestCase):
    def test_references_are_not_literals(self):
        for v in ("$TOKEN", "${TOKEN}", "${env:TOKEN}", "$(cat /run/secret)", "`pass show x`",
                  "%TOKEN%", "{{ secrets.TOKEN }}", "${{ secrets.TOKEN }}", "Bearer $TOKEN",
                  "@/run/secrets/key", "<your-token>", "YOUR_API_KEY", "xxxxxxxxxxxx", "changeme", "*", ""):
            self.assertNotEqual(A.value_class(v), A.LITERAL, v)

    def test_escaped_substitution_and_self_naming_words(self):
        self.assertEqual(A.value_class("$\\(python3 -c 'print(1)'\\)"), A.COMMAND_SUB)
        for v in ("dev-signing-key", "some_api_token", "the-shared-secret"):
            self.assertEqual(A.value_class(v), A.PLACEHOLDER, v)
        self.assertEqual(A.value_class("correct-horse-battery-staple"), A.LITERAL)

    def test_literal(self):
        for v in (S, GH, "Bearer " + S):
            self.assertEqual(A.value_class(v), A.LITERAL)


class CommandsThatCarryOne(unittest.TestCase):
    CASES = [
        "PGPASSWORD=%s psql -h db.example.com -U app",
        "curl -u admin:%s https://example.com/api",
        "curl -H 'Authorization: Bearer %s' https://example.com/api",
        "curl -sS -H \"X-API-Key: %s\" https://example.com/api",
        "mysql -u root -p%s appdb",
        "mysql --user=root --password=%s appdb",
        "docker login -u acme -p %s registry.example.com",
        "echo %s | docker login -u acme --password-stdin registry.example.com",
        "docker login --password-stdin registry.example.com <<< %s",
        "sudo -E env API_TOKEN=%s ./deploy.sh",
        "kubectl create secret generic app --from-literal=password=%s",
        "sshpass -p %s ssh deploy@example.com",
        "export DEPLOY_TOKEN=%s",
        "acme-cli --api-key %s sync",
        "acme-cli --token=%s sync",
        "git clone https://deploy:%s@example.com/owner/repo.git",
        "psql postgresql://app:%s@db.example.com:5432/app",
        "npm config set //registry.example.com/:_authToken %s",
        "cargo login %s",
        "openssl enc -aes-256-cbc -pass pass:%s -in a -out b",
        "htpasswd -cb .htpasswd acme %s",
        "vault kv put secret/app password=%s",
        "RESULT=$(curl -u acme:%s https://example.com)",
        "gh secret set DEPLOY -b %s",
        "timeout 30 env DB_PASSWORD=%s ./migrate",
        "redis-cli -a %s ping",
        "wget --password=%s https://example.com/f",
        "terraform apply -var db_password=%s",
        "mvn deploy -Drepo.password=%s",
        "cd app && DB_PASS=%s npm run migrate",
    ]

    def test_each_is_caught(self):
        for case in self.CASES:
            hits = acted(case % S)
            self.assertTrue(hits, case)
            self.assertTrue(any(S in v for _s, _sev, v in hits), case)

    def test_nested_shell_is_caught(self):
        self.assertTrue(acted("bash -c 'PGPASSWORD=%s psql -h db'" % S))
        self.assertTrue(acted("ssh host \"mysql -u root -p%s db\"" % S))

    def test_vendor_token_anywhere(self):
        for cmd in ("echo %s", "some-tool run --note %s", "curl https://example.com/?x=%s"):
            self.assertTrue(acted(cmd % GH), cmd)
        self.assertTrue(acted("aws-thing --id %s" % AWS))
        self.assertTrue(acted("curl -H 'X-Thing: %s' https://example.com" % JWT))

    def test_sink_never_names_the_value(self):
        for case in self.CASES:
            for sink, _sev, _v in A.scan_command(case % S):
                self.assertNotIn(S, sink, case)


class CommandsThatDoNot(unittest.TestCase):
    CASES = [
        "date -u",
        "ls -la",
        "docker run -p 8080:80 -e NODE_ENV=production nginx",
        "mysql -u root -p appdb",
        "psql --password -h db.example.com app",
        "ssh -p 2222 deploy@example.com",
        "llm --max-tokens 4096 --temperature 0.2 prompt.txt",
        "PGPASSWORD=$PGPASSWORD psql -h db",
        "PGPASSWORD=\"$(pass show db/app)\" psql -h db",
        "curl -H \"Authorization: Bearer $API_TOKEN\" https://example.com",
        "curl -H \"Authorization: Bearer ${API_TOKEN}\" https://example.com",
        "curl -u \"$USER:$PASS\" https://example.com",
        "docker login -u acme --password-stdin registry.example.com < token.txt",
        "cat token.txt | docker login -u acme --password-stdin registry.example.com",
        "export API_TOKEN=<your-token>",
        "acme-cli --api-key YOUR_API_KEY sync",
        "grep -rn 'password=' src/",
        "rg --files -g '*token*'",
        GC + " -m 'rotate the api token and password handling'",
        "sshpass -f pwfile ssh deploy@example.com",
        "mysql --defaults-extra-file=my.cnf appdb",
        "restic --password-file /run/secrets/restic backup /data",
        "GIT_ASKPASS=/usr/local/bin/askpass git fetch",
        "git clone https://example.com/owner/repo.git",
        "git clone git@example.com:owner/repo.git",
        "npm install --save-dev @types/node",
        "kubectl get secret app -o jsonpath='{.data.password}'",
        "echo 'set the TOKEN variable before running'",
        "python3 -c 'import secrets; print(secrets.token_hex(16))'",
        "tar -czpf backup.tgz dir",
        "unzip -P \"$ZIP_PASSWORD\" archive.zip",
        "openssl rand -hex 32",
        "find . -name '*.key' -newer stamp",
    ]

    def test_each_is_clean(self):
        for case in self.CASES:
            self.assertEqual(acted(case), [], case)

    def test_a_well_known_default_is_reported_but_never_blocks(self):
        hits = A.scan_command("PGPASSWORD=postgres psql -h localhost")
        self.assertEqual([h for h in hits if h[1] in ACT], [])


def scan(name, text):
    return [(where, sink, sev) for where, sink, sev, _v in A.scan_text(name, text) if sev in ACT]


class Files(unittest.TestCase):
    def settings(self, **extra):
        doc = {"permissions": {"allow": [
            "Bash(npm run test:*)",
            "Bash(PGPASSWORD=%s psql -h db.example.com:*)" % S,
            "Read(//etc/hosts)",
        ]}}
        doc.update(extra)
        return json.dumps(doc, indent=2)

    def test_an_approved_command_is_found_in_the_permission_list(self):
        hits = scan(".claude/settings.local.json", self.settings())
        self.assertEqual(len(hits), 1)
        self.assertIn("permissions.allow[1]", hits[0][0])
        self.assertEqual(hits[0][2], A.HIGH)

    def test_other_harnesses_rule_spellings(self):
        for rule in ("Shell(curl -u acme:%s https://example.com)", "run_shell_command(mysql -uroot -p%s db)"):
            self.assertTrue(scan(".gemini/settings.json", json.dumps({"tools": {"allowed": [rule % S]}})), rule)

    def test_env_block(self):
        text = self.settings(env={"API_TOKEN": S2, "NODE_ENV": "production", "OTHER_TOKEN": "${OTHER_TOKEN}"})
        wheres = [w for w, _s, _sev in scan(".claude/settings.json", text)]
        self.assertTrue(any("env.API_TOKEN" in w for w in wheres))
        self.assertFalse(any("NODE_ENV" in w or "OTHER_TOKEN" in w for w in wheres))

    def test_mcp_server_arguments_headers_and_url(self):
        doc = {"mcpServers": {
            "db": {"command": "npx", "args": ["-y", "acme-mcp", "--api-key", S]},
            "http": {"url": "https://example.com/mcp?api_key=" + S2, "headers": {"Authorization": "Bearer " + S}},
            "ok": {"command": "npx", "args": ["-y", "acme-mcp", "--api-key", "${ACME_KEY}"],
                   "headers": {"Authorization": "Bearer ${ACME_KEY}"}},
        }}
        wheres = [w for w, _s, _sev in scan(".mcp.json", json.dumps(doc))]
        self.assertTrue(any(w.startswith("mcpServers.db") for w in wheres))
        self.assertTrue(any("mcpServers.http.headers" in w for w in wheres))
        self.assertTrue(any("mcpServers.http.url" in w for w in wheres))
        self.assertFalse(any("mcpServers.ok" in w for w in wheres))

    def test_credential_named_key(self):
        self.assertTrue(scan(".cursor/mcp.json", json.dumps({"server": {"apiKey": S}})))
        self.assertEqual(scan(".claude/settings.json", json.dumps(
            {"apiKeyHelper": "/usr/local/bin/key-helper", "maxTokens": 4096, "tokenBudget": 20000})), [])

    def test_json_with_comments_and_trailing_commas(self):
        text = '{\n  // local overrides\n  "env": {"DB_PASSWORD": "%s",},\n}\n' % S
        self.assertTrue(scan(".vscode/mcp.json", text))

    def test_transcript_lines(self):
        line = json.dumps({"type": "tool_use", "name": "Bash", "input": {"command": "curl -u acme:%s https://example.com" % S}})
        hits = scan("session.jsonl", "{}\n" + line + "\n")
        self.assertTrue(hits)
        self.assertTrue(hits[0][0].startswith("line 2"))

    def test_toml_and_yaml(self):
        if A.tomllib is not None:
            self.assertTrue(scan(".codex/config.toml", '[mcp_servers.db.env]\nDB_PASSWORD = "%s"\n' % S))
        self.assertTrue(scan(".continue/config.yaml", "models:\n  - name: acme\n    apiKey: %s\n" % S))
        self.assertEqual(scan(".continue/config.yaml", "models:\n  - name: acme\n    apiKey: ${{ secrets.ACME }}\n"), [])

    def test_markdown_is_read_for_tokens_and_fenced_commands_only(self):
        md = "# Notes\n\nSet the password before you start, then run:\n\n```bash\nmysql -u root -p%s app\n```\n" % S
        hits = scan("CLAUDE.md", md)
        self.assertTrue(hits)
        self.assertTrue(all(sev == A.MEDIUM for _w, _s, sev in hits))
        self.assertEqual(scan("CLAUDE.md", "The api key: rotate it monthly. password = whatever you like\n"), [])
        self.assertTrue(scan("AGENTS.md", "token is %s\n" % GH))

    def test_code_and_prose_under_a_credential_name_are_not_findings(self):
        # Scripts on the agent surface read credentials and talk about them;
        # neither is one.
        clean = [
            "TOKEN = os.environ['ACME_TOKEN']",
            "TOKEN = os.environ.get('ACME_TOKEN')",
            "const token = process.env.ACME_TOKEN",
            "api_key = settings.acme_api_key",
            "password = getpass.getpass()",
            'TOKEN_SRC="the ACME_TOKEN in your environment"',
            'echo "token source: ${TOKEN_SRC:-unknown}"',
            'echo "using ${TOKEN:-nothing}"',
            'say "  Token: Tracker > Profile > Account Security > New token."',
            '<registryKey key="my.feature.enabled" value="true"/>',
            'password: "ask the person who set it up"',
        ]
        for line in clean:
            self.assertEqual(scan("setup.sh", line + "\n"), [], line)
        # The real thing in the same positions still is.
        self.assertTrue(scan("setup.sh", "TOKEN = '%s'\n" % S))
        self.assertTrue(scan("setup.sh", "password: %s\n" % S))
        self.assertTrue(scan("setup.sh", "password: %s  # set in March\n" % S))

    def test_a_fence_is_read_as_commands_only_when_it_is_shell(self):
        xml = "```xml\n<registryKey key=\"my.feature.enabled\" value=\"true\"/>\n```\n"
        self.assertEqual(scan("SKILL.md", xml), [])
        kt = "```kotlin\nval client = Client(password = %s)\n```\n" % ("pw" + "Value")
        self.assertEqual(scan("SKILL.md", kt), [])
        for lang in ("", "sh", "bash", "console"):
            md = "```%s\n$ mysql -u root -p%s app\n```\n" % (lang, S)
            self.assertTrue(scan("SKILL.md", md), lang)
        # A vendor token is a finding in any fence.
        self.assertTrue(scan("SKILL.md", "```json\n{\"note\": \"%s\"}\n```\n" % GH))

    def test_a_private_key_needs_a_body(self):
        head = "-----BEGIN " + "PRIVATE KEY-----"
        body = "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC" + "BKcwggSjAgEAAoIBAQC7"
        # A pattern list, or prose about key formats, has the header only.
        self.assertEqual(scan("auditor.md", "  /%s/g,\n  /other/g,\n" % head), [])
        self.assertEqual(scan("notes.md", "Keys start with `%s`.\n" % head), [])
        self.assertTrue(scan("notes.md", "%s\n%s\n" % (head, body)))
        self.assertTrue(scan("settings.json", json.dumps({"env": {"SIGNING": head + "\n" + body}})))
        self.assertTrue(acted("echo '%s\\n%s' > k.pem" % (head, body)))

    def test_identifiers_under_vague_names_are_not_findings(self):
        uid = "-".join(["3f2b8c1e", "9a4d", "4e6f", "8b1a", "7c5d2e9f0a1b"])
        digest = "9f2c" * 8
        self.assertEqual(scan("log.jsonl", json.dumps({"session": uid, "key": "v1:" + digest}) + "\n"), [])
        # The public half of a telemetry DSN is published by design.
        self.assertEqual(scan("settings.json", json.dumps({"dsn_url": "https://%s@o1.ingest.example.com/2" % digest})), [])
        # A password in the same URL is still one.
        self.assertTrue(scan("settings.json", json.dumps({"u": "https://%s:%s@o1.ingest.example.com/2" % (digest, S)})))

    def test_broken_json_still_gets_the_text_pass(self):
        out = A.scan_text(".claude/settings.json", '{"env": {"API_TOKEN": "%s"' % GH)
        self.assertTrue(any(sev == A.INFO for _w, _s, sev, _v in out))
        self.assertTrue(any(sev in ACT for _w, _s, sev, _v in out))

    def test_surface(self):
        for rel in (".claude/settings.local.json", ".mcp.json", "CLAUDE.md", "AGENTS.md", ".cursor/mcp.json",
                    ".vscode/mcp.json", "packages/api/.claude/settings.json", ".gemini/settings.json"):
            self.assertTrue(A.is_surface(rel), rel)
        for rel in ("src/main.py", "README.md", "package.json", ".vscode/launch.json", ".claude/hooks/guard.py"):
            self.assertFalse(A.is_surface(rel), rel)


class NothingLeaks(unittest.TestCase):
    """The report is read by an agent and lands in a transcript. It must not
    carry the credential, a piece of it, its length or a digest of it."""

    def raw(self):
        raw = []
        for where, sink, sev, value in A.scan_text(".claude/settings.local.json", json.dumps({
                "permissions": {"allow": ["Bash(PGPASSWORD=%s psql:*)" % S, "Bash(curl -u acme:%s https://example.com)" % S]},
                "env": {"GITHUB_TOKEN": GH}, "servers": {GH: {"note": "a token used as a key"}}})):
            raw.append((".claude/settings.local.json", "untracked", where, sink, sev, value))
        return raw

    def check(self, text):
        for secret in (S, GH):
            for frag in fragments(secret):
                self.assertNotIn(frag, text)
            self.assertNotIn(str(len(secret)), text.replace("S1", "").replace("S2", ""))

    def test_text_report(self):
        report = A.build_report(1, self.raw(), ["a note"], [("big.jsonl", "too large")])
        buf = io.StringIO()
        A.print_report(report, buf)
        self.check(buf.getvalue())
        self.assertIn("[S1]", buf.getvalue())

    def test_json_report(self):
        report = A.build_report(1, self.raw(), [], [])
        self.check(json.dumps(report))
        self.assertEqual(set(report["findings"][0]), {"severity", "file", "where", "sink", "credential", "git"})

    def test_one_credential_in_two_places_is_one_credential(self):
        report = A.build_report(1, self.raw(), [], [])
        by = {}
        for f in report["findings"]:
            by.setdefault(f["credential"], []).append(f)
        self.assertEqual(report["distinct_credentials"], len(by))
        self.assertTrue(any(len(v) > 1 for v in by.values()))

    def test_ordinals_do_not_survive_the_run(self):
        a, b = A.Ordinals(), A.Ordinals()
        self.assertEqual(a.of(S), "S1")
        self.assertEqual(a.of(S2), "S2")
        self.assertEqual(a.of(S), "S1")
        self.assertEqual(b.of(S2), "S1")
        self.assertNotEqual(a._key, b._key)


def run(args, stdin="", cwd=None):
    p = subprocess.run([sys.executable, SCRIPT] + args, input=stdin, capture_output=True, text=True, cwd=cwd)
    return p.returncode, p.stdout, p.stderr


class Hook(unittest.TestCase):
    def event(self, command):
        return json.dumps({"hook_event_name": "PreToolUse", "tool_name": "Bash", "cwd": "/work",
                           "tool_input": {"command": command}})

    def test_clean_command_passes_silently(self):
        self.assertEqual(run(["check-cmd"], self.event("npm test")), (0, "", ""))

    def test_literal_credential_is_denied_without_being_echoed(self):
        code, out, err = run(["check-cmd"], self.event("PGPASSWORD=%s psql -h db" % S))
        self.assertEqual(code, 0)
        decision = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(decision["hookEventName"], "PreToolUse")
        self.assertEqual(decision["permissionDecision"], "deny")
        for frag in fragments(S):
            self.assertNotIn(frag, out + err)

    def test_exit_format_blocks_with_status_two(self):
        code, out, err = run(["check-cmd", "--format", "exit"], self.event("curl -u acme:%s https://example.com" % S))
        self.assertEqual((code, out), (2, ""))
        self.assertIn("Blocked by agent-secret-guard", err)
        for frag in fragments(S):
            self.assertNotIn(frag, err)

    def test_unreadable_input_fails_closed(self):
        for bad in ("", "not json", "[1, 2]"):
            self.assertEqual(run(["check-cmd"], bad)[0], 2, bad)

    def test_other_tools_and_missing_commands_pass(self):
        self.assertEqual(run(["check-cmd"], json.dumps({"tool_name": "Read", "tool_input": {"file_path": "a"}}))[0], 0)

    def test_the_command_cannot_be_passed_as_an_argument(self):
        self.assertEqual(run(["check-cmd", "PGPASSWORD=%s psql" % S])[0], 2)

    def test_selftest_passes_and_prints_no_literal(self):
        code, out, err = run(["selftest"])
        self.assertEqual((code, err), (0, ""))
        self.assertIn("self-test passed", out)
        self.assertEqual(len(out.splitlines()), 1)

    @unittest.skipUnless(os.name == "posix" and shutil.which("sh"), "needs a POSIX shell")
    def test_the_wrapper_finds_python_with_an_empty_environment(self):
        wrapper = os.path.join(SCRIPTS, "guard-command.sh")
        self.assertTrue(os.access(wrapper, os.X_OK))
        sh = shutil.which("sh")
        ok = subprocess.run([sh, wrapper, "--self-test"], env={}, capture_output=True, text=True)
        self.assertEqual(ok.returncode, 0, ok.stderr)
        deny = subprocess.run([sh, wrapper], env={}, capture_output=True, text=True,
                              input=self.event("PGPASSWORD=%s psql -h db" % S))
        self.assertEqual(json.loads(deny.stdout)["hookSpecificOutput"]["permissionDecision"], "deny")
        clean = subprocess.run([sh, wrapper], env={}, capture_output=True, text=True, input=self.event("npm test"))
        self.assertEqual((clean.returncode, clean.stdout), (0, ""))

    def test_the_skill_does_not_trip_its_own_scanner(self):
        skill = os.path.join(SCRIPTS, os.pardir)
        for base, _dirs, names in os.walk(skill):
            for name in names:
                if name.endswith((".md", ".sh")):
                    with open(os.path.join(base, name), encoding="utf-8") as fh:
                        rows = [(w, k) for w, k, sev, _v in A.scan_text(name, fh.read()) if sev in (A.HIGH, A.MEDIUM)]
                    self.assertEqual(rows, [], name)


class Scan(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="asg-")
        self.addCleanup(shutil.rmtree, self.root, True)

    def write(self, rel, text):
        path = os.path.join(self.root, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)

    def git(self, *args):
        subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false"]
                       + list(args), cwd=self.root, check=True, capture_output=True)

    def leaky(self):
        return json.dumps({"permissions": {"allow": ["Bash(PGPASSWORD=%s psql -h db:*)" % S]}})

    def test_clean_tree(self):
        self.write(".claude/settings.json", json.dumps({"permissions": {"allow": ["Bash(npm test:*)"]}}))
        code, out, _err = run(["scan", self.root])
        self.assertEqual(code, 0)
        self.assertIn("1 file(s) scanned", out)

    def test_finding_sets_the_exit_status_and_stays_redacted(self):
        self.write(".claude/settings.local.json", self.leaky())
        self.write("node_modules/pkg/.claude/settings.local.json", self.leaky())
        self.write("src/config.py", "PASSWORD = '%s'\n" % S)
        code, out, err = run(["scan", self.root])
        self.assertEqual(code, 1)
        self.assertIn("HIGH", out)
        self.assertNotIn("node_modules", out)
        self.assertNotIn(self.root, out)
        for frag in fragments(S):
            self.assertNotIn(frag, out + err)
        code, out, _err = run(["scan", self.root, "--json"])
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["distinct_credentials"], 1)

    def test_git_state_staged_and_history(self):
        if shutil.which("git") is None:
            self.skipTest("git is not installed")
        self.git("init", "-q")
        # A developer's global excludes file may already cover agent files;
        # the test has to see the repository as a fresh clone would.
        self.git("config", "core.excludesFile", os.path.join(self.root, ".git", "no-global-excludes"))
        self.write(".claude/settings.local.json", self.leaky())
        _code, out, _err = run(["scan", self.root])
        self.assertIn("not ignored by git", out)
        self.assertEqual(run(["scan", self.root, "--staged"])[0], 0)
        self.git("add", "-A")
        code, out, _err = run(["scan", self.root, "--staged"])
        self.assertEqual(code, 1)
        self.assertIn("(staged)", out)
        self.git("commit", "-q", "-m", "one")
        self.write(".claude/settings.local.json", "{}")
        self.git("commit", "-q", "-am", "two")
        self.assertEqual(run(["scan", self.root])[0], 0)
        code, out, _err = run(["scan", self.root, "--history"])
        self.assertEqual(code, 1)
        self.assertIn("history", out)
        self.write(".gitignore", ".claude/settings.local.json\n")
        self.git("rm", "-q", "--cached", ".claude/settings.local.json")
        self.write(".claude/settings.local.json", self.leaky())
        _code, out, _err = run(["scan", self.root])
        self.assertIn("ignored by git", out)
        self.assertNotIn("not ignored by git", out)

    def test_packaging_note(self):
        self.write(".claude/settings.json", "{}")
        self.write("package.json", json.dumps({"name": "acme", "version": "1.0.0"}))
        _code, out, _err = run(["scan", self.root])
        self.assertIn("NOTE", out)
        self.write("package.json", json.dumps({"name": "acme", "version": "1.0.0", "files": ["dist"]}))
        _code, out, _err = run(["scan", self.root])
        self.assertNotIn("npm", out)

    def test_usage_errors(self):
        self.assertEqual(run(["scan", os.path.join(self.root, "missing")])[0], 2)
        self.assertEqual(run(["scan", "--nope"])[0], 2)
        self.assertEqual(run(["frobnicate"])[0], 2)
        self.assertEqual(run(["sinks"])[0], 0)


# Longer values, and ones with the characters a shell treats specially.
L = S + "a" + S2
LL = (S + S2) * 2
DOLLAR = "$".join(("Kd7", "wQ2", "mZ9x"))
HEXID = "4AEE18F8" + "3AFDEB23"


# Mixed case with no digit in it, and the same shaped as base64 of 16 and of
# 17 bytes: 22 or 23 characters, then the padding.
MIXED = "".join(("qWx", "RtB", "zKp", "NmJ", "dVf", "G"))
B64_16 = MIXED + MIXED[:6] + "=="
B64_17 = MIXED + MIXED[:7] + "="


def text_acted(name, text):
    return [h for h in A.scan_text(name, text) if h[2] in ACT]


class Quoting(unittest.TestCase):
    """A quoted value is still a value. What the quotes change is whether a
    `$` inside it is a reference, and that is the lexer's to say."""

    def test_ansi_c_and_locale_quotes(self):
        for cmd in ("PGPASSWORD=$'%s' psql -h db" % S, 'PGPASSWORD=$"%s" psql -h db' % S):
            self.assertTrue(acted(cmd), cmd.replace(S, "<v>"))

    def test_a_dollar_inside_single_quotes_is_part_of_the_value(self):
        doubled = "$$".join(("Rp4", "w0Tn9Abc"))
        for cmd in ("PGPASSWORD='%s' psql" % DOLLAR, "curl -u 'acme:%s' https://example.com" % doubled):
            self.assertTrue(acted(cmd))

    def test_a_dollar_outside_them_is_still_a_reference(self):
        for cmd in ('PGPASSWORD="$DB_PASS" psql', "PGPASSWORD=${DB_PASS} psql",
                    'curl -u "acme:$ACME_TOKEN" https://example.com'):
            self.assertEqual(acted(cmd), [], cmd)

    def test_punctuation_does_not_make_a_value_a_placeholder(self):
        angle = "<".join(("9k#Lm", "2pQr8!vXz"))
        slashed = "/" + "".join(("9j4kL8m", "N2pQ7rT5", "wX1zB3")) + "=="
        for cmd in ("PGPASSWORD='%s' psql" % angle, "API_SECRET='%s' ./app" % slashed,
                    "PGPASSWORD='my-prod-db-%s' psql" % S):
            self.assertTrue(acted(cmd))

    def test_the_sink_never_carries_the_lexer_s_own_marks(self):
        for sink, _sev, value in A.scan_command("PGPASSWORD='%s' psql" % DOLLAR):
            for mark in ("", ""):
                self.assertNotIn(mark, sink)
                self.assertNotIn(mark, value)


class Carriers(unittest.TestCase):
    """A command that runs another command is read for the one it runs."""

    def test_a_flag_at_the_end_of_a_short_cluster_takes_the_next_word(self):
        for cmd in ("curl -sSu acme:%s https://example.com" % S, "unzip -qP %s a.zip" % S):
            self.assertTrue(acted(cmd), cmd.replace(S, "<v>"))

    def test_a_command_passed_as_one_string(self):
        for cmd in ('env -S "PGPASSWORD=%s psql -h db"' % S, 'npx -c "PGPASSWORD=%s psql -h db"' % S):
            self.assertTrue(acted(cmd), cmd.replace(S, "<v>"))

    def test_a_command_carried_to_another_host_or_container(self):
        for cmd in ("ssh deploy@db.example.com mysql -u root -p%s app" % S,
                    "docker exec db mysql -u root -p%s app" % S,
                    "kubectl exec pod -- redis-cli -a %s ping" % S):
            self.assertTrue(acted(cmd), cmd.replace(S, "<v>"))

    def test_a_carrier_with_nothing_to_carry_is_clean(self):
        for cmd in ("ssh deploy@db.example.com uptime", "docker exec db ls /var/lib", "kubectl exec pod -- env"):
            self.assertEqual(acted(cmd), [], cmd)


class StdinConsumers(unittest.TestCase):
    """Echoing a literal into a program that reads its secret from stdin
    keeps it out of that program's arguments and puts it in echo's."""

    def test_each_is_caught(self):
        percent = "%".join(("Zq7", "vK2mXw9R"))
        for cmd in ("echo '%s' | docker login -u acme --password-stdin" % percent,
                    "echo %s | vault login -" % S,
                    "echo %s | openssl passwd -6 -stdin" % S,
                    "curl -K - https://example.com <<< 'user = \"acme:%s\"'" % S):
            self.assertTrue(acted(cmd))

    def test_htpasswd_takes_one_only_in_batch_mode(self):
        self.assertTrue(acted("htpasswd -nb acme %s" % S))
        self.assertTrue(acted("htpasswd -b /etc/htpasswd acme %s" % S))
        self.assertEqual(acted("htpasswd -c /etc/htpasswd acme"), [])

    def test_a_format_string_alone_is_not_one(self):
        self.assertEqual(acted("printf '%s\\n' \"$ACME_TOKEN\" | docker login -u acme --password-stdin"), [])


class NamesThatAreNotCredentials(unittest.TestCase):
    """A name that ends in token, key, pass or secret and holds something else."""

    def test_where_a_listing_stopped(self):
        for flag in ("--next-token", "--continuation-token", "--starting-token", "--sync-token",
                     "--resume-token", "--cancel-token"):
            self.assertEqual(acted("tool list %s %s" % (flag, L)), [], flag)
        self.assertEqual(acted("gcloud compute instances list --page-token=%s" % L), [])
        self.assertIsNone(A.key_class("nextToken"))

    def test_and_the_tokens_that_are(self):
        for flag in ("--token", "--access-token"):
            self.assertTrue(acted("tool %s %s" % (flag, L)), flag)
        self.assertEqual(A.key_class("SYNC_API_KEY"), "strong")

    def test_a_secret_named_rather_than_given(self):
        for cmd in ("gcloud secrets versions access latest --secret=acme-api-credential",
                    "gcloud run deploy svc --set-secrets=API_KEY=acme-api-credential:latest"):
            self.assertEqual(acted(cmd), [], cmd)

    def test_a_flag_is_not_the_value_of_the_flag_before_it(self):
        self.assertEqual(acted("mongosh -u admin -p --host db.example.com"), [])
        self.assertTrue(acted("mongosh -u admin -p %s --host db.example.com" % S))

    def test_keys_that_name_or_sort_something(self):
        self.assertEqual(acted("git -c user.signingKey=%s log" % HEXID), [])
        for cmd in ("rabbitmqadmin publish --routing-key=orders.created.v2x9k3 payload=hi",
                    "tool --shard-key tenant9a8b7c6d5e",
                    "aws s3 cp a s3://acme --sse-kms-key-id 1a2b3c4d-5e6f"):
            self.assertEqual(acted(cmd), [], cmd)
        for name in ("CACHE_KEY_PREFIX_V2", "PRIMARY_SORT_KEY", "S3_OBJECT_KEY", "PUBLIC_API_KEY", "SSH_HOST_KEY_PATH"):
            self.assertEqual(acted("%s=%s ./run" % (name, L)), [], name)

    def test_a_pass_that_is_a_stage(self):
        for cmd in ("opt --compiler-pass=inline-functions-v2 a.ll", "PASS_LIST=mem2reg,instcombine3 ./run"):
            self.assertEqual(acted(cmd), [], cmd)
        for cmd in ("DB_PASS=%s ./run" % S, "tool --pass %s" % S):
            self.assertTrue(acted(cmd))

    def test_a_cookie_that_is_a_preference(self):
        self.assertEqual(acted("curl -b 'theme=dark;locale=en-US' https://example.com"), [])
        self.assertTrue(acted("curl -b 'session=%s' https://example.com" % L))

    def test_a_sentence_used_as_a_key(self):
        doc = json.dumps({"answers": {"Which secret key should the build use": "The one in the store, not this"}})
        self.assertEqual(text_acted("session.jsonl", doc), [])
        self.assertIsNone(A.key_class("Where does the API token live"))
        self.assertEqual(A.key_class("Secret Access Key"), "strong")

    def test_a_short_question_is_still_a_clause(self):
        for name in ("What password works?", "Is token valid", "Use the API key",
                     "One two three four five API key"):
            self.assertIsNone(A.key_class(name), name)
        doc = json.dumps({"answers": {"Is token valid": "It was when this ran, yes"}})
        self.assertEqual(text_acted("session.jsonl", doc), [])

    def test_a_label_of_four_or_five_words(self):
        for name in ("AWS Secret Access Key", "GitHub Personal Access Token", "Supabase Service Role Key",
                     "Google Cloud API Key", "Azure Storage Account Key", "Stripe Webhook Signing Secret",
                     "Acme Production Database Root Password"):
            self.assertEqual(A.key_class(name), "strong", name)
            hits = text_acted(".mcp.json", json.dumps({"item": {name: L}}))
            self.assertTrue(hits, name)
            self.assertEqual(hits[0][2], A.HIGH, name)

    def test_a_slug_that_starts_like_a_vendor_token(self):
        for cmd in ("git checkout sk-refactor-the-payment-module-into-services",
                    "git checkout perm-allow-all-users-to-read-settings",
                    "psql -c 'select * from sbs_customer_accounts_summary_table'"):
            self.assertEqual(acted(cmd), [], cmd)


class NamesThatAre(unittest.TestCase):
    def test_qualified_keys(self):
        for name in ("SUPABASE_SERVICE_ROLE_KEY", "STRIPE_RESTRICTED_KEY", "ALGOLIA_ADMIN_KEY",
                     "DATADOG_APPLICATION_KEY", "LAUNCHDARKLY_SDK_KEY", "HMAC_SHA256_KEY", "JWT_SIGNING_KEY",
                     "AWS_BEDROCK_BEARER_TOKEN_US_EAST_1"):
            self.assertTrue(acted("%s=%s ./run" % (name, L)), name)

    def test_more_programs(self):
        for cmd in ("etcdctl --user root:%s get k" % S,
                    "influx query -t %s q" % L,
                    "cqlsh -u cassandra -p %s db.example.com" % S,
                    "dotnet nuget push a.nupkg -k %s" % L,
                    "nuget sources add -Name acme -Source https://example.com -u me -p %s" % S,
                    "composer config http-basic.repo.example.com me %s" % S,
                    "conan user -p %s me" % S):
            self.assertTrue(acted(cmd), cmd.split()[0])

    def test_more_vendor_tokens(self):
        hexd = "0123456789abcdef"
        for token in ("sb" + "p_" + (hexd * 3)[:40], "sb_" + "secret_" + LL[:30], "hv" + "s." + LL[:40],
                      "gs" + "k_" + LL[:52], "pp" + "lx-" + LL[:48], "r" + "8_" + LL[:37]):
            self.assertTrue(list(A.prefix_hits("x " + token + " y")), token[:4])


class MoreSurfaces(unittest.TestCase):
    def test_an_authorization_header_in_yaml(self):
        doc = "mcpServers:\n  acme:\n    headers:\n      Authorization: Bearer %s\n" % L
        self.assertTrue(text_acted(".goose/config.yaml", doc))
        prose = "notes: |\n  Authorization: Bearer tokens are read from the environment\n"
        self.assertEqual(text_acted(".goose/config.yaml", prose), [])

    def test_a_command_given_as_a_list(self):
        for server in ({"command": ["acme-mcp", "--api-key", L]},
                       {"cmd": "acme-mcp", "args": ["--api-key", L]}):
            self.assertTrue(text_acted(".mcp.json", json.dumps({"mcpServers": {"acme": server}})), sorted(server))
        self.assertEqual(text_acted(".mcp.json", json.dumps(
            {"mcpServers": {"acme": {"command": ["acme-mcp", "--api-key", "${ACME_API_KEY}"]}}})), [])

    def test_surfaces(self):
        for path in (".gemini/config/mcp_config.json", ".config/goose/config.yaml"):
            self.assertIn(path, A.USER_FILES)
        self.assertIn(".goose", A.AGENT_DIRS)

    def test_comment_stripping_leaves_strings_alone(self):
        doc = '{\n // c\n "a": "x,}y",\n "b": 1,\n}'
        self.assertEqual(json.loads(A._strip_jsonc(doc)), {"a": "x,}y", "b": 1})


class NothingLeaksFromNames(unittest.TestCase):
    """A credential in the place a name belongs is still not printed."""

    def test_a_name_that_is_itself_random_is_not_echoed(self):
        name, value = "Zk9" + "Lm2Qp8", "Vx4" + "Nr7Tb1"
        for cmd in ("fly secrets set %s=%s" % (name, value), "heroku config:set %s=%s" % (name, value)):
            hits = acted(cmd)
            self.assertTrue(hits)
            for sink, _sev, _value in hits:
                self.assertNotIn(name, sink)

    def test_a_value_left_where_the_name_goes(self):
        self.assertTrue(acted("kubectl create secret generic app --from-literal=%s=" % S))

    def test_mixed_case_without_digits_is_random_too(self):
        for value in (MIXED, MIXED + MIXED[:8], B64_16.rstrip("="), B64_17.rstrip("=")):
            self.assertTrue(A.looks_random(value))
        for name in ("maxOutputTokensPerRequest", "getIdOfUser", "OAUTH2_CLIENT_ID", "sha256sum",
                     "DATABASE_URL", "IPv4Address", "parseHTTPResponse", "kebab-case-name", "XMLHttpRequest"):
            self.assertFalse(A.looks_random(name), name)

    def test_a_mixed_case_value_in_name_position_is_not_echoed(self):
        for cmd in ("fly secrets set %s=%s" % (MIXED, MIXED[:6]), "heroku config:set %s=%s" % (MIXED, MIXED[:6])):
            hits = acted(cmd)
            self.assertTrue(hits)
            for sink, _sev, _value in hits:
                for frag in fragments(MIXED, 4):
                    self.assertNotIn(frag, sink)

    def test_base64_left_where_the_name_goes(self):
        for b64 in (B64_16, B64_17):
            self.assertTrue(b64.endswith("="))
            self.assertTrue(acted("kubectl create secret generic app --from-literal=%s" % b64))

    def test_mixed_case_after_a_slash_or_in_a_cookie(self):
        long = MIXED + MIXED[:8]
        self.assertTrue(acted("API_SECRET='/%s' ./app" % long))
        self.assertTrue(acted("curl -b 'sid=%s' https://example.com" % long))
        self.assertEqual(acted("API_SECRET=/etc/acme/AppData ./app"), [])
        self.assertEqual(acted("curl -b 'theme=DarkModeHighContrast' https://example.com"), [])

    def test_a_credential_used_as_a_json_key(self):
        root = tempfile.mkdtemp(prefix="asg-")
        self.addCleanup(shutil.rmtree, root, True)
        os.makedirs(os.path.join(root, ".claude"))
        secret = "Zk9" + "$" + "Lm2" + "!" + "Qp8"
        with open(os.path.join(root, ".claude", "settings.json"), "w", encoding="utf-8") as fh:
            json.dump({"https://acme:%s@db.example.com" % secret: {"enabled": True}}, fh)
        for extra in ([], ["--json"]):
            code, out, err = run(["scan", root] + extra)
            self.assertEqual(code, 1)
            for frag in fragments(secret, 3):
                self.assertNotIn(frag, out + err)


class Hardening(unittest.TestCase):
    @unittest.skipUnless(os.name == "posix" and shutil.which("sh"), "needs a POSIX shell")
    def test_the_wrapper_never_runs_a_python_from_the_project(self):
        """An empty PATH must not become one that searches the working
        directory, which is the project being guarded."""
        root = tempfile.mkdtemp(prefix="asg-")
        self.addCleanup(shutil.rmtree, root, True)
        marker = os.path.join(root, "ran")
        planted = os.path.join(root, "python3")
        with open(planted, "w", encoding="utf-8") as fh:
            fh.write("#!/bin/sh\n: > '%s'\nexit 0\n" % marker)
        os.chmod(planted, 0o755)
        wrapper = os.path.join(SCRIPTS, "guard-command.sh")
        event = json.dumps({"tool_name": "Bash", "tool_input": {"command": "npm test"}})
        for env in ({"PATH": ""}, {}):
            subprocess.run([shutil.which("sh"), wrapper], env=env, cwd=root, input=event,
                           capture_output=True, text=True, timeout=60)
            self.assertFalse(os.path.exists(marker), env)

    @unittest.skipUnless(hasattr(os, "mkfifo") and hasattr(os, "symlink"), "needs links and named pipes")
    def test_a_link_or_a_pipe_in_a_project_is_skipped_not_opened(self):
        root = tempfile.mkdtemp(prefix="asg-")
        self.addCleanup(shutil.rmtree, root, True)
        outside = tempfile.mkdtemp(prefix="asg-")
        self.addCleanup(shutil.rmtree, outside, True)
        target = os.path.join(outside, "settings.json")
        with open(target, "w", encoding="utf-8") as fh:
            json.dump({"permissions": {"allow": ["Bash(PGPASSWORD=%s psql -h db:*)" % S]}}, fh)
        os.makedirs(os.path.join(root, ".claude"))
        os.symlink(target, os.path.join(root, ".claude", "settings.json"))
        os.mkfifo(os.path.join(root, ".claude", "settings.local.json"))
        # A reader that opened the pipe would wait for a writer for ever.
        p = subprocess.run([sys.executable, SCRIPT, "scan", root, "--json"], capture_output=True, text=True, timeout=60)
        report = json.loads(p.stdout)
        self.assertEqual((p.returncode, report["findings"]), (0, []))
        self.assertEqual(sorted(s["reason"] for s in report["skipped"]),
                         ["not a regular file", "symbolic link, not followed"])
        self.assertEqual(A.read_text(target)[1], None)


if __name__ == "__main__":
    unittest.main()
