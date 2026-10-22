#!/usr/bin/env python3
"""Isolated regression checks for personal installation and settings preservation."""
import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class PersonalInstallTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), PATH=f'{self.bin}:{os.environ["PATH"]}')
        self.env.pop('XDG_DATA_HOME', None)
        for key in ('CAELESTIA_DIR', 'CAELESTIA_BRANCH', 'CAELESTIA_REPO', 'BUNDLE_DIR'):
            self.env.pop(key, None)

    def executable(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('#!/bin/sh\n' + content)
        path.chmod(0o755)

    def bootstrap(self):
        script = self.home / 'bootstrap/install.sh'
        script.parent.mkdir(exist_ok=True)
        shutil.copy2(ROOT / 'install.sh', script)
        master, slave = pty.openpty()
        try:
            return subprocess.run(['sh', str(script)], stdin=slave, capture_output=True,
                                  text=True, env=self.env, timeout=10)
        finally:
            os.close(master)
            os.close(slave)

    def test_bootstrap_clones_fork_and_runs_its_setup(self):
        self.executable(self.bin / 'git', '''
[ "$1" = clone ] || exit 1
printf '%s\\n' "$@" > "$HOME/clone-args"
for destination do :; done
mkdir -p "$destination/scripts"
printf 'echo FORK_SETUP_STARTED\\n' > "$destination/scripts/setup.sh"
''')
        result = self.bootstrap()
        self.assertEqual(result.returncode, 0, result.stderr)
        args = (self.home / 'clone-args').read_text().splitlines()
        self.assertIn('https://github.com/FaaizAlii/caelestia-kde.git', args)
        self.assertEqual(args[args.index('-b') + 1], 'main')
        self.assertEqual(args[-1], str(self.home / 'caelestia-kde-faaiz'))
        self.assertIn('FORK_SETUP_STARTED', result.stdout)

    def test_existing_upstream_checkout_is_not_updated(self):
        (self.home / 'caelestia-kde-faaiz/.git').mkdir(parents=True)
        self.executable(self.bin / 'git', '''
case "$*" in
  *'remote get-url origin') echo https://github.com/ladybug-me/caelestia-kde.git ;;
  *pull*) touch "$HOME/unsafe-pull"; exit 1 ;;
  *) exit 1 ;;
esac
''')
        result = self.bootstrap()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('does not match', result.stderr)
        self.assertFalse((self.home / 'unsafe-pull').exists())

    def test_defaults_enable_features_and_preserve_later_preferences(self):
        repo = self.home / 'repo'
        scripts = repo / 'scripts'
        scripts.mkdir(parents=True)
        shutil.copy2(ROOT / 'scripts/fork-defaults.sh', scripts)
        self.executable(scripts / 'install-urdu-font.sh', 'printf "%s\\n" "$HOME/font.ttf"\n')
        src = ROOT / 'src/kwin/scripts/three-finger-overview-sensitive'
        shutil.copytree(src, repo / 'src/kwin/scripts/three-finger-overview-sensitive')
        self.executable(self.bin / 'kwriteconfig6', 'printf "%s\\n" "$*" >> "$HOME/kwin-settings"\n')
        self.executable(self.bin / 'qdbus6', 'exit 0\n')
        config = self.home / '.config/caelestia/shell.json'
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps({'other': {'keep': 42}}))
        for first in (True, False):
            result = subprocess.run(['bash', str(scripts / 'fork-defaults.sh')], env=self.env,
                                    capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            data = json.loads(config.read_text())
            self.assertEqual(data['other']['keep'], 42)
            self.assertEqual(data['services']['romanizeIndicLyrics'], first)
            self.assertEqual(data['services']['urduFontFile'], (self.home / 'font.ttf').as_uri())
            data['services']['romanizeIndicLyrics'] = False
            config.write_text(json.dumps(data))
        installed = self.home / '.local/share/kwin/scripts/three-finger-overview-sensitive'
        self.assertEqual((installed / 'contents/ui/main.qml').read_bytes(), (src / 'contents/ui/main.qml').read_bytes())
        self.assertIn('three-finger-overview-sensitiveEnabled true', (self.home / 'kwin-settings').read_text())

if __name__ == '__main__':
    unittest.main()
