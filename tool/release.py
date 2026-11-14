"""Build artifacts and publish a complete version after every platform succeeds."""

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/release'


def version():
    match = re.search(r'^version: (\d+\.\d+\.\d+)\+([1-9]\d*)$',
                      (ROOT / 'pubspec.yaml').read_text(), re.M)
    if not match:
        raise ValueError('Use version: major.minor.patch+positiveBuildNumber')
    return match[1], int(match[2])


def verify():
    name, _ = version()
    if not (ROOT / f'docs/releases/v{name}.md').is_file():
        raise ValueError('Add release notes matching pubspec.yaml')
    paths = subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines()
    forbidden = re.compile(r'(^|/)(\.private|\.env[^/]*|key\.properties|local\.properties)(/|$)|\.(jks|keystore|db|enc)$')
    for path in paths:
        if forbidden.search(path):
            raise ValueError(f'Private file tracked: {path}')
        data = (ROOT / path).read_bytes()
        if re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}', data):
            raise ValueError(f'Credential pattern in: {path}')
    print(f'Verified source and release notes for v{name}.')


def signing():
    folder = ROOT / '.private'
    folder.mkdir(mode=0o700, exist_ok=True)
    key = folder / 'release.jks'
    key.write_bytes(base64.b64decode(os.environ['ANDROID_KEYSTORE_BASE64'], validate=True))
    key.chmod(0o600)
    password = os.environ['ANDROID_KEYSTORE_PASSWORD']
    if not re.fullmatch(r'[A-Za-z0-9_-]{32,}', password):
        raise ValueError('Signing password must use at least 32 safe characters')
    config = ROOT / 'android/key.properties'
    config.write_text(f'storeFile={key.as_posix()}\nstorePassword={password}\nkeyAlias=assetkeeper\nkeyPassword={password}\n')
    config.chmod(0o600)


def package(platform):
    name, _ = version()
    prefix = f'AssetKeeper-v{name}'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if platform == 'android':
        apk = ROOT / 'build/app/outputs/flutter-apk/app-release.apk'
        sdk = Path(os.environ.get('ANDROID_HOME') or os.environ['ANDROID_SDK_ROOT'])
        tools = sorted((sdk / 'build-tools').glob('*'))[-1]
        certificate = subprocess.check_output([str(tools / 'apksigner'), 'verify', '--print-certs', str(apk)], text=True)
        fingerprint = (ROOT / 'android/release-certificate.sha256').read_text().strip()
        if f'Signer #1 certificate SHA-256 digest: {fingerprint}' not in certificate or 'CN=Android Debug' in certificate:
            raise ValueError('APK must use the pinned production signing certificate')
        info = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(apk)], text=True)
        _, code = version()
        if not re.search(rf"package: name='com\.zeerooo\.assetkeeper' versionCode='{code}' versionName='{re.escape(name)}'", info):
            raise ValueError('APK package identity or version does not match this release')
        with zipfile.ZipFile(apk) as archive:
            for abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64']:
                if f'lib/{abi}/libsqlcipher.so' not in archive.namelist():
                    raise ValueError(f'Missing encrypted SQLite library for {abi}')
        shutil.copy2(apk, OUTPUT / f'{prefix}-android.apk')
    elif platform == 'linux':
        bundle = ROOT / 'build/linux/x64/release/bundle'
        if not (bundle / 'assetkeeper').is_file() or not (bundle / 'lib/libsqlcipher.so').is_file():
            raise ValueError('Linux executable or SQLCipher library missing')
        with tarfile.open(OUTPUT / f'{prefix}-linux-x64.tar.gz', 'w:gz') as archive:
            archive.add(bundle, arcname='AssetKeeper')
            archive.add(ROOT / 'docs/INSTALL.md', arcname='AssetKeeper/INSTALL.md')
    elif platform == 'windows':
        bundle = ROOT / 'build/windows/x64/runner/Release'
        if not (bundle / 'assetkeeper.exe').is_file() or not (bundle / 'sqlcipher.dll').is_file():
            raise ValueError('Windows executable or SQLCipher library missing')
        for name in ['msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll']:
            shutil.copy2(Path(os.environ['WINDIR']) / 'System32' / name, bundle / name)
        with zipfile.ZipFile(OUTPUT / f'{prefix}-windows-x64.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in bundle.rglob('*'):
                if path.is_file():
                    archive.write(path, 'AssetKeeper/' + path.relative_to(bundle).as_posix())
            archive.write(ROOT / 'docs/INSTALL.md', 'AssetKeeper/INSTALL.md')
    else:
        raise ValueError('Unknown platform')
    print(f'Packaged {platform}.')


def gh(*args, **kwargs):
    return subprocess.run(['gh', *args], cwd=ROOT, check=True, text=True, **kwargs)


def publish():
    name, code = version()
    tag = f'v{name}'
    existing = subprocess.run(['gh', 'release', 'view', tag, '--json', 'isDraft'],
                              cwd=ROOT, text=True, capture_output=True)
    if existing.returncode == 0 and not json.loads(existing.stdout)['isDraft']:
        print(f'{tag} is already published; bump pubspec.yaml for a new update.')
        return
    latest = subprocess.run(['gh', 'release', 'view', '--json', 'tagName'],
                            cwd=ROOT, text=True, capture_output=True)
    if latest.returncode == 0:
        old = json.loads(latest.stdout)['tagName'].removeprefix('v')
        if tuple(map(int, name.split('.'))) <= tuple(map(int, old.split('.'))):
            raise ValueError('New releases must have a higher version')
        previous = subprocess.check_output(
            ['gh', 'release', 'download', f'v{old}', '--pattern', 'release-info.json', '--output', '-'],
            cwd=ROOT, text=True)
        if code <= json.loads(previous)['build_number']:
            raise ValueError('New releases must also increase the Android build number')
    files = [OUTPUT / f'AssetKeeper-{tag}-{suffix}' for suffix in
             ['android.apk', 'linux-x64.tar.gz', 'windows-x64.zip']]
    if not all(p.is_file() and p.stat().st_size for p in files):
        raise ValueError('All three platform builds are required before publishing')
    source = OUTPUT / f'AssetKeeper-{tag}-source.zip'
    subprocess.run(['git', 'archive', '--format=zip', '--prefix=AssetKeeper/',
                    f'--output={source}', 'HEAD'], cwd=ROOT, check=True)
    files.append(source)
    manifest = OUTPUT / 'release-info.json'
    manifest.write_text(json.dumps({'version': name, 'build_number': code, 'android_package': 'com.zeerooo.assetkeeper'}) + '\n')
    files.append(manifest)
    sums = OUTPUT / 'SHA256SUMS'
    checksums = []
    for path in files:
        with path.open('rb') as stream:
            checksums.append(f'{hashlib.file_digest(stream, "sha256").hexdigest()}  {path.name}\n')
    sums.write_text(''.join(checksums))
    if existing.returncode != 0:
        sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        gh('release', 'create', tag, '--draft', '--target', sha, '--title', f'AssetKeeper {tag}',
           '--notes-file', str(ROOT / f'docs/releases/{tag}.md'))
    gh('release', 'upload', tag, *map(str, [*files, sums]), '--clobber')
    gh('release', 'edit', tag, '--draft=false', '--latest')
    print(f'Published complete release {tag}.')


if __name__ == '__main__':
    command = sys.argv[1]
    if command == 'package':
        package(sys.argv[2])
    else:
        {'verify': verify, 'signing': signing, 'publish': publish}[command]()
