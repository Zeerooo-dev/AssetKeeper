# Verification

Updated on November 15, 2026 with Flutter 3.47.5, Dart 3.13.4, Linux x64.

## Results

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | Passed with no issues |
| `flutter test --no-pub` | All 60 tests passed |
| `flutter test integration_test/app_test.dart -d linux` | Passed on the native Linux runner |
| Linux release bundle | Built successfully |
| Android debug APK | Built successfully; debug signed |
| Browser release, with bundled rendering assets | Built successfully |
| Isolated Chromium startup and SQLite worker | Passed |
| Browser operator settings after page reload | Persisted correctly |
| Smartphone browser navigation at 390 × 844 | Rendered correctly; no JavaScript exceptions |

## Covered workflows

- SQLite migration and foreign key enforcement; initial reference data only.
- Equipment with serial number; furniture without one; exact peso parsing.
- Duplicate property numbers, including mixed-case and archived duplicates.
- Asset editing, status persistence and database-boundary validation.
- Employee transfer preserves condition, previous employee, date, remarks and actor.
- Editing accountability also records a transfer, with immutable employee-name
  snapshots that survive later employee renaming.
- Transaction rollback: simulated audit-write failure leaves both asset assignment
  and transfer history unchanged.
- Unit transfer requires a destination, stores the previous unit, and preserves
  accountable employee. Transferred status through the editor also records history.
- Optimistic concurrency rejects stale edits and transfers.
- Invalid dates, future dates, dates before acquisition and out-of-order transfer
  dates are rejected. Editing acquisition date cannot invalidate past transfers.
- Custom branches/categories, safe branch rename, and referenced-deletion protection.
- Combined filters and literal wildcard search; live dashboard totals and archives.
- Transfer and audit rows reject update/delete through SQLite triggers.
- Close/reopen persistence; encrypted close/reopen; missing key and secure-storage
  failure preserve original data; native database lock rejects a second instance.
- Phone registration, duplicate validation, full-page asset details, employee transfer,
  employee creation and More navigation were exercised through Flutter controls.
- All eight sections were checked at 320 × 640, 390 × 844, 736 × 1024,
  1024 × 768, 1440 × 900 and 640 × 360 without layout exceptions.
- A 320 px form with 2× text and a keyboard inset retained a reachable Save button.
  Long transfer status fields were checked at 2× text in all four themes.
- Native integration checked real Linux device-key storage, first-run operator
  setup, asset/detail rendering, record persistence and encryption. It used a
  temporary database and removed its test database/key afterward.

## Screenshots

These are captures of the native Flutter application with explicit verification
records. They are not production inventory or the earlier HTML prototype.

- [PC layout](screenshots/assetkeeper-desktop.png)
- [Smartphone inventory](screenshots/assetkeeper-smartphone.png)
- [Smartphone asset details](screenshots/assetkeeper-smartphone-details.png)

## Boundaries

- No physical Android/iPhone testing was performed; no phone was connected.
- Windows, macOS and iOS targets are present but cannot be built or accepted on
  this Linux host. They require their platform toolchains and signing where needed.
- Android output is a debug-signed test build, not a published release.
- PC and phone installations have independent local databases. No cloud sync,
  shared-server authentication, portable backup/restore or Smart Stock data import.
- Inventory displays 20 records per page but currently loads matching records into
  device memory; SQL counting/paging is the next step for very large inventories.
- Native SQLCipher encryption remains active while open and after a forced process kill.
  Browser IndexedDB remains unencrypted. See the automatic-encryption security report.
- The original Smart Stock checkout was only read. No original source/database,
  cloud project, GitHub repository, app-store listing or production deployment changed.

## Smart Stock branch and JANITRA navigation refresh

The owner selected `ui/stitch-mobile-redesign` for the application styling and
JANITRA for navigation. The branch theme was fetched from GitHub and matched to
its local source. AssetKeeper now uses its navy/slate palette, compact type,
20 px cards, 14 px fields, pill buttons, initials tiles, status chips, grouped
forms and dashboard action cards. Asset counts, acquisition values and asset
conditions continue to use the existing database.

The mobile bar uses JANITRA's 26 px floating glass surface with 16 px side insets,
always-visible labels and neutral selected states. Blur falls back to solid
surfaces in high-contrast mode or when contrast would be insufficient. Large
text keeps the two-column wrapping navigation. The PC sidebar and phone top
bar follow the page background. Eight new navigation checks cover all four
themes with and without high contrast, including insets, radius and tab actions.

This refresh changes presentation only; storage, operator names, asset records
and transfer history are unchanged. Existing running release windows must be
closed normally and reopened to load the updated build.

Additional captures:
- [Phone dashboard](screenshots/assetkeeper-smartphone-dashboard.png)
- [PC dashboard](screenshots/assetkeeper-desktop-dashboard.png)

## Automatic encryption update, November 15

The native engine now uses SQLCipher. Eight additional tests cover legacy and
plaintext migration, wrong/missing keys, ciphertext corruption, orphan/interrupted
migration recovery, and committed-write recovery after SIGKILL. The raw main and
WAL files were checked for the test plaintext marker. This was tested on Linux;
Android builds are checked separately and physical phone acceptance remains pending.

The dependency advisory snapshot and security boundaries are recorded in
[the security report](security/automatic-encryption.md).

## Icon and animation kit, version 1.0.2+3

Integrated the supplied Android launcher resources and the native system splash,
plus a bounded Flutter loading intro. The four new checks cover reduced motion,
finite playback, immediate dismissal on readiness, and Android resource wiring.
Analysis and all 59 tests passed. The debug APK compiled successfully, including
Android 12+ animated-vector resources and Android 13+ monochrome icon variants.
Launcher masking and actual splash timing remain unverified on a physical phone.
See [integration notes](branding-kit/integration.md).

## Android animation handoff fix, 1.0.3+4

The recording was inspected frame by frame and compared with the source GIF.
Android no longer replays that GIF after the native splash. The handoff uses a
clean static mark and matching background, with immediate native-overlay removal.
A widget regression covers the Android-specific handoff and early dismissal;
the Android resource/Kotlin compiler validates the guarded native callback.
Physical-device confirmation of the fix remains pending.

## GitHub updates and release builds, 1.0.4+5

69 Flutter tests passed; the analyzer reported no issues. New tests cover exact
platform downloads, version ordering, rejection of foreign URLs/drafts/previews,
offline checks, setup/editor deferral, manual rechecks and small-phone large-text
popup layouts in light and dark themes. Release-script tests also guard against
partial publication, replacement of published files, non-increasing versions and
Android build numbers, and missing SQLCipher libraries.

Local production APK and Linux builds compiled. Android packaging checks the
public production certificate fingerprint, package identity, version code/name
and SQLCipher libraries for all three APK architectures. GitHub Actions runs
validation and separate Android/Linux/Windows builds before publishing a complete
stable release. Build logs and final artifacts are available in the repository.
This does not constitute physical Android/Windows installation acceptance.

The native Linux integration test also passed after adding updates, including
temporary secure storage and encrypted inventory reopen. Native-rendered phone
and desktop popup captures were visually inspected. The updated OSV query checked
92 Pub package versions and returned no matching advisories; its scope does not
cover every native-library, OS or application-level vulnerability.
