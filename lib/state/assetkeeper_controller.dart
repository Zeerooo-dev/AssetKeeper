import 'package:flutter/foundation.dart';

import '../core/app_theme.dart';
import '../data/database_service.dart';
import '../models/models.dart';

enum AppSection {
  assets,
  dashboard,
  employees,
  transfers,
  branches,
  categories,
  audit,
  settings,
}

extension AppSectionLabel on AppSection {
  String get label => switch (this) {
    AppSection.assets => 'Assets',
    AppSection.dashboard => 'Dashboard',
    AppSection.employees => 'Employees',
    AppSection.transfers => 'Transfers',
    AppSection.branches => 'Branches',
    AppSection.categories => 'Categories',
    AppSection.audit => 'Audit log',
    AppSection.settings => 'Settings',
  };
}

class AssetKeeperController extends ChangeNotifier {
  AssetKeeperController(this.database);
  final DatabaseService database;
  bool loading = true, closed = false;
  String? error;
  String operatorName = '';
  AssetKeeperTheme theme = AssetKeeperTheme.defaultLight;
  List<Reference> branches = [], categories = [];
  List<Employee> employees = [];
  Map<String, int> metrics = {};
  List<Transfer> recentTransfers = [];
  int revision = 0;
  AppSection section = AppSection.assets;
  final inventoryQuery = InventoryQuery();

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await database.open();
      closed = false;
      await refresh();
    } catch (e) {
      error = errorMessage(e);
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    final values = await Future.wait<Object>([
      database.references('branches'),
      database.references('categories'),
      database.employees(),
      database.settings(),
      database.metrics(),
      database.transfers(limit: 5),
    ]);
    branches = values[0] as List<Reference>;
    categories = values[1] as List<Reference>;
    employees = values[2] as List<Employee>;
    final settings = values[3] as Map<String, String>;
    operatorName = settings['operator'] ?? '';
    theme =
        AssetKeeperTheme.values
            .where((v) => v.name == settings['theme'])
            .firstOrNull ??
        AssetKeeperTheme.defaultLight;
    metrics = values[4] as Map<String, int>;
    recentTransfers = values[5] as List<Transfer>;
    revision++;
    notifyListeners();
  }

  void navigate(AppSection value, {int? employeeId}) {
    if (employeeId != null) {
      inventoryQuery.clear();
      inventoryQuery.employeeId = employeeId;
    }
    section = value;
    notifyListeners();
  }

  Future<void> closeDatabase() async {
    try {
      await database.close();
    } catch (e) {
      error = errorMessage(e);
      rethrow;
    } finally {
      closed = !database.isOpen;
      notifyListeners();
    }
  }
}
