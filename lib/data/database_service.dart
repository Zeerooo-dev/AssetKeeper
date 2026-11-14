import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite_common/sqlite_api.dart';

import '../models/models.dart';
import '../platform/database_lock.dart';
import '../services/database_crypto.dart';
import '../services/sqlcipher_storage.dart';

class UserError implements Exception {
  const UserError(this.message);
  final String message;
  @override
  String toString() => message;
}

String errorMessage(Object error) {
  if (error is UserError) return error.message;
  if (error is FormatException) return error.message;
  if (error is DatabaseException) {
    if (error.isUniqueConstraintError()) {
      return 'That property number, employee code, or name already exists.';
    }
    if (error.toString().contains('FOREIGN KEY')) {
      return 'This record is in use. Reassign its assets first; history references must be preserved.';
    }
  }
  return 'The operation could not finish. Your saved records are preserved. $error';
}

class DatabaseService {
  DatabaseService(
    this.factory,
    this.path, {
    this.protectAtRest = true,
    DatabaseKeyStore? keyStore,
  }) : _cipher = protectAtRest
           ? SqlCipherStorage(factory, path, keyStore: keyStore)
           : null;

  final DatabaseFactory factory;
  final String path;
  final bool protectAtRest;
  final SqlCipherStorage? _cipher;
  late final _fileLock = DatabaseFileLock(path);
  Database? _database;
  Database get db =>
      _database ??
      (throw const UserError(
        'The database is closed. Reopen it before continuing.',
      ));
  bool get isOpen => _database != null;

  Future<void> open() async {
    if (_database != null) return;
    if (protectAtRest) await _fileLock.acquire();
    try {
      await _cipher?.prepare();
      _database = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: true,
          onConfigure: (database) async {
            await _cipher?.configure(database);
            await database.execute('PRAGMA foreign_keys = ON');
            await database.execute('PRAGMA busy_timeout = 5000');
          },
          onCreate: (database, version) async {
            final sql = await rootBundle.loadString(
              'assets/migrations/001_initial.sql',
            );
            // Keep trigger bodies together; their internal semicolons precede END.
            for (final statement in sql.split(
              RegExp(r';\s*(?=(?:CREATE|INSERT)\b|$)'),
            )) {
              if (statement.trim().isNotEmpty) {
                await database.execute(statement);
              }
            }
          },
        ),
      );
    } catch (_) {
      if (protectAtRest) await _fileLock.release();
      rethrow;
    }
  }

  Future<void> close() async {
    final database = _database;
    if (database == null) return;
    _database = null;
    try {
      await database.close();
    } finally {
      if (protectAtRest) await _fileLock.release();
    }
  }

  Future<Map<String, String>> settings() async => {
    for (final row in await db.query('settings'))
      row['key'] as String: row['value'] as String,
  };

  String _text(
    String value,
    String label,
    int maximum, {
    bool optional = false,
  }) {
    final trimmed = value.trim();
    if ((!optional && trimmed.isEmpty) || trimmed.length > maximum) {
      throw UserError(
        '$label must contain ${optional ? 'at most' : '1 to'} $maximum characters.',
      );
    }
    return trimmed;
  }

  String _date(String value, String label) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        day(parsed) != value ||
        value.compareTo(day(DateTime.now())) > 0) {
      throw UserError('Choose a valid $label that is not in the future.');
    }
    return value;
  }

  Future<String> _actor(DatabaseExecutor tx) async {
    final rows = await tx.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['operator'],
    );
    if (rows.isEmpty) {
      throw const UserError('Set your operator name before changing records.');
    }
    return _text(rows.single['value'] as String, 'Operator name', 120);
  }

  Future<void> _audit(
    DatabaseExecutor tx,
    String action,
    String actor,
    Object details, {
    int? assetId,
  }) async {
    await tx.insert('audit_log', {
      'asset_id': assetId,
      'action': action,
      'actor': actor,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'details': jsonEncode(details),
    });
  }

  Future<void> saveSettings(String operatorName, String theme) async {
    final actor = _text(operatorName, 'Operator name', 120);
    if (!['defaultLight', 'dark', 'blueSteel', 'sageField'].contains(theme)) {
      throw const UserError('Choose a supported theme.');
    }
    await db.transaction((tx) async {
      final before = await tx.query('settings');
      for (final entry in {'operator': actor, 'theme': theme}.entries) {
        await tx.insert('settings', {
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await _audit(tx, 'Settings updated', actor, {
        'before': before,
        'operator': actor,
        'theme': theme,
      });
    });
  }

  Future<List<Reference>> references(String table) async {
    _referenceTable(table);
    return (await db.query(
      table,
      orderBy: 'name COLLATE NOCASE',
    )).map(Reference.fromMap).toList();
  }

  void _referenceTable(String table) {
    if (table != 'branches' && table != 'categories') {
      throw ArgumentError.value(table);
    }
  }

  Future<int> saveReference(String table, String name, {int? id}) async {
    _referenceTable(table);
    name = _text(
      name,
      table == 'branches' ? 'Branch name' : 'Category name',
      100,
    );
    return db.transaction((tx) async {
      final actor = await _actor(tx);
      final before = id == null
          ? null
          : (await tx.query(
              table,
              where: 'id = ?',
              whereArgs: [id],
            )).firstOrNull;
      if (id != null && before == null) {
        throw const UserError(
          'This record no longer exists. Refresh and try again.',
        );
      }
      if (id == null) {
        id = await tx.insert(table, {'name': name});
      } else {
        await tx.update(
          table,
          {'name': name},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await _audit(
        tx,
        '${table == 'branches' ? 'Branch' : 'Category'} ${before == null ? 'added' : 'renamed'}',
        actor,
        {'id': id, 'before': before, 'name': name},
      );
      return id!;
    });
  }

  Future<void> deleteReference(String table, int id) async {
    _referenceTable(table);
    await db.transaction((tx) async {
      final actor = await _actor(tx);
      final rows = await tx.query(table, where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) throw const UserError('This record no longer exists.');
      await tx.delete(table, where: 'id = ?', whereArgs: [id]);
      await _audit(
        tx,
        '${table == 'branches' ? 'Branch' : 'Category'} removed',
        actor,
        rows.single,
      );
    });
  }

  Future<List<Employee>> employees() async => (await db.query(
    'employees',
    orderBy: 'name COLLATE NOCASE, code',
  )).map(Employee.fromMap).toList();
  Future<int> saveEmployee(
    String name,
    String code,
    String unit, {
    int? id,
  }) async {
    name = _text(name, 'Employee name', 120);
    code = _text(code, 'Employee code', 60);
    unit = _text(unit, 'Organizational unit', 100, optional: true);
    return db.transaction((tx) async {
      final actor = await _actor(tx);
      final before = id == null
          ? null
          : (await tx.query(
              'employees',
              where: 'id = ?',
              whereArgs: [id],
            )).firstOrNull;
      if (id != null && before == null) {
        throw const UserError('This employee no longer exists.');
      }
      final data = {'name': name, 'code': code, 'unit': unit};
      if (id == null) {
        id = await tx.insert('employees', data);
      } else {
        await tx.update('employees', data, where: 'id = ?', whereArgs: [id]);
      }
      await _audit(
        tx,
        'Employee ${before == null ? 'added' : 'updated'}',
        actor,
        {'id': id, 'before': before, 'after': data},
      );
      return id!;
    });
  }

  Future<void> deleteEmployee(int id) async {
    await db.transaction((tx) async {
      final actor = await _actor(tx);
      final rows = await tx.query(
        'employees',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) {
        throw const UserError('This employee no longer exists.');
      }
      await tx.delete('employees', where: 'id = ?', whereArgs: [id]);
      await _audit(tx, 'Employee removed', actor, rows.single);
    });
  }

  static const _assetSelect = '''SELECT a.*, c.name AS category_name,
    b.name AS branch_name, e.name AS employee_name, e.code AS employee_code
    FROM assets a JOIN categories c ON c.id=a.category_id
    JOIN branches b ON b.id=a.branch_id JOIN employees e ON e.id=a.employee_id''';

  Future<Asset?> findAsset(int id) async {
    final rows = await db.rawQuery('$_assetSelect WHERE a.id=?', [id]);
    return rows.isEmpty ? null : Asset(rows.single);
  }

  Future<List<Asset>> assets({
    InventoryQuery? query,
    int? limit,
    int offset = 0,
  }) async {
    final q = query ?? InventoryQuery();
    final where = <String>['a.archived = ?'];
    final args = <Object?>[q.archived ? 1 : 0];
    if (q.search.trim().isNotEmpty) {
      where.add(
        '(a.name LIKE ? ESCAPE \'\\\' OR a.property_number LIKE ? ESCAPE \'\\\' OR a.serial_number LIKE ? ESCAPE \'\\\' OR e.name LIKE ? ESCAPE \'\\\' OR e.code LIKE ? ESCAPE \'\\\')',
      );
      final search = q.search
          .trim()
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      args.addAll(List.filled(5, '%$search%'));
    }
    for (final entry in {
      'category_id': q.categoryId,
      'branch_id': q.branchId,
      'employee_id': q.employeeId,
      'status': q.status.isEmpty ? null : q.status,
    }.entries) {
      if (entry.value != null) {
        where.add('a.${entry.key} = ?');
        args.add(entry.value);
      }
    }
    final sort = switch (q.sort) {
      'Acquisition value' => 'a.price_centavos DESC',
      'Acquisition date' => 'a.acquisition_date DESC',
      'Property number' => 'a.property_number COLLATE NOCASE',
      _ => 'a.name COLLATE NOCASE',
    };
    final paging = limit == null ? '' : ' LIMIT ? OFFSET ?';
    if (limit != null) args.addAll([limit, offset]);
    return (await db.rawQuery(
      '$_assetSelect WHERE ${where.join(' AND ')} ORDER BY $sort, a.id$paging',
      args,
    )).map(Asset.new).toList();
  }

  Future<Map<String, Object?>> _current(Transaction tx, Asset asset) async {
    final rows = await tx.query(
      'assets',
      where: 'id = ? AND version = ?',
      whereArgs: [asset.id, asset.version],
    );
    if (rows.isEmpty) {
      throw const UserError(
        'This asset changed in another window. Refresh and try again.',
      );
    }
    if (rows.single['archived'] == 1) {
      throw const UserError(
        'Restore this asset before editing or transferring it.',
      );
    }
    return rows.single;
  }

  Future<void> _employeeHistory(
    Transaction tx,
    int assetId,
    int from,
    int to,
    String date,
    String actor,
    String remarks,
  ) async {
    final people = await tx.query(
      'employees',
      where: 'id IN (?, ?)',
      whereArgs: [from, to],
    );
    if (people.length != 2) {
      throw const UserError('Select a different existing employee.');
    }
    await tx.insert('accountability_transfers', {
      'asset_id': assetId,
      'previous_employee_id': from,
      'new_employee_id': to,
      'previous_employee_name': people.singleWhere(
        (e) => e['id'] == from,
      )['name'],
      'new_employee_name': people.singleWhere((e) => e['id'] == to)['name'],
      'transfer_date': date,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'actor': actor,
      'remarks': remarks,
    });
  }

  Future<void> _unitHistory(
    Transaction tx,
    int assetId,
    String from,
    String to,
    String date,
    String actor,
    String remarks,
  ) async {
    from = _text(from, 'Previous unit', 100);
    to = _text(to, 'Destination unit', 100);
    if (from.toLowerCase() == to.toLowerCase()) {
      throw const UserError('Choose a different destination unit.');
    }
    await tx.insert('unit_transfers', {
      'asset_id': assetId,
      'previous_unit': from,
      'destination_unit': to,
      'transfer_date': date,
      'recorded_at': DateTime.now().toUtc().toIso8601String(),
      'actor': actor,
      'remarks': remarks,
    });
  }

  Future<int> saveAsset(AssetDraft draft, {Asset? existing}) async {
    _text(draft.name, 'Asset name', 120);
    _text(draft.property, 'Property number', 60);
    _text(draft.serial, 'Serial number', 100, optional: true);
    _text(draft.description, 'Description', 2000, optional: true);
    _text(draft.unit, 'Organizational unit', 100, optional: true);
    _text(
      draft.destination,
      'Destination unit',
      100,
      optional: draft.status != transferredStatus,
    );
    _date(draft.acquired, 'acquisition date');
    if (draft.price < 0 || draft.price > 999999999999) {
      throw const UserError('Acquisition price is outside the allowed range.');
    }
    if (!assetStatuses.contains(draft.status)) {
      throw const UserError('Choose a valid asset status.');
    }
    return db.transaction((tx) async {
      final actor = await _actor(tx);
      final before = existing == null ? null : await _current(tx, existing);
      final now = DateTime.now().toUtc().toIso8601String();
      final values = draft.toMap();
      if (before != null) {
        final earliest = await tx.rawQuery(
          '''SELECT MIN(transfer_date) AS first_date FROM (
          SELECT transfer_date FROM accountability_transfers WHERE asset_id=?
          UNION ALL SELECT transfer_date FROM unit_transfers WHERE asset_id=?)''',
          [existing!.id, existing.id],
        );
        final firstDate = earliest.single['first_date'] as String?;
        if (firstDate != null && draft.acquired.compareTo(firstDate) > 0) {
          throw const UserError(
            'Acquisition date cannot be after a recorded transfer.',
          );
        }
      }
      final unitTransfer =
          draft.status == transferredStatus &&
          (before == null ||
              before['status'] != transferredStatus ||
              before['destination_unit'] != draft.destination.trim());
      if (before != null &&
          !unitTransfer &&
          draft.unit.trim() != before['current_unit']) {
        throw const UserError(
          'Use Transfer to change the organizational unit.',
        );
      }
      if (unitTransfer) values['current_unit'] = draft.destination.trim();
      values['updated_at'] = now;
      int id;
      if (existing == null) {
        values['created_at'] = now;
        id = await tx.insert('assets', values);
      } else {
        id = existing.id;
        values['version'] = existing.version + 1;
        await tx.update(
          'assets',
          values,
          where: 'id = ? AND version = ?',
          whereArgs: [id, existing.version],
        );
        if (before!['employee_id'] != draft.employeeId) {
          await _employeeHistory(
            tx,
            id,
            before['employee_id'] as int,
            draft.employeeId,
            day(DateTime.now()),
            actor,
            'Accountability changed through asset editor.',
          );
        }
      }
      if (unitTransfer) {
        final previousUnit = before?['current_unit'] as String?;
        await _unitHistory(
          tx,
          id,
          previousUnit == null || previousUnit.isEmpty
              ? draft.unit.trim()
              : previousUnit,
          draft.destination.trim(),
          day(DateTime.now()),
          actor,
          'Unit transfer recorded through asset editor.',
        );
      }
      await _audit(
        tx,
        existing == null ? 'Asset registered' : 'Asset updated',
        actor,
        {'before': before, 'after': values},
        assetId: id,
      );
      return id;
    });
  }

  Future<void> transfer(
    Asset asset, {
    int? employeeId,
    String? destination,
    String? previousUnit,
    required String transferDate,
    String remarks = '',
  }) async {
    _date(transferDate, 'transfer date');
    if (transferDate.compareTo(asset.acquired) < 0) {
      throw const UserError('Transfer date cannot be before acquisition.');
    }
    _text(remarks, 'Remarks', 1000, optional: true);
    if ((employeeId == null) == (destination == null)) {
      throw const UserError(
        'Choose either an employee transfer or a unit transfer.',
      );
    }
    await db.transaction((tx) async {
      final before = await _current(tx, asset);
      final actor = await _actor(tx);
      final last = await tx.rawQuery(
        '''SELECT MAX(transfer_date) AS latest FROM (
        SELECT transfer_date FROM accountability_transfers WHERE asset_id=?
        UNION ALL SELECT transfer_date FROM unit_transfers WHERE asset_id=?)''',
        [asset.id, asset.id],
      );
      final latest = last.single['latest'] as String?;
      if (latest != null && transferDate.compareTo(latest) < 0) {
        throw const UserError(
          'Transfer date cannot be earlier than the latest recorded transfer.',
        );
      }
      final values = <String, Object?>{
        'version': asset.version + 1,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (employeeId != null) {
        await _employeeHistory(
          tx,
          asset.id,
          before['employee_id'] as int,
          employeeId,
          transferDate,
          actor,
          remarks.trim(),
        );
        values['employee_id'] = employeeId;
      } else {
        final from = (before['current_unit'] as String).isEmpty
            ? previousUnit ?? ''
            : before['current_unit'] as String;
        await _unitHistory(
          tx,
          asset.id,
          from,
          destination!,
          transferDate,
          actor,
          remarks.trim(),
        );
        values.addAll({
          'status': transferredStatus,
          'current_unit': destination.trim(),
          'destination_unit': destination.trim(),
        });
      }
      await tx.update(
        'assets',
        values,
        where: 'id = ? AND version = ?',
        whereArgs: [asset.id, asset.version],
      );
      await _audit(
        tx,
        employeeId != null
            ? 'Accountability transferred'
            : 'Transferred to other unit',
        actor,
        {
          'before': before,
          'after': values,
          'transfer_date': transferDate,
          'remarks': remarks.trim(),
        },
        assetId: asset.id,
      );
    });
  }

  Future<void> archive(Asset asset, bool archived) async {
    await db.transaction((tx) async {
      final actor = await _actor(tx);
      final count = await tx.update(
        'assets',
        {
          'archived': archived ? 1 : 0,
          'version': asset.version + 1,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ? AND version = ?',
        whereArgs: [asset.id, asset.version],
      );
      if (count != 1) {
        throw const UserError(
          'This asset changed. Refresh before trying again.',
        );
      }
      await _audit(tx, archived ? 'Asset archived' : 'Asset restored', actor, {
        'property_number': asset.property,
      }, assetId: asset.id);
    });
  }

  Future<List<Transfer>> transfers({
    int? assetId,
    int limit = 100,
    int offset = 0,
  }) async {
    const employeeSql = '''SELECT t.id,t.asset_id,'employee' AS kind,a.name AS asset_name,a.property_number,
      t.previous_employee_name AS from_name,t.new_employee_name AS to_name,
      t.transfer_date,t.recorded_at,t.actor,t.remarks FROM accountability_transfers t JOIN assets a ON a.id=t.asset_id''';
    const unitSql = '''SELECT t.id,t.asset_id,'unit' AS kind,a.name AS asset_name,a.property_number,
      t.previous_unit AS from_name,t.destination_unit AS to_name,
      t.transfer_date,t.recorded_at,t.actor,t.remarks FROM unit_transfers t JOIN assets a ON a.id=t.asset_id''';
    final where = assetId == null ? '' : ' WHERE t.asset_id=?';
    return (await db.rawQuery(
      'SELECT * FROM ($employeeSql$where UNION ALL $unitSql$where) ORDER BY recorded_at DESC,id DESC LIMIT ? OFFSET ?',
      [
        if (assetId != null) ...[assetId, assetId],
        limit,
        offset,
      ],
    )).map(Transfer.new).toList();
  }

  Future<List<Map<String, Object?>>> audit({int limit = 50, int offset = 0}) =>
      db.query('audit_log', orderBy: 'id DESC', limit: limit, offset: offset);

  Future<Map<String, int>> metrics() async {
    final rows = await db.rawQuery(
      '''SELECT COUNT(*) AS total, COALESCE(SUM(price_centavos),0) AS value,
      SUM(CASE WHEN c.name='Equipment' COLLATE NOCASE THEN 1 ELSE 0 END) AS equipment,
      SUM(CASE WHEN c.name='Furniture' COLLATE NOCASE THEN 1 ELSE 0 END) AS furniture
      FROM assets a JOIN categories c ON c.id=a.category_id WHERE a.archived=0''',
    );
    final result = rows.single.map(
      (key, value) => MapEntry(key, (value as int?) ?? 0),
    );
    for (final row in await db.rawQuery(
      'SELECT status,COUNT(*) AS count FROM assets WHERE archived=0 GROUP BY status',
    )) {
      result[row['status'] as String] = row['count'] as int;
    }
    return result;
  }
}
