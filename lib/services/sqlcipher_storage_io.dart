import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqlite3/sqlite3.dart' as native;

import 'database_crypto.dart';

class SqlCipherStorage {
  SqlCipherStorage(this.factory, this.path, {DatabaseKeyStore? keyStore})
    : keyStore = keyStore ?? const SecureDatabaseKeyStore();
  final DatabaseFactory factory;
  final String path;
  final DatabaseKeyStore keyStore;
  String? _hex;
  String get _keySql => 'PRAGMA key = "x\'${_hex!}\'"';
  File get _pending => File('$path.cipher-migrating');
  File get _previous => File('$path.plaintext-migrating');

  Future<bool> _plaintext(File file) async {
    if (!await file.exists()) return false;
    final handle = await file.open();
    try {
      return ascii.decode(await handle.read(16), allowInvalid: true) ==
          'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }

  Future<void> _loadKey({required bool create}) async {
    final hash = await Sha256().hash(utf8.encode(path));
    final name = 'assetkeeper.database.v3.${base64Url.encode(hash.bytes)}';
    var saved = await keyStore.read(name);
    if (saved == null) {
      if (!create) {
        throw StateError(
          'The database encryption key is missing. Original files are preserved.',
        );
      }
      final key = await AesGcm.with256bits().newSecretKey();
      saved = base64Encode(await key.extractBytes());
      await keyStore.write(name, saved);
      if (await keyStore.read(name) != saved) {
        throw StateError(
          'Device secure storage could not retain the database key.',
        );
      }
    }
    final bytes = base64Decode(saved);
    if (bytes.length != 32) {
      throw StateError('Invalid database encryption key.');
    }
    _hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _verify(File file) {
    final db = native.sqlite3.open(file.path, mode: native.OpenMode.readOnly);
    try {
      db.execute(_keySql);
      if (db.select('PRAGMA cipher_version').isEmpty) {
        throw StateError('SQLCipher is unavailable.');
      }
      if (db.select('PRAGMA cipher_integrity_check').isNotEmpty ||
          db.select('PRAGMA integrity_check').single.values.single != 'ok') {
        throw StateError('Encrypted database verification failed.');
      }
    } finally {
      db.close();
    }
  }

  Future<void> prepare() async {
    try {
      await _prepare();
    } catch (_) {
      // Driver exceptions can contain keyed SQL; never forward them to UI or logs.
      throw StateError(
        'Encrypted storage could not be opened or migrated. Check the device keyring and close older AssetKeeper windows. Existing files were retained for recovery.',
      );
    }
  }

  Future<void> _prepare() async {
    final file = File(path);
    final legacy = File('$path.enc');
    if (await legacy.exists()) {
      final working = File('$path.legacy-migrating');
      if (await file.exists()) {
        if (await _plaintext(file)) {
          throw StateError('Ambiguous legacy database files.');
        }
        await _loadKey(create: false);
        _verify(file);
      } else {
        if (await _previous.exists()) {
          throw StateError('Ambiguous migration files.');
        }
        await _loadKey(create: !await _pending.exists());
        try {
          await DatabaseCrypto(
            factory,
            path,
            keyStore: keyStore,
          ).decryptIfNeeded(outputPath: working.path, preserveEncrypted: true);
          await _export(working.path);
          await _pending.rename(path);
        } finally {
          if (await working.exists()) await working.delete();
        }
      }
      if (await working.exists()) await working.delete();
      await legacy.delete();
      return;
    }
    final plain = await _plaintext(file);
    final cipherExists =
        (await file.exists() && !plain) || await _pending.exists();
    await _loadKey(create: !cipherExists);
    if (await file.exists() && !plain) {
      _verify(file);
      if (await _previous.exists()) await _previous.delete();
      return;
    }
    if (!await file.exists() && await _previous.exists()) {
      if (await _pending.exists()) {
        _verify(_pending);
        await _pending.rename(path);
        await _previous.delete();
        return;
      }
      await _previous.rename(path);
    }
    if (!await file.exists() && await _pending.exists()) {
      throw StateError('An encrypted migration candidate needs recovery.');
    }
    if (!await file.exists()) return;
    if (!await _plaintext(file)) throw StateError('Unrecognized database.');
    await _export(path);
    if (await _previous.exists()) {
      throw StateError('Ambiguous migration backup.');
    }
    await file.rename(_previous.path);
    await _pending.rename(path);
    await _previous.delete();
  }

  Future<void> _export(String sourcePath) async {
    // An interrupted export is discarded only while its intact source still exists.
    if (await _pending.exists()) await _pending.delete();
    final source = native.sqlite3.open(sourcePath);
    try {
      source.execute('PRAGMA temp_store = MEMORY');
      if (source.select('PRAGMA cipher_version').isEmpty) {
        throw StateError('SQLCipher is unavailable.');
      }
      if (source.select('PRAGMA integrity_check').single.values.single !=
          'ok') {
        throw StateError('Source database is damaged.');
      }
      final version =
          source.select('PRAGMA user_version').single.values.single as int;
      source.execute('ATTACH DATABASE ? AS encrypted KEY "x\'${_hex!}\'"', [
        _pending.path,
      ]);
      source.execute('BEGIN IMMEDIATE');
      try {
        source.select("SELECT sqlcipher_export('encrypted')");
        source.execute('PRAGMA encrypted.user_version = $version');
        for (final row in source.select(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        )) {
          final name = (row['name'] as String).replaceAll('"', '""');
          if (source
                  .select('SELECT COUNT(*) FROM main."$name"')
                  .single
                  .values
                  .single !=
              source
                  .select('SELECT COUNT(*) FROM encrypted."$name"')
                  .single
                  .values
                  .single) {
            throw StateError('Migration row count mismatch.');
          }
        }
        source.execute('COMMIT');
      } catch (_) {
        source.execute('ROLLBACK');
        rethrow;
      }
      source.execute('DETACH DATABASE encrypted');
    } finally {
      source.close();
    }
    _verify(_pending);
  }

  Future<void> configure(DatabaseExecutor db) async {
    try {
      if (_hex == null) throw StateError('Encryption key is unavailable.');
      await db.execute(_keySql);
      if ((await db.rawQuery('PRAGMA cipher_version')).isEmpty) {
        throw StateError('SQLCipher is unavailable.');
      }
      await db.execute('PRAGMA cipher_memory_security = ON');
      await db.execute('PRAGMA temp_store = MEMORY');
      await db.execute('PRAGMA secure_delete = ON');
      await db.rawQuery('SELECT count(*) FROM sqlite_master');
    } catch (_) {
      throw StateError(
        'Encrypted database verification failed. No plaintext fallback is allowed.',
      );
    }
  }
}
