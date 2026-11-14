import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('A temporary test database path is required.');
  }
  final key =
      (await stdin
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .first)
          .trim();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
    throw ArgumentError('Invalid test key.');
  }
  final db = sqlite3.open(args.single);
  db.execute('PRAGMA key = "x\'$key\'"');
  if (db.select('PRAGMA cipher_version').isEmpty) {
    throw StateError('SQLCipher unavailable.');
  }
  db.execute('PRAGMA journal_mode = WAL');
  db.execute('CREATE TABLE crash_probe(value TEXT NOT NULL)');
  db.execute('INSERT INTO crash_probe VALUES (?)', [
    'CONFIDENTIAL-CRASH-RECORD',
  ]);
  stdout.writeln('COMMITTED');
  // The parent test force-kills this process without closing SQLite.
  await Future<void>.delayed(const Duration(minutes: 2));
  db.close();
}
