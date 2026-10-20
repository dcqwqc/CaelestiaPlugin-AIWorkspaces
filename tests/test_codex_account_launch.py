"""Named Codex launchers: deterministic accounts without touching real auth."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/codex-account-launch'


class NamedCodexAccountTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / '.local/bin'
        self.mockbin = self.home / 'mockbin'
        self.bin.mkdir(parents=True)
        self.mockbin.mkdir(parents=True)
        registry = self.home / '.codex/accounts/registry.json'
        registry.parent.mkdir(parents=True)
        registry.write_text(json.dumps({'accounts': [
            {'alias': 'levi', 'email': 'levi@example.test'},
            {'alias': 'lina', 'email': 'lina@example.test'},
        ]}))
        for name in ('codexlina', 'codexlevi'):
            (self.bin / name).symlink_to(SCRIPT)
        for name, body in {
            'codex-auth': '#!/bin/sh\nprintf "auth %s\n" "$*" >> "$TRACE"\n',
            'codex': '#!/bin/sh\nprintf "daemon %s\n" "$*" >> "$TRACE"\n',
        }.items():
            f = self.mockbin / name
            f.write_text(body)
            f.chmod(0o755)
        f = self.bin / 'ai-workspace'
        f.write_text('#!/bin/sh\nprintf "workspace %s\n" "$*" >> "$TRACE"\n')
        f.chmod(0o755)
        self.trace = self.home / 'trace'
        self.env = {**os.environ, 'HOME': str(self.home),
                    'PATH': str(self.mockbin) + ':' + os.environ['PATH'],
                    'TRACE': str(self.trace),
                    'CODEX_ACCOUNT_CLI': str(self.mockbin / 'codex')}
        self.env.pop('AI_SESSION_ID', None)

    def run_named(self, name, *args):
        return subprocess.run([str(self.bin / name), *args], env=self.env,
                              capture_output=True, text=True, timeout=8)

    def test_launch_does_not_require_or_restart_daemon(self):
        proc = self.run_named('codexlevi', '--yolo')
        self.assertEqual(proc.returncode, 0, proc.stderr)
        trace = self.trace.read_text()
        self.assertIn('auth switch levi', trace)
        self.assertNotIn('daemon', trace)
        self.assertIn('--yolo', trace)

    def test_check_does_not_switch_accounts_or_start_services(self):
        for name, alias in (('codexlina', 'lina'), ('codexlevi', 'levi')):
            proc = self.run_named(name, '--check')
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertIn(alias, proc.stdout)
        self.assertFalse(self.trace.exists())

    def test_bash_dispatches_exact_account_and_workspace(self):
        for name, alias in (('codexlina', 'lina'), ('codexlevi', 'levi')):
            proc = self.run_named(name, '--model', 'test-model')
            self.assertEqual(proc.returncode, 0, proc.stderr)
            trace = self.trace.read_text()
            self.assertIn(f'auth switch {alias}', trace)
            self.assertNotIn('daemon app-server daemon restart', trace)
            self.assertIn(f'workspace run --provider codex -- {self.mockbin / "codex"} --model test-model', trace)
            self.trace.unlink()

    def test_missing_or_duplicated_account_refuses_check(self):
        registry = self.home / '.codex/accounts/registry.json'
        registry.write_text(json.dumps({'accounts': [{'alias': 'levi'}]}))
        self.assertNotEqual(self.run_named('codexlina', '--check').returncode, 0)
        registry.write_text(json.dumps({'accounts': [{'alias': 'levi'}, {'alias': 'levi'}]}))
        self.assertNotEqual(self.run_named('codexlevi', '--check').returncode, 0)
        self.assertFalse(self.trace.exists())

    def test_fish_generator_routes_to_same_standalone_scripts(self):
        text=(SCRIPT.parent/'ai-workspace').read_text()
        self.assertIn('codex-account-launch', text)
        self.assertIn('for name in ("codexlevi", "codexlina")', text)
        self.assertIn('command \"$HOME/.local/bin/{name}\" $argv', text)


if __name__ == '__main__':
    unittest.main()
