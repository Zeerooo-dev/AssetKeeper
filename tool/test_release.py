import json
import base64
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile
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

    def test_android_package_requires_sqlcipher_on_every_architecture(self):
        root = release.ROOT
        tools = root / 'sdk/build-tools/36.0.0'
        tools.mkdir(parents=True)
        (root / 'android').mkdir()
        (root / 'android/release-certificate.sha256').write_text('a' * 64)
        apk = root / 'build/app/outputs/flutter-apk/app-release.apk'
        apk.parent.mkdir(parents=True)
        certificate = 'Signer certificate SHA-256 digest: ' + 'A' * 64
        info = "package: name='com.zeerooo.assetkeeper' versionCode='5' versionName='1.0.4'"
        for library in ['libsqlite3.so', 'libsqlcipher.so']:
            with zipfile.ZipFile(apk, 'w') as archive:
                for abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']:
                    archive.writestr(f'lib/{abi}/{library}', b'native library')
            with patch.dict(release.os.environ, {'ANDROID_HOME': str(root / 'sdk')}), patch.object(
                    release.subprocess, 'check_output', side_effect=[certificate, info]):
                if library == 'libsqlite3.so':
                    with self.assertRaisesRegex(ValueError, 'encrypted SQLite'):
                        release.package('android')
                else:
                    release.package('android')
                    self.assertEqual((release.OUTPUT / 'AssetKeeper-v1.0.4-android.apk').read_bytes(), apk.read_bytes())
            if library == 'libsqlcipher.so':
                with patch.dict(release.os.environ, {'ANDROID_HOME': str(root / 'sdk')}), patch.object(
                        release.subprocess, 'check_output', return_value='Signer certificate SHA-256 digest: ' + 'b' * 64):
                    with self.assertRaisesRegex(ValueError, 'APK certificate mismatch'):
                        release.package('android')

    def test_restored_key_must_match_pinned_certificate(self):
        certificate = b'public DER certificate'
        folder = release.ROOT / 'android'
        folder.mkdir()
        pin = folder / 'release-certificate.sha256'
        pin.write_text(hashlib.sha256(certificate).hexdigest())
        with patch.dict(release.os.environ, {
                'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'private test keystore').decode(),
                'ANDROID_KEYSTORE_PASSWORD': 'x' * 32,
        }), patch.object(release.subprocess, 'check_output', return_value=certificate):
            release.signing()
            self.assertTrue((folder / 'key.properties').is_file())
            pin.write_text('b' * 64)
            with self.assertRaisesRegex(ValueError, 'Private signing key'):
                release.signing()


if __name__ == '__main__':
    unittest.main()
