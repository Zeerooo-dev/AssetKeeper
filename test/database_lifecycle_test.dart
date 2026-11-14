import 'dart:io';

import 'package:assetkeeper/data/database_service.dart';
import 'package:assetkeeper/services/database_crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestKeys implements DatabaseKeyStore {
  final keys = <String, String>{};
  @override
  Future<String?> read(String name) async => keys[name];
  @override
  Future<void> write(String name, String value) async {
    keys[name] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native database stays encrypted while open and lock blocks a second instance', () async {
    sqfliteFfiInit();
    final temp = await Directory.systemTemp.createTemp(
      'assetkeeper-lifecycle-',
    );
    final path = '${temp.path}/inventory.db';
    final keys = TestKeys();
    final first = DatabaseService(
      databaseFactoryFfiNoIsolate,
      path,
      keyStore: keys,
    );
    final second = DatabaseService(
      databaseFactoryFfiNoIsolate,
      path,
      keyStore: keys,
    );
    try {
      await first.open();
      await first.saveSettings('Officer', 'defaultLight');
      await expectLater(second.open(), throwsStateError);
      expect((await first.settings())['operator'], 'Officer');
      expect(
        (await File(path).readAsBytes()).take(16).toList(),
        isNot('SQLite format 3\u0000'.codeUnits),
      );
      await first.close();
      expect(await File(path).exists(), true);
      expect(await File('$path.enc').exists(), false);
      await second.open();
      expect((await second.settings())['operator'], 'Officer');
      await second.close();
      await first.open();
      expect((await first.settings())['operator'], 'Officer');
    } finally {
      await first.close();
      await second.close();
      await temp.delete(recursive: true);
    }
  });
}
