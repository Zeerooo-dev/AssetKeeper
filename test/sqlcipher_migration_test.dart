import 'dart:convert';
import 'dart:io';

import 'package:assetkeeper/data/database_service.dart';
import 'package:assetkeeper/services/database_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/sqlite3.dart' as native;

import 'database_lifecycle_test.dart' show TestKeys;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late String path;
  late TestKeys keys;
  setUp(() async {
    sqfliteFfiInit();
    temp = await Directory.systemTemp.createTemp('assetkeeper-cipher-');
    path = '${temp.path}/data.db';
    keys = TestKeys();
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  Future<void> plaintext() async {
    final old = DatabaseService(
      databaseFactoryFfiNoIsolate,
      path,
      protectAtRest: false,
    );
    await old.open();
    await old.saveSettings('Original operator', 'dark');
    await old.saveEmployee('Employee', 'EMP-1', 'IT');
    await old.close();
  }

  DatabaseService service() =>
      DatabaseService(databaseFactoryFfiNoIsolate, path, keyStore: keys);
  void unreadable() {
    final db = native.sqlite3.open(path);
    try {
      expect(
        () => db.select('SELECT * FROM settings'),
        throwsA(isA<native.SqliteException>()),
      );
    } finally {
      db.close();
    }
  }

  test('plaintext migration preserves schema version, settings, employees and triggers', () async {
    await plaintext();
    final db = service();
    try {
      await db.open();
      expect((await db.settings())['operator'], 'Original operator');
      expect((await db.employees()).single.code, 'EMP-1');
      unreadable();
      await expectLater(
        db.db.rawDelete('DELETE FROM audit_log'),
        throwsA(isA<DatabaseException>()),
      );
      expect(await File('$path.plaintext-migrating').exists(), false);
    } finally {
      await db.close();
    }
  });
  test(
    'old encrypted envelope migrates without requiring manual closing',
    () async {
      await plaintext();
      final legacy = DatabaseCrypto(
        databaseFactoryFfiNoIsolate,
        path,
        keyStore: keys,
      );
      await legacy.decryptIfNeeded();
      await legacy.encryptAndDeletePlaintext();
      final db = service();
      try {
        await db.open();
        expect((await db.settings())['operator'], 'Original operator');
        unreadable();
        expect(await File('$path.enc').exists(), false);
      } finally {
        await db.close();
      }
    },
  );
  test(
    'missing SQLCipher key fails closed without replacing ciphertext',
    () async {
      final db = service();
      await db.open();
      await db.saveSettings('Officer', 'defaultLight');
      await db.close();
      final original = await File(path).readAsBytes();
      keys.keys.clear();
      await expectLater(service().open(), throwsStateError);
      expect(await File(path).readAsBytes(), original);
      expect(keys.keys, isEmpty);
    },
  );
  test(
    'corrupt ciphertext is preserved rather than opened as plaintext',
    () async {
      final db = service();
      await db.open();
      await db.saveSettings('Officer', 'defaultLight');
      await db.close();
      final bytes = await File(path).readAsBytes();
      bytes[bytes.length - 16] ^= 255;
      await File(path).writeAsBytes(bytes);
      await expectLater(service().open(), throwsStateError);
      expect(await File(path).readAsBytes(), bytes);
    },
  );
  test(
    'interrupted plaintext promotion recovers a verified encrypted candidate',
    () async {
      await plaintext();
      final old = await File(path).readAsBytes();
      final db = service();
      await db.open();
      await db.close();
      await File(path).rename('$path.cipher-migrating');
      await File('$path.plaintext-migrating').writeAsBytes(old);
      final reopened = service();
      try {
        await reopened.open();
        expect((await reopened.settings())['operator'], 'Original operator');
        expect(await File('$path.plaintext-migrating').exists(), false);
        unreadable();
      } finally {
        await reopened.close();
      }
    },
  );
  test('orphan migration file fails closed and is never replaced by an empty store', () async {
    final db = service();
    await db.open();
    await db.saveSettings('Officer', 'defaultLight');
    await db.close();
    await File(path).rename('$path.cipher-migrating');
    final original = await File('$path.cipher-migrating').readAsBytes();
    await expectLater(service().open(), throwsStateError);
    expect(await File(path).exists(), false);
    expect(await File('$path.cipher-migrating').readAsBytes(), original);
  });
  test('wrong device key cannot open or rewrite the database', () async {
    final db = service();
    await db.open();
    await db.saveSettings('Officer', 'defaultLight');
    await db.close();
    final original = await File(path).readAsBytes();
    keys.keys.updateAll((_, value) => base64Encode(List.filled(32, 1)));
    await expectLater(service().open(), throwsStateError);
    expect(await File(path).readAsBytes(), original);
  });
  test(
    'committed data survives SIGKILL and main/WAL files contain no plaintext',
    () async {
      final db = service();
      await db.open();
      await db.saveSettings('Officer', 'defaultLight');
      await db.close();
      final hex = base64Decode(keys.keys.values.single)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final child = await Process.start('dart', [
        'run',
        'tool/encryption_crash_probe.dart',
        path,
      ], workingDirectory: Directory.current.path);
      final stderr = child.stderr.transform(utf8.decoder).join();
      try {
        child.stdin.writeln(hex);
        await child.stdin.flush();
        final ready = await child.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 50));
        expect(ready, 'COMMITTED');
        child.kill(ProcessSignal.sigkill);
        await child.exitCode;
        await stderr;
        for (final file in [File(path), File('$path-wal')]) {
          if (await file.exists()) {
            final text = latin1.decode(await file.readAsBytes());
            expect(text, isNot(contains('CONFIDENTIAL-CRASH-RECORD')));
            expect(text.startsWith('SQLite format 3'), false);
          }
        }
        final reopened = service();
        try {
          await reopened.open();
          expect(
            (await reopened.db.query('crash_probe')).single['value'],
            'CONFIDENTIAL-CRASH-RECORD',
          );
        } finally {
          await reopened.close();
        }
      } finally {
        child.kill(ProcessSignal.sigkill);
        await child.exitCode;
      }
    },
    skip: Platform.isWindows,
  );
}
