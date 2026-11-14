import 'package:flutter/material.dart';

import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/assetkeeper_controller.dart';
import '../widgets/common.dart';
import 'asset_editor.dart';
import 'transfer_page.dart';

Future<void> openAssetDetails(
  BuildContext context,
  AssetKeeperController controller,
  int id,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AssetDetailsPage(controller: controller, id: id),
  ),
);

class AssetDetailsPage extends StatefulWidget {
  const AssetDetailsPage({
    super.key,
    required this.controller,
    required this.id,
  });
  final AssetKeeperController controller;
  final int id;
  @override
  State<AssetDetailsPage> createState() => _AssetDetailsPageState();
}

class _AssetDetailsPageState extends State<AssetDetailsPage> {
  late Future<Asset?> future = widget.controller.database.findAsset(widget.id);
  void reload() => setState(() {
    future = widget.controller.database.findAsset(widget.id);
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Asset details')),
    body: SafeArea(
      child: FutureBuilder<Asset?>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              title: 'Could not load asset',
              message: errorMessage(snapshot.error!),
              action: TextButton(onPressed: reload, child: const Text('Retry')),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data == null) {
            return const EmptyState(
              title: 'Asset unavailable',
              message: 'This record no longer exists.',
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: AssetDetails(
                  asset: snapshot.data!,
                  controller: widget.controller,
                  onChanged: reload,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class AssetDetails extends StatefulWidget {
  const AssetDetails({
    super.key,
    required this.asset,
    required this.controller,
    required this.onChanged,
  });
  final Asset asset;
  final AssetKeeperController controller;
  final VoidCallback onChanged;
  @override
  State<AssetDetails> createState() => _AssetDetailsState();
}

class _AssetDetailsState extends State<AssetDetails> {
  late Future<List<Transfer>> history = widget.controller.database.transfers(
    assetId: widget.asset.id,
    limit: 5,
  );
  @override
  void didUpdateWidget(AssetDetails old) {
    super.didUpdateWidget(old);
    if (old.asset.version != widget.asset.version ||
        old.asset.id != widget.asset.id) {
      history = widget.controller.database.transfers(
        assetId: widget.asset.id,
        limit: 5,
      );
    }
  }

  Widget field(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Asset details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  a.category.toLowerCase() == 'furniture'
                      ? Icons.chair_outlined
                      : Icons.computer_outlined,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(a.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            StatusLabel(a.status),
            if (a.archived)
              const Text(
                'Archived',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            field('Property number', a.property),
            field('Accountable employee', '${a.employee} · ${a.employeeCode}'),
            field('Branch location', a.branch),
            field('Category', a.category),
            field(
              'Serial number',
              a.serial.isEmpty ? 'Not applicable' : a.serial,
            ),
            field('Acquisition price', money(a.price)),
            field('Acquisition date', displayDate(a.acquired)),
            if (a.unit.isNotEmpty) field('Current organizational unit', a.unit),
            if (a.destination.isNotEmpty)
              field('Destination unit', a.destination),
            field(
              'Description',
              a.description.isEmpty
                  ? 'No description provided.'
                  : a.description,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Recent transfer history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            FutureBuilder<List<Transfer>>(
              future: history,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      Text(errorMessage(snapshot.error!)),
                      TextButton(
                        onPressed: () => setState(() {
                          history = widget.controller.database.transfers(
                            assetId: a.id,
                            limit: 5,
                          );
                        }),
                        child: const Text('Retry history'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }
                if (snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('No transfers recorded.'),
                  );
                }
                return Column(
                  children: [
                    for (final t in snapshot.data!)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.employeeTransfer
                                    ? 'Employee accountability'
                                    : 'Unit transfer',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              Text('${t.from} → ${t.to}'),
                              Text(displayDate(t.date)),
                              Text('Recorded by ${t.actor}'),
                              if (t.remarks.isNotEmpty) Text(t.remarks),
                            ],
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssetHistoryPage(
                            controller: widget.controller,
                            asset: a,
                          ),
                        ),
                      ),
                      child: const Text('View complete history'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            if (!a.archived)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final id = await editAsset(
                        context,
                        widget.controller,
                        asset: a,
                      );
                      if (id != null) widget.onChanged();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      final changed = await transferAsset(
                        context,
                        widget.controller,
                        a,
                      );
                      if (changed == true) widget.onChanged();
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Transfer'),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SaveButton(
                label: a.archived ? 'Restore asset' : 'Archive asset',
                icon: a.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
                onSave: () async {
                  if (!await confirm(
                    context,
                    title: a.archived ? 'Restore asset?' : 'Archive asset?',
                    description: a.archived
                        ? 'Return this asset to the active inventory.'
                        : 'Remove this asset from current inventory totals? Its property number and complete history will be retained.',
                    action: a.archived ? 'Restore' : 'Archive',
                  )) {
                    return;
                  }
                  await widget.controller.database.archive(a, !a.archived);
                  await widget.controller.refresh();
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AssetHistoryPage extends StatefulWidget {
  const AssetHistoryPage({
    super.key,
    required this.controller,
    required this.asset,
  });
  final AssetKeeperController controller;
  final Asset asset;
  @override
  State<AssetHistoryPage> createState() => _AssetHistoryPageState();
}

class _AssetHistoryPageState extends State<AssetHistoryPage> {
  int offset = 0;
  late Future<List<Transfer>> future = load();
  Future<List<Transfer>> load() => widget.controller.database.transfers(
    assetId: widget.asset.id,
    limit: 21,
    offset: offset,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete transfer history')),
    body: FutureBuilder<List<Transfer>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            title: 'History unavailable',
            message: errorMessage(snapshot.error!),
            action: TextButton(
              onPressed: () => setState(() {
                future = load();
              }),
              child: const Text('Retry'),
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
              widget.asset.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (entries.isEmpty)
              const EmptyState(
                title: 'No transfers recorded',
                message: 'Future accountability and unit transfers will appear here.',
              ),
            ...entries.take(20).map((t) => TransferTile(t)),
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
    ),
  );
}
