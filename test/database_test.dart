import 'dart:io';

import 'package:assetkeeper/data/database_service.dart';
import 'package:assetkeeper/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseService service;
  late int juan, maria;
  AssetDraft draft({
    String name = 'Office Chair',
    String property = 'PROP-001',
    String serial = '',
    int? employee,
    int category = 1,
    String status = 'Active',
    String unit = 'Administration',
    String destination = '',
    int price = 550025,
    String acquired = '2025-02-15',
    int branch = 1,
  }) => AssetDraft(
    name: name,
    property: property,
    categoryId: category,
    employeeId: employee ?? juan,
    branchId: branch,
    price: price,
    acquired: acquired,
    serial: serial,
    status: status,
    unit: unit,
    destination: destination,
  );
  Future<Asset> create({AssetDraft? value}) async =>
      (await service.findAsset(await service.saveAsset(value ?? draft())))!;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    service = DatabaseService(
      databaseFactoryFfiNoIsolate,
      inMemoryDatabasePath,
      protectAtRest: false,
    );
    await service.open();
    await service.saveSettings('Property Officer', 'defaultLight');
    juan = await service.saveEmployee(
      'Juan Dela Cruz',
      'EMP-001',
      'Administration',
    );
    maria = await service.saveEmployee('Maria Santos', 'EMP-002', 'IT');
  });
  tearDown(() => service.close());

  test(
    'migration seeds reference data only, with foreign keys enabled',
    () async {
      expect(
        (await service.references('branches')).single.name,
        'Valencia Branch',
      );
      expect((await service.references('categories')).map((e) => e.name), [
        'Equipment',
        'Furniture',
      ]);
      expect(await service.assets(), isEmpty);
      expect(
        (await service.db.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
    },
  );
  test(
    'equipment and furniture register with internal IDs and optional serials',
    () async {
      final a = await create(value: draft(serial: 'SN-001'));
      final b = await create(value: draft(property: 'PROP-002', category: 2));
      expect(a.id, isNot(b.id));
      expect(a.serial, 'SN-001');
      expect(b.serial, '');
      expect(b.price, 550025);
      expect(b.employee, 'Juan Dela Cruz');
      expect(b.category, 'Furniture');
    },
  );
  test('property number uniqueness is case insensitive and includes archived assets', () async {
    final a = await create();
    await service.archive(a, true);
    await expectLater(
      service.saveAsset(draft(property: ' prop-001 ')),
      throwsA(isA<DatabaseException>()),
    );
  });
  test('employee transfer atomically updates assignment without changing condition', () async {
    final a = await create(value: draft(status: 'Obsolete'));
    await service.transfer(
      a,
      employeeId: maria,
      transferDate: '2026-01-10',
      remarks: 'Custodian changed',
    );
    final current = (await service.findAsset(a.id))!;
    expect(current.employeeId, maria);
    expect(current.status, 'Obsolete');
    final history = (await service.transfers(assetId: a.id)).single;
    expect(history.from, 'Juan Dela Cruz');
    expect(history.to, 'Maria Santos');
    expect(history.actor, 'Property Officer');
    expect(history.remarks, 'Custodian changed');
  });
  test('editing accountability also preserves history and snapshots after employee rename', () async {
    final a = await create();
    await service.saveAsset(draft(employee: maria), existing: a);
    await service.saveEmployee('Maria S. Santos', 'EMP-002', 'IT', id: maria);
    expect((await service.findAsset(a.id))!.employee, 'Maria S. Santos');
    expect((await service.transfers(assetId: a.id)).single.to, 'Maria Santos');
  });
  test(
    'a failed audit insert rolls back both assignment and transfer row',
    () async {
      final a = await create();
      await service.db.execute(
        "CREATE TRIGGER fail_audit BEFORE INSERT ON audit_log BEGIN SELECT RAISE(ABORT,'Simulated disk error'); END",
      );
      await expectLater(
        service.transfer(a, employeeId: maria, transferDate: '2026-01-10'),
        throwsA(isA<DatabaseException>()),
      );
      expect((await service.findAsset(a.id))!.employeeId, juan);
      expect(await service.transfers(assetId: a.id), isEmpty);
    },
  );
  test('unit transfer requires destination and preserves employee', () async {
    final a = await create();
    await expectLater(
      service.transfer(a, destination: ' ', transferDate: '2026-01-10'),
      throwsA(isA<UserError>()),
    );
    await service.transfer(
      a,
      destination: 'Accounting',
      transferDate: '2026-01-10',
    );
    final current = (await service.findAsset(a.id))!;
    expect(current.employeeId, juan);
    expect(current.status, transferredStatus);
    expect(current.unit, 'Accounting');
    final history = (await service.transfers()).single;
    expect(history.employeeTransfer, false);
    expect(history.from, 'Administration');
    expect(history.to, 'Accounting');
  });
  test('transferred status in editor requires previous/destination units and records the move', () async {
    await expectLater(
      service.saveAsset(draft(status: transferredStatus)),
      throwsA(isA<UserError>()),
    );
    final a = await create(
      value: draft(status: transferredStatus, destination: 'Accounting'),
    );
    expect(a.unit, 'Accounting');
    expect((await service.transfers()).single.to, 'Accounting');
    await service.saveAsset(
      draft(
        status: transferredStatus,
        destination: 'Accounting',
        unit: 'Accounting',
      ),
      existing: a,
    );
    expect(await service.transfers(), hasLength(1));
  });
  test(
    'an unspecified previous unit can be supplied during transfer',
    () async {
      final a = await create(value: draft(unit: ''));
      await service.transfer(
        a,
        destination: 'IT',
        previousUnit: 'Administration',
        transferDate: '2026-01-10',
      );
      expect((await service.transfers()).single.from, 'Administration');
    },
  );
  test('all five statuses can be persisted', () async {
    for (var i = 0; i < assetStatuses.length; i++) {
      final a = await create(
        value: draft(
          property: 'PROP-$i',
          status: assetStatuses[i],
          destination: assetStatuses[i] == transferredStatus ? 'IT' : '',
        ),
      );
      expect(a.status, assetStatuses[i]);
    }
  });
  test(
    'concurrent stale writes cannot overwrite a newer asset or add history',
    () async {
      final a = await create();
      await service.transfer(a, employeeId: maria, transferDate: '2026-01-10');
      await expectLater(
        service.saveAsset(draft(price: 100), existing: a),
        throwsA(isA<UserError>()),
      );
      await expectLater(
        service.transfer(a, destination: 'IT', transferDate: '2026-01-11'),
        throwsA(isA<UserError>()),
      );
      expect((await service.findAsset(a.id))!.employeeId, maria);
      expect(await service.transfers(), hasLength(1));
    },
  );
  test('dates, amounts, foreign keys and destination are validated at storage boundary', () async {
    for (final invalid in [
      draft(acquired: '2026-02-30'),
      draft(acquired: '2999-01-01'),
      draft(price: -1),
      draft(status: 'Low stock'),
      draft(name: ''),
    ]) {
      await expectLater(service.saveAsset(invalid), throwsA(isA<UserError>()));
    }
    await expectLater(
      service.saveAsset(draft(employee: 999)),
      throwsA(isA<DatabaseException>()),
    );
    expect(await service.assets(), isEmpty);
  });
  test(
    'chronology rejects transfers before acquisition or before latest history',
    () async {
      final a = await create();
      await expectLater(
        service.transfer(a, employeeId: maria, transferDate: '2024-01-01'),
        throwsA(isA<UserError>()),
      );
      await service.transfer(a, employeeId: maria, transferDate: '2026-01-10');
      final current = (await service.findAsset(a.id))!;
      await expectLater(
        service.transfer(current, employeeId: juan, transferDate: '2026-01-09'),
        throwsA(isA<UserError>()),
      );
      await expectLater(
        service.saveAsset(
          draft(employee: maria, acquired: '2026-02-01'),
          existing: current,
        ),
        throwsA(isA<UserError>()),
      );
    },
  );
  test('custom branch/category rename preserves asset references; referenced deletion is blocked', () async {
    final branch = await service.saveReference('branches', 'Malaybalay Branch');
    final category = await service.saveReference(
      'categories',
      'Office Appliances',
    );
    final a = await create(
      value: draft(branch: branch, category: category),
    );
    await service.saveReference('branches', 'Malaybalay Main', id: branch);
    expect((await service.findAsset(a.id))!.branch, 'Malaybalay Main');
    await expectLater(
      service.deleteReference('branches', branch),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      service.deleteReference('categories', category),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      service.deleteEmployee(juan),
      throwsA(isA<DatabaseException>()),
    );
  });
  test('filters combine status/category/employee/branch, and search escapes wildcards', () async {
    await create(value: draft(property: 'PROP-100%', category: 2));
    await create(
      value: draft(property: 'PROP-200', employee: maria, status: 'Obsolete'),
    );
    final q = InventoryQuery()
      ..categoryId = 2
      ..employeeId = juan
      ..branchId = 1
      ..status = 'Active';
    expect(await service.assets(query: q), hasLength(1));
    q.clear();
    q.search = '%';
    expect(await service.assets(query: q), hasLength(1));
    q.search = 'EMP-002';
    expect((await service.assets(query: q)).single.employeeId, maria);
  });
  test(
    'metrics derive from live records and exclude archived assets',
    () async {
      await create(value: draft(price: 10, category: 2));
      final b = await create(
        value: draft(property: 'PROP-002', price: 20, status: 'Obsolete'),
      );
      expect((await service.metrics())['value'], 30);
      await service.archive(b, true);
      final metrics = await service.metrics();
      expect(metrics['total'], 1);
      expect(metrics['value'], 10);
      expect(metrics['furniture'], 1);
      expect(
        (await service.assets(query: InventoryQuery()..archived = true))
            .single
            .id,
        b.id,
      );
      await service.archive((await service.findAsset(b.id))!, false);
      expect((await service.metrics())['total'], 2);
    },
  );
  test('transfer and audit history cannot be changed or deleted', () async {
    final a = await create();
    await service.transfer(a, employeeId: maria, transferDate: '2026-01-10');
    final b = (await service.findAsset(a.id))!;
    await service.transfer(b, destination: 'IT', transferDate: '2026-01-11');
    for (final table in [
      'accountability_transfers',
      'unit_transfers',
      'audit_log',
    ]) {
      await expectLater(
        service.db.rawDelete('DELETE FROM $table'),
        throwsA(isA<DatabaseException>()),
      );
      await expectLater(
        service.db.rawUpdate("UPDATE $table SET actor='Changed'"),
        throwsA(isA<DatabaseException>()),
      );
    }
  });
  test('SQLite records and history survive close/reopen', () async {
    final dir = await Directory.systemTemp.createTemp('assetkeeper-test-');
    final disk = DatabaseService(
      databaseFactoryFfiNoIsolate,
      '${dir.path}/test.db',
      protectAtRest: false,
    );
    try {
      await disk.open();
      await disk.saveSettings('Real officer', 'dark');
      final e = await disk.saveEmployee('Employee', 'EMP', 'Administration');
      final id = await disk.saveAsset(
        AssetDraft(
          name: 'Desk',
          property: 'P1',
          categoryId: 2,
          employeeId: e,
          branchId: 1,
          price: 999,
          acquired: '2025-01-01',
          unit: 'Administration',
        ),
      );
      await disk.transfer(
        (await disk.findAsset(id))!,
        destination: 'Accounting',
        transferDate: '2026-01-10',
      );
      await disk.close();
      await disk.open();
      expect((await disk.findAsset(id))!.destination, 'Accounting');
      expect(await disk.transfers(), hasLength(1));
      expect((await disk.settings())['operator'], 'Real officer');
    } finally {
      await disk.close();
      await dir.delete(recursive: true);
    }
  });
}
