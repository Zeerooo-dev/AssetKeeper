import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<DatabaseFactory> createFactory() async {
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

Future<String> databasePath(
  DatabaseFactory factory, {
  required bool sandbox,
}) async {
  final dir = await getApplicationSupportDirectory();
  final assetKeeperDir = Directory(p.join(dir.path, 'AssetKeeper'));
  if (!await assetKeeperDir.exists()) {
    await assetKeeperDir.create(recursive: true);
  }
  return p.join(
    assetKeeperDir.path,
    sandbox ? 'assetkeeper_sandbox.db' : 'assetkeeper.db',
  );
}
