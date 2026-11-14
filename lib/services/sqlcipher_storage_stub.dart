import 'package:sqflite_common/sqlite_api.dart';

import 'database_crypto.dart';

class SqlCipherStorage {
  SqlCipherStorage(
    DatabaseFactory factory,
    String path, {
    DatabaseKeyStore? keyStore,
  });
  Future<void> prepare() async => throw UnsupportedError(
    'Native encrypted storage is unavailable in browsers.',
  );
  Future<void> configure(DatabaseExecutor db) async => throw UnsupportedError(
    'Native encrypted storage is unavailable in browsers.',
  );
}
