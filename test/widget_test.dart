import 'package:assetkeeper/data/database_service.dart';
import 'package:assetkeeper/main.dart';
import 'package:assetkeeper/models/models.dart';
import 'package:assetkeeper/state/assetkeeper_controller.dart';
import 'package:assetkeeper/ui/pages/asset_details.dart';
import 'package:assetkeeper/ui/pages/asset_editor.dart';
import 'package:assetkeeper/ui/pages/transfer_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseService database;
  late AssetKeeperController controller;
  late int employee;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = DatabaseService(
      databaseFactoryFfiNoIsolate,
      inMemoryDatabasePath,
      protectAtRest: false,
    );
    await database.open();
    await database.saveSettings('Test Officer', 'defaultLight');
    employee = await database.saveEmployee(
      'Juan Dela Cruz',
      'EMP-001',
      'Administration',
    );
    await database.saveEmployee('Maria Santos', 'EMP-002', 'IT');
    controller = AssetKeeperController(database);
    await controller.initialize();
  });
  tearDown(() async {
    controller.dispose();
    await database.close();
  });

  testWidgets(
    'smartphone registration validates duplicates and furniture without serial',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(AssetKeeperApp(controller: controller));
      await settle(tester);
      expect(find.text('No assets yet'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Add asset'));
      await settle(tester);
      expect(find.byType(AssetEditor), findsOneWidget);
      await tester.enterText(field('Asset name *'), 'Office Chair');
      await tester.enterText(field('Property number *'), 'PROP-001');
      await reveal(tester, field('Acquisition price (₱) *'));
      await tester.enterText(field('Acquisition price (₱) *'), '5500.25');
      final employeeDropdown = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<int> &&
            w.decoration.labelText == 'Accountable employee *',
      );
      await reveal(tester, employeeDropdown);
      await tester.tap(employeeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Dela Cruz · EMP-001').last);
      await tester.pumpAndSettle();
      final categoryDropdown = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<int> &&
            w.decoration.labelText == 'Category *',
      );
      await reveal(tester, categoryDropdown);
      await tester.tap(categoryDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furniture').last);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save asset');
      await reveal(tester, save);
      await tester.tap(save);
      await settle(tester);
      expect(find.byType(AssetEditor), findsNothing);
      final assets = await tester.runAsync(database.assets);
      expect(assets, hasLength(1));
      expect(assets!.single.serial, '');
      expect(assets.single.price, 550025);
      await tester.tap(find.widgetWithText(FilledButton, 'Add asset'));
      await settle(tester);
      await tester.enterText(field('Asset name *'), 'Duplicate chair');
      await tester.enterText(field('Property number *'), 'prop-001');
      await reveal(tester, field('Acquisition price (₱) *'));
      await tester.enterText(field('Acquisition price (₱) *'), '100');
      await reveal(tester, employeeDropdown);
      await tester.tap(employeeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Dela Cruz · EMP-001').last);
      await tester.pumpAndSettle();
      await reveal(tester, save);
      await tester.tap(save);
      await settle(tester);
      expect(find.byType(AssetEditor), findsOneWidget);
      expect(find.textContaining('already exists'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone asset opens full page, transfer changes employee and retains history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final id = await tester.runAsync(
        () => database.saveAsset(
          AssetDraft(
            name: 'Dell Laptop',
            property: 'PROP-001',
            categoryId: 1,
            employeeId: employee,
            branchId: 1,
            price: 5890000,
            acquired: '2025-01-01',
            unit: 'Administration',
          ),
        ),
      );
      await tester.runAsync(controller.refresh);
      await tester.pumpWidget(AssetKeeperApp(controller: controller));
      await settle(tester);
      await tester.tap(find.text('Dell Laptop'));
      await settle(tester);
      expect(find.byType(AssetDetailsPage), findsOneWidget);
      final transfer = find.widgetWithText(FilledButton, 'Transfer');
      await reveal(tester, transfer);
      await tester.tap(transfer);
      await settle(tester);
      expect(find.byType(TransferPage), findsOneWidget);
      final employeeDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int>,
      );
      await tester.tap(employeeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maria Santos · EMP-002').last);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Confirm transfer');
      await reveal(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record transfer'));
      await settle(tester);
      expect(find.byType(TransferPage), findsNothing);
      final asset = await tester.runAsync(() => database.findAsset(id!));
      expect(asset!.employee, 'Maria Santos');
      expect(asset.status, 'Active');
      expect(
        await tester.runAsync(() => database.transfers(assetId: id)),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final spec in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(736, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
    const Size(640, 360),
  ]) {
    testWidgets('all sections fit ${spec.width}x${spec.height}', (
      tester,
    ) async {
      tester.view.physicalSize = spec;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => database.saveAsset(
          AssetDraft(
            name: 'Dell Laptop',
            property: 'PROP-001',
            categoryId: 1,
            employeeId: employee,
            branchId: 1,
            price: 5890000,
            acquired: '2025-01-01',
          ),
        ),
      );
      await tester.runAsync(controller.refresh);
      await tester.pumpWidget(AssetKeeperApp(controller: controller));
      await settle(tester);
      for (final section in AppSection.values) {
        controller.navigate(section);
        await settle(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: '${section.label} at $spec',
        );
      }
    });
  }
  testWidgets(
    'large text and keyboard inset keep smartphone forms scrollable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(AssetKeeperApp(controller: controller));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Add asset'));
      await settle(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      addTearDown(tester.view.resetViewInsets);
      final save = find.widgetWithText(FilledButton, 'Save asset');
      await reveal(tester, save);
      await tester.pumpAndSettle();
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('bottom navigation More opens employee and branch management', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(AssetKeeperApp(controller: controller));
    await settle(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Employees'));
    await settle(tester);
    expect(find.text('Add employee'), findsOneWidget);
    await tester.tap(find.text('Add employee'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Employee name *'), 'Ana Reyes');
    await tester.enterText(field('Employee code *'), 'EMP-003');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Ana Reyes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
