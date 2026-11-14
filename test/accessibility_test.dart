import 'package:assetkeeper/core/app_theme.dart';
import 'package:assetkeeper/data/database_service.dart';
import 'package:assetkeeper/models/models.dart';
import 'package:assetkeeper/state/assetkeeper_controller.dart';
import 'package:assetkeeper/ui/pages/asset_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('all themes support long status fields on large-text phones', (
    tester,
  ) async {
    sqfliteFfiInit();
    final database = DatabaseService(
      databaseFactoryFfiNoIsolate,
      inMemoryDatabasePath,
      protectAtRest: false,
    );
    late AssetKeeperController controller;
    late Asset asset;
    await tester.runAsync(() async {
      await database.open();
      await database.saveSettings('Officer', 'defaultLight');
      final employee = await database.saveEmployee(
        'Property custodian',
        'EMP-01',
        'Administration',
      );
      final id = await database.saveAsset(
        AssetDraft(
          name: 'Office cabinet',
          property: 'PROP-LONG',
          categoryId: 2,
          employeeId: employee,
          branchId: 1,
          price: 850000,
          acquired: '2025-01-01',
          status: transferredStatus,
          unit: 'Administration',
          destination: 'Accounting',
        ),
      );
      asset = (await database.findAsset(id))!;
      controller = AssetKeeperController(database);
      await controller.initialize();
    });
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final theme in AssetKeeperTheme.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AssetKeeperThemes.build(theme),
          home: AssetEditor(
            key: ValueKey(theme),
            controller: controller,
            asset: asset,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: theme.name);
      expect(find.text('Destination unit *'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.runAsync(database.close);
  });
}
