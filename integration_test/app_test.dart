import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:assetkeeper/data/database_service.dart';
import 'package:assetkeeper/main.dart';
import 'package:assetkeeper/models/models.dart';
import 'package:assetkeeper/platform/database_factory.dart';
import 'package:assetkeeper/state/assetkeeper_controller.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native startup, secure storage, PC/phone screens and reopen', (
    tester,
  ) async {
    final info = await createAssetKeeperDatabaseFactory(sandbox: true);
    final temp = await Directory.systemTemp.createTemp(
      'assetkeeper-native-check-',
    );
    final path = '${temp.path}/verification.db';
    final database = DatabaseService(info.factory, path);
    final controller = AssetKeeperController(database);
    final screen = GlobalKey();
    try {
      await controller.initialize();
      if (database.isOpen) {
        final versions = {
          'sqlcipher': await database.db.rawQuery('PRAGMA cipher_version'),
          'sqlite': await database.db.rawQuery(
            'SELECT sqlite_version() AS version',
          ),
        };
        final report = File('build/verification/encryption-engine.json');
        await report.parent.create(recursive: true);
        await report.writeAsString(jsonEncode(versions));
      }
      expect(controller.error, isNull);
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: screen,
          child: AssetKeeperApp(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set up AssetKeeper'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Verification officer',
      );
      final start = find.widgetWithText(
        FilledButton,
        'Start using AssetKeeper',
      );
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('No assets yet'), findsOneWidget);
      final juan = await database.saveEmployee(
        'Juan Dela Cruz',
        'TEST-001',
        'Administration',
      );
      final maria = await database.saveEmployee(
        'Maria Santos',
        'TEST-002',
        'IT',
      );
      final id = await database.saveAsset(
        AssetDraft(
          name: 'Dell Latitude 5440',
          property: 'TEST-PROP-001',
          serial: 'TEST-SERIAL',
          categoryId: 1,
          employeeId: juan,
          branchId: 1,
          price: 5890000,
          acquired: '2026-02-12',
          unit: 'Administration',
          description:
              'Verification record: 14-inch laptop, 16 GB RAM, 512 GB SSD.',
        ),
      );
      await database.saveAsset(
        AssetDraft(
          name: 'Ergonomic Office Chair',
          property: 'TEST-PROP-002',
          categoryId: 2,
          employeeId: juan,
          branchId: 1,
          price: 550000,
          acquired: '2025-02-15',
          unit: 'Administration',
          description: 'Verification record: mesh office chair with adjustable armrests.',
        ),
      );
      await database.saveAsset(
        AssetDraft(
          name: 'Epson EcoTank L3250',
          property: 'TEST-PROP-003',
          categoryId: 1,
          employeeId: maria,
          branchId: 1,
          price: 1199500,
          acquired: '2026-03-08',
          unit: 'Administration',
        ),
      );
      await database.transfer(
        (await database.findAsset(id))!,
        employeeId: maria,
        transferDate: '2026-11-10',
        remarks: 'Verification transfer.',
      );
      await controller.refresh();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dell Latitude 5440').first);
      await tester.pumpAndSettle();
      expect(find.text('Recent transfer history'), findsOneWidget);
      Future<void> screenshot(String name) async {
        final boundary =
            screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/verification/$name.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      }

      await screenshot('assetkeeper-desktop');
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await screenshot('assetkeeper-smartphone');
      await tester.tap(find.text('Dell Latitude 5440').first);
      await tester.pumpAndSettle();
      await screenshot('assetkeeper-smartphone-details');
      await tester.pageBack();
      await tester.pumpAndSettle();
      controller.navigate(AppSection.dashboard);
      await tester.pumpAndSettle();
      await screenshot('assetkeeper-smartphone-dashboard');
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      await screenshot('assetkeeper-desktop-dashboard');
      expect(tester.takeException(), isNull);
      await database.close();
      expect(await File('$path.enc').exists(), false);
      expect(await File(path).exists(), true);
      await database.open();
      expect((await database.assets()).length, 3);
      expect((await database.transfers()).single.to, 'Maria Santos');
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      controller.dispose();
      await database.close();
      final hash = await Sha256().hash(utf8.encode(path));
      await const FlutterSecureStorage().delete(
        key: 'assetkeeper.database.v3.${base64Url.encode(hash.bytes)}',
      );
      await temp.delete(recursive: true);
    }
  });
}
