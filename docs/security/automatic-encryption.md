# Automatic native database encryption

Updated November 15, 2026. AssetKeeper now uses SQLCipher for native storage.
The database stays encrypted on disk while open, after each committed save,
in the background, and after process termination. No manual database close is
required. The Settings close button was removed.

## Implementation

- sqlite3 build hooks select the bundled SQLCipher engine. Every native platform
  uses sqflite FFI, with SQLCipher availability checked before normal SQL queries.
- A random 256-bit key is stored in the platform keyring/keystore using a separate
  v3 namespace. A missing, malformed or wrong key fails closed. No replacement key
  is generated for existing encrypted data.
- The key is applied before schema/version queries. Temp storage stays in RAM;
  SQLCipher memory wiping and SQLite secure deletion are enabled. Keyed SQL errors
  are replaced with safe errors, rather than logging the key or raw keyed SQL.
- The database lock and transactional concurrency/history protections are retained.
- Legacy ciphertext is retained through migration until encrypted output passes
  verification. Plaintext migration checks source integrity, exported table counts,
  user_version, encrypted page integrity and SQLite integrity before promotion.
- Interrupted promotion can resume from its verified candidate. Ambiguous/orphan
  files are preserved and opening fails instead of silently creating an empty store.

## Verification

- All 55 automated tests passed, including migration and process-kill tests.
- A child process committed a record in WAL mode, then was killed with SIGKILL
  without closing SQLite. Main/WAL files contained no readable test record, and
  reopening with the key recovered the committed record.
- Plain SQLite access without a key was rejected while the app connection remained
  open. Missing/wrong keys and corrupt ciphertext did not replace stored files.
- Legacy migration retained settings, employee records, schema version and immutable
  audit triggers. Interruption and orphan-file cases were also checked.
- `pub-advisories.json` records the OSV Pub dependency check and timestamp. The final scan checked 82 Pub packages with zero matches. A zero
  result only means OSV returned no matching advisories for those package versions.
  It is not a comprehensive audit of native libraries, OS components or application logic.
- `encryption-engine.json` records the native engine versions observed in integration.

## Boundaries

Browser storage is not encrypted by this update. The UI directs users who need
protected records to the native PC/phone apps. Native changes cannot be rolled
back to older builds without converting storage; older apps cannot read SQLCipher.

Migration can temporarily read old plaintext data; old filesystem blocks and flash
remnants cannot be reliably erased by an app. Use device full-disk encryption.
A compromised OS, unlocked keyring, debugging/instrumentation access, or a malicious
app update can still expose data from a running app. This is encryption at rest,
not user authentication or a claim of zero vulnerabilities.

Linux is the runtime verification host. Physical Android/iOS testing and Windows/
macOS runtime acceptance remain unverified. Supplied Android debug builds are for
functional testing, not production distribution. Production requires proper signing,
a non-debug build and normal platform security review.

## Sources

- [sqlite3 build hooks](https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md)
- [SQLCipher API, encryption and integrity checks](https://www.zetetic.net/sqlcipher/sqlcipher-api/)
- [OSV API](https://google.github.io/osv.dev/api/)

The tested native engine was SQLCipher 4.20.0 community with SQLite 3.54.1.
