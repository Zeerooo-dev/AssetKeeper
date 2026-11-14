import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import release


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        (root / 'pubspec.yaml').write_text('version: 1.0.4+5\n')
        self.root_patch = patch.object(release, 'ROOT', root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.out_patch = patch.object(release, 'OUTPUT', root / 'build/release')
        self.out_patch.start()
        self.addCleanup(self.out_patch.stop)

    def test_published_release_is_never_overwritten(self):
        response = subprocess.CompletedProcess([], 0, json.dumps({'isDraft': False}), '')
        with patch.object(release.subprocess, 'run', return_value=response), patch.object(release, 'gh') as gh:
            release.publish()
            gh.assert_not_called()

    def test_missing_platform_blocks_publication(self):
        release.OUTPUT.mkdir(parents=True)
        for suffix in ['android.apk', 'linux-x64.tar.gz']:
            (release.OUTPUT / f'AssetKeeper-v1.0.4-{suffix}').write_bytes(b'artifact')
        missing = subprocess.CompletedProcess([], 1, '', 'not found')
        with patch.object(release.subprocess, 'run', return_value=missing), patch.object(release, 'gh') as gh:
            with self.assertRaisesRegex(ValueError, 'All three'):
                release.publish()
            gh.assert_not_called()

    def test_version_must_increase(self):
        missing = subprocess.CompletedProcess([], 1, '', 'not found')
        latest = subprocess.CompletedProcess([], 0, json.dumps({'tagName': 'v1.0.5'}), '')
        with patch.object(release.subprocess, 'run', side_effect=[missing, latest]), patch.object(release, 'gh') as gh:
            with self.assertRaisesRegex(ValueError, 'higher version'):
                release.publish()
            gh.assert_not_called()

    def test_android_build_number_must_increase(self):
        missing = subprocess.CompletedProcess([], 1, '', 'not found')
        latest = subprocess.CompletedProcess([], 0, json.dumps({'tagName': 'v1.0.3'}), '')
        with patch.object(release.subprocess, 'run', side_effect=[missing, latest]), patch.object(
                release.subprocess, 'check_output', return_value=json.dumps({'build_number': 5})), patch.object(release, 'gh') as gh:
            with self.assertRaisesRegex(ValueError, 'Android build number'):
                release.publish()
            gh.assert_not_called()


if __name__ == '__main__':
    unittest.main()
