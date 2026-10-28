import importlib.util
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import tomllib
import unittest

sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('config_merge', Path(__file__).resolve().parents[1] / 'three-tier-collaboration/scripts/config-merge.py')
merge = importlib.util.module_from_spec(spec)
spec.loader.exec_module(merge)


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))
        self.folder = Path(tempfile.mkdtemp(prefix='three-tier-config-test-'))
        self.path = self.folder / 'config.toml'
        self.backups = self.folder / 'backups'

    def install(self):
        edit = merge.plan('install', self.path)
        merge.apply(edit, self.backups)
        return edit

    def test_packaged_settings_match(self):
        target = Path(__file__).resolve().parents[1] / 'three-tier-collaboration/references/fallback-config.toml'
        data = tomllib.loads(target.read_text(encoding='utf-8-sig'))
        flattened = {key: merge.get(data, key) for key in merge.SETTINGS}
        self.assertEqual(flattened, merge.SETTINGS)

    def test_defaults_and_uninstall(self):
        self.install()
        self.assertEqual(tomllib.loads(self.path.read_text()), {
            'model': 'gpt-6.1-sol', 'model_reasoning_effort': 'medium',
            'agents': {'enabled': True, 'max_concurrent_threads_per_session': 3,
                       'default_subagent_model': 'gpt-6-luna', 'default_subagent_reasoning_effort': 'medium'}})
        merge.apply(merge.plan('uninstall', self.path), self.backups)
        self.assertEqual(tomllib.loads(self.path.read_text()), {'agents': {}})

    def test_preserve_other_values_and_comments(self):
        before = (b'\xef\xbb\xbf# personal preferences\r\nmodel = "old" # keep this\r\n'
                  b'approval_policy = "on-request"\r\n[agents]\r\nenabled = false\r\n'
                  b'[agents.reviewer]\r\nconfig_file = "reviewer.toml"\r\n'
                  b'[mcp_servers.example]\r\nurl = "https://example.invalid"\r\n')
        self.path.write_bytes(before)
        self.install()
        raw = self.path.read_bytes()
        self.assertTrue(raw.startswith(b'\xef\xbb\xbf# personal preferences\r\n'))
        self.assertIn(b'# keep this\r\n', raw)
        data = merge.parsed(raw)
        self.assertEqual(data['approval_policy'], 'on-request')
        self.assertEqual(data['agents']['reviewer'], {'config_file': 'reviewer.toml'})
        self.assertEqual(data['mcp_servers']['example']['url'], 'https://example.invalid')
        merge.apply(merge.plan('uninstall', self.path), self.backups)
        self.assertEqual(merge.parsed(self.path.read_bytes()), merge.parsed(before))
        self.assertTrue(any(p.read_bytes() == before for p in self.backups.iterdir()))

    def test_reinstall_keeps_original_baseline(self):
        self.path.write_text('model = "original"\n', encoding='utf-8')
        self.install()
        once = self.path.read_bytes()
        self.install()
        self.assertEqual(self.path.read_bytes(), once)
        merge.apply(merge.plan('uninstall', self.path), self.backups)
        self.assertEqual(merge.parsed(self.path.read_bytes())['model'], 'original')

    def test_preserve_later_user_edit(self):
        self.path.write_text('model = "original"\n', encoding='utf-8')
        self.install()
        self.path.write_bytes(self.path.read_bytes().replace(b'"gpt-6.1-sol"', b'"user-choice"') + b'\n[other]\ncustom = true\n')
        edit = merge.plan('uninstall', self.path)
        self.assertIn('Preserved a later user change: model', edit['warnings'])
        merge.apply(edit, self.backups)
        data = merge.parsed(self.path.read_bytes())
        self.assertEqual(data['model'], 'user-choice')
        self.assertTrue(data['other']['custom'])

    def test_rollback(self):
        original = b'model = "before"\n'
        self.path.write_bytes(original)
        edit = self.install()
        merge.apply(edit, self.backups, reverse=True)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertFalse(Path(str(self.path) + '.three-tier-collaboration.json').exists())

    def test_concurrent_edit(self):
        edit = merge.plan('install', self.path)
        self.path.write_text('# a concurrent change\n', encoding='utf-8')
        with self.assertRaises(ValueError):
            merge.apply(edit, self.backups)
        self.assertEqual(self.path.read_text(), '# a concurrent change\n')

    def test_no_receipt_no_ownership(self):
        self.path.write_text('model = "personal-choice"\n', encoding='utf-8')
        before = self.path.read_bytes()
        merge.apply(merge.plan('uninstall', self.path), self.backups)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertFalse(self.backups.exists())

    def test_unsupported_and_invalid_layouts_leave_bytes_intact(self):
        for raw in (b'agents = {enabled = false}\n', b'model = ["unexpected"]\n',
                    b'[agents]\nmax_threads = 8\n', b'model = "bad\n'):
            self.path.write_bytes(raw)
            with self.assertRaises((ValueError, tomllib.TOMLDecodeError)):
                merge.plan('install', self.path)
            self.assertEqual(self.path.read_bytes(), raw)

    def test_root_without_final_newline(self):
        self.path.write_bytes(b'model = "original"')
        self.install()
        self.assertEqual(merge.parsed(self.path.read_bytes())['model_reasoning_effort'], 'medium')


if __name__ == '__main__':
    unittest.main()
