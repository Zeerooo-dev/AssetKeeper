import 'package:sqflite_common/sqlite_api.dart';

import 'database_factory_io.dart'
    if (dart.library.js_interop) 'database_factory_web.dart'
    as impl;

class AssetKeeperDatabaseInfo {
  const AssetKeeperDatabaseInfo({required this.factory, required this.path});
  final DatabaseFactory factory;
  final String path;
}

Future<AssetKeeperDatabaseInfo> createAssetKeeperDatabaseFactory({
  required bool sandbox,
}) async {
  final factory = await impl.createFactory();
  final path = await impl.databasePath(factory, sandbox: sandbox);
  return AssetKeeperDatabaseInfo(factory: factory, path: path);
}
