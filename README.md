# AssetKeeper

Current build: 1.0.4+5, GitHub update notifications and three-platform releases.

Version 1.0.1+2 adds automatic native SQLCipher encryption.

Equipment and furniture inventory and accountability management for PC and
smartphones. Built with Flutter and SQLite, adapted from the approved Smart Stock
prototype, now restyled from Smart Stock's `ui/stitch-mobile-redesign` branch,
with JANITRA-style floating glass navigation. Both reference projects are unchanged.

## Run

Tested with Flutter 3.47.5 and Dart 3.13.4. Install Flutter and platform tooling
for your target. From this folder:

```sh
flutter pub get
flutter run -d linux
```

On Windows use `flutter run -d windows`; on macOS use `flutter run -d macos`.
Connect an Android phone with USB debugging, run `flutter devices`, then
`flutter run -d DEVICE_ID`. iOS requires macOS, Xcode and signing setup.
Android production uses `com.zeerooo.assetkeeper` and private release signing.
It installs separately from the older test APK, preserving that old installation.
See [installation](docs/INSTALL.md) before moving any existing inventory.

Linux needs GTK development tools, a Secret Service keyring, and libsecret/jsoncpp
development libraries for secure storage. `flutter doctor -v` checks host tooling.
Keep the OS keyring available to reopen an encrypted database.

## First use

1. Set your operator name, which is recorded on future changes.
2. Open Employees and add personnel with unique employee codes. On a phone,
   Employees, Branches, Categories, Audit Log and Settings are in More.
3. Valencia Branch, Equipment and Furniture are ready. Add custom branches and
   categories as needed.
4. Add one asset per physical item. Property numbers are unique, including archived
   records. Furniture can have an empty serial number. Prices use exact centavos.
5. Open an asset to edit it or transfer accountability. Employee transfers preserve
   condition. Unit transfers require a destination and set the transferred status.
6. Filter by employee, category, status or branch; search property/serial/name.
   Archived assets have a separate filter and can be restored.

## Data and safety

- Records persist locally. PC and phone installations **do not synchronize**.
  There is no server login or role system in the reference architecture. An operator
  name is an audit label, not authenticated identity; use OS/device access controls.
- Assets are archived rather than permanently deleted. Transfer and audit histories
  are append-only. Editing the employee automatically creates a history entry.
- Branch/category renames preserve assignments. Referenced records cannot be
  removed; edit asset assignments before removing an unused branch/category.
  Employees referenced in history must be retained.
- Native databases use a separate AssetKeeper directory under application support.
  The exact path is in Settings. Smart Stock databases and keys are never opened.
- Native database pages are encrypted automatically with SQLCipher while the app
  is open, saving, backgrounded or closed. There is no manual-close requirement.
  The random key is held in device secure storage; no key is embedded in source.
- The first updated launch migrates the old plaintext or AES-GCM envelope format.
  Migration verifies integrity, table row counts, schema version and encrypted
  output before promotion. Do not run the old and updated app simultaneously.
  Interrupted migrations retain their source and resume or fail closed.
- A native database lock prevents concurrent processes from encrypting the same
  store. Optimistic versions prevent stale edits from overwriting newer records.
- Preserve the encrypted database **and its original device key**. Copying a database
  file to another device alone is not a portable backup. No Smart Stock import or
  cross-device backup/restore flow is included.
- The app starts without sample assets or people. Tests and screenshots use
  temporary databases separate from your real inventory.

## Browser

The browser build uses the same SQLite service through a web worker and IndexedDB.
Records stay in that browser profile/origin and are not encrypted by the native
key store. Clearing site data removes them. Bundled `web/sqlite3.wasm` and
`web/sqflite_sw.js` are required; regenerate after upgrading SQLite packages:

```sh
dart run sqflite_common_ffi_web:setup --force
flutter run -d chrome --web-port 8787
```

Keep the port/origin stable to return to saved browser data. For a static build:

```sh
flutter build web --release --no-web-resources-cdn
python3 -m http.server 8787 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8787`. On another device use a properly configured HTTPS
host, not `file://`. No hosted deployment is included.

## Builds

```sh
flutter build linux --release
flutter build apk --release    # requires private android/key.properties
flutter build windows --release  # on Windows
flutter build macos --release    # on macOS
flutter build ios --no-codesign  # on macOS; signing still needed to install
```

Linux output: `build/linux/x64/release/bundle/assetkeeper`. Keep the entire bundle
together. Android test APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Production Android releases require the private signing key and are checked
against the public certificate fingerprint in android/release-certificate.sha256.
Windows packages include the C++ runtime DLLs and are not code-signed.

## GitHub updates and releases

Official source and downloads: https://github.com/Zeerooo-dev/AssetKeeper.
The app checks the public GitHub latest-release API after setup and on resume
after four hours. It sends no inventory, operator name or database key. A newer
stable version with the exact platform download triggers a dismissible popup.
Settings > Check for updates bypasses the four-hour interval. Offline errors do
not block inventory work. Downloads open in the browser; installation is manual.

Push to `main` to run analysis, tests and Android/Linux/Windows release builds.
Increment both the version and build number in pubspec.yaml and add matching
`docs/releases/vVERSION.md` notes to publish a new update automatically. A release
becomes visible only after all builds succeed. Pushing the same version builds
review artifacts without replacing an existing published release. A raw Git tag
alone does not notify the app.

The workflow needs repository secrets `ANDROID_KEYSTORE_BASE64` and
`ANDROID_KEYSTORE_PASSWORD` (the same production key on every build). Signing
files are ignored and never uploaded as source or build artifacts. Keep a secure
offline backup: losing the key prevents future in-place Android updates.
Installation details and platform requirements: [docs/INSTALL.md](docs/INSTALL.md).

## Verification

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter test integration_test/app_test.dart -d linux
```

The native integration test uses a temporary database, verifies real device key
storage and encrypted reopen, captures PC/phone layouts in `build/verification/`,
and removes its test database and key. It does not modify your real inventory.

See [architecture](docs/architecture.md) and [verification](docs/verification.md).

## Automatic encryption security update

See [security verification](docs/security/automatic-encryption.md). This update
changes the native SQLite engine to SQLCipher through sqlite3 build hooks, including
Android/iOS/macOS as well as PC. Builds must retain `source: sqlcipher` in pubspec.
The app checks engine availability and refuses an unencrypted native fallback.
The browser build remains unencrypted and is not covered by this native guarantee.

Use a properly signed, non-debug build for production. Encryption does not replace
device access controls or protect against a compromised OS or a running process
with access to the device keyring. Flash storage may retain remnants of data
written by older plaintext versions; OS full-disk encryption remains advisable.

## Android icon and opening-animation kit

The supplied AssetKeeper kit is integrated into the launcher and startup flow.
Android 8+ uses separate adaptive foreground/background layers, Android 13+ adds
its monochrome themed-icon layer, and older launchers receive density-specific
regular and round icons. Android 12+ uses the supplied 900 ms animated vector;
older devices show the static vector. The system controls splash dismissal.

On Android, the native animation hands off to a clean, ring-free mark on the
same background while initialization finishes. The GIF is not replayed after the
system splash. Other platforms retain the bounded GIF intro and reduced-motion
still. Initialization completing dismisses the loading screen immediately.
The MP4 remains reference material and requires no video-player dependency.
Kit vector masters and the original reference README are in docs/branding-kit;
implementation details and verification are in docs/branding-kit/integration.md.
