import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/assetkeeper_controller.dart';
import '../widgets/common.dart';
import 'asset_details.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.controller});
  final AssetKeeperController controller;
  @override
  Widget build(BuildContext context) {
    final metrics = controller.metrics;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text('Current registered property · Archived assets excluded'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL ACQUISITION VALUE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  money(metrics['value'] ?? 0),
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${metrics['total'] ?? 0} registered assets across ${controller.branches.length} branches',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final columns =
                box.maxWidth >= 640 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.5
                ? 4
                : box.maxWidth >= 340
                ? 2
                : 1;
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in {
                  'Registered assets': metrics['total'] ?? 0,
                  'Equipment': metrics['equipment'] ?? 0,
                  'Furniture': metrics['furniture'] ?? 0,
                  'Active assets': metrics['Active'] ?? 0,
                }.entries)
                  SizedBox(
                    width: width,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key),
                            const SizedBox(height: 8),
                            Text(
                              '${entry.value}',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final section in [
                AppSection.assets,
                AppSection.employees,
                AppSection.transfers,
                AppSection.branches,
              ])
                SizedBox(
                  width: (box.maxWidth - 8) / 2,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => controller.navigate(section),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(switch (section) {
                              AppSection.assets => Icons.inventory_2_outlined,
                              AppSection.employees => Icons.people_outline,
                              AppSection.transfers => Icons.swap_horiz,
                              _ => Icons.business_outlined,
                            }),
                            const SizedBox(height: 8),
                            Text(section.label, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Asset conditions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final status in assetStatuses)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: StatusLabel(status)),
                        const SizedBox(width: 16),
                        Text('${metrics[status] ?? 0}'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Recent transfers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => controller.navigate(AppSection.transfers),
              child: const Text('View all'),
            ),
          ],
        ),
        if (controller.recentTransfers.isEmpty)
          const EmptyState(
            title: 'No transfers yet',
            message: 'Employee and unit transfers appear here after they are recorded.',
            icon: Icons.swap_horiz,
          )
        else
          Card(
            child: Column(
              children: controller.recentTransfers
                  .map(
                    (t) => TransferTile(
                      t,
                      onTap: () =>
                          openAssetDetails(context, controller, t.assetId),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.controller, this.audit = false});
  final AssetKeeperController controller;
  final bool audit;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int offset = 0;
  late Future<List<Object>> future = load();
  Future<List<Object>> load() async => widget.audit
      ? await widget.controller.database.audit(limit: 21, offset: offset)
      : await widget.controller.database.transfers(limit: 21, offset: offset);
  String auditSummary(Map<String, Object?> row) {
    final details =
        jsonDecode(row['details'] as String) as Map<String, dynamic>;
    final after = details['after'] as Map<String, dynamic>?;
    final before = details['before'];
    final labels = {
      'name': 'Name',
      'property_number': 'Property number',
      'serial_number': 'Serial number',
      'description': 'Description',
      'price_centavos': 'Acquisition price',
      'acquisition_date': 'Acquisition date',
      'status': 'Status',
      'current_unit': 'Organizational unit',
      'destination_unit': 'Destination unit',
      'employee_id': 'Employee',
      'branch_id': 'Branch',
      'category_id': 'Category',
      'code': 'Employee code',
      'unit': 'Organizational unit',
      'archived': 'Archived',
    };
    String format(String key, dynamic value) {
      if (value == null || value == '') return 'None';
      if (key == 'price_centavos') return money(value as int);
      if (key == 'employee_id') return controllerEmployees(value as int);
      if (key == 'branch_id') {
        return widget.controller.branches
                .where((e) => e.id == value)
                .firstOrNull
                ?.name ??
            'Previous branch';
      }
      if (key == 'category_id') {
        return widget.controller.categories
                .where((e) => e.id == value)
                .firstOrNull
                ?.name ??
            'Previous category';
      }
      return '$value';
    }

    if (after != null) {
      final changes = <String>[];
      for (final key in labels.keys) {
        if (after.containsKey(key) &&
            (before is! Map || before[key] != after[key])) {
          changes.add(
            '${labels[key]}: ${before is Map ? '${format(key, before[key])} → ' : ''}${format(key, after[key])}',
          );
        }
      }
      return changes.isEmpty ? 'Record saved.' : changes.join('\n');
    }
    return [
      if (details['property_number'] != null)
        'Property: ${details['property_number']}',
      if (details['name'] != null) 'Name: ${details['name']}',
      if (details['operator'] != null) 'Operator: ${details['operator']}',
      if (details['theme'] != null) 'Appearance preference saved.',
    ].join('\n');
  }

  String controllerEmployees(int id) =>
      widget.controller.employees.where((e) => e.id == id).firstOrNull?.label ??
      'Previous employee';
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Object>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return SingleChildScrollView(
          child: EmptyState(
            title: 'History unavailable',
            message: errorMessage(snapshot.error!),
            action: TextButton(
              onPressed: () => setState(() {
                future = load();
              }),
              child: const Text('Retry'),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final entries = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.audit ? 'Audit log' : 'Transfers',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            widget.audit
                ? 'Permanent record of changes and their operator.'
                : 'Employee accountability and organizational unit movement.',
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            const EmptyState(
              title: 'No records yet',
              message: 'Recorded changes will appear here.',
              icon: Icons.history,
            ),
          ...entries.take(20).map((entry) {
            if (entry is Transfer) {
              return Card(
                child: TransferTile(
                  entry,
                  onTap: () => openAssetDetails(
                    context,
                    widget.controller,
                    entry.assetId,
                  ),
                ),
              );
            }
            final row = entry as Map<String, Object?>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ExpansionTile(
                  title: Text(row['action'] as String),
                  subtitle: Text(
                    '${row['actor']} · ${displayTime(row['recorded_at'] as String)}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedAlignment: Alignment.centerLeft,
                  children: [SelectableText(auditSummary(row))],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: offset == 0
                    ? null
                    : () => setState(() {
                        offset -= 20;
                        future = load();
                      }),
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: entries.length <= 20
                    ? null
                    : () => setState(() {
                        offset += 20;
                        future = load();
                      }),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      );
    },
  );
}
