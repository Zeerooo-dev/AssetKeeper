import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/database_service.dart';
import '../../models/models.dart';
import '../../state/assetkeeper_controller.dart';
import '../widgets/common.dart';
import 'asset_details.dart';
import 'asset_editor.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.controller});
  final AssetKeeperController controller;
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final search = TextEditingController(
    text: widget.controller.inventoryQuery.search,
  );
  Timer? debounce;
  List<Asset> assets = [];
  Asset? selected;
  bool loading = true, filtersOpen = false;
  String? error;
  int page = 0, request = 0;
  late int revision = widget.controller.revision;
  InventoryQuery get query => widget.controller.inventoryQuery;
  @override
  void initState() {
    super.initState();
    filtersOpen = query.employeeId != null;
    load();
  }

  @override
  void didUpdateWidget(InventoryPage old) {
    super.didUpdateWidget(old);
    if (revision != widget.controller.revision) {
      revision = widget.controller.revision;
      load();
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final current = ++request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      // shortcut: filter results are loaded locally; use SQL count/paging for inventories that outgrow device memory.
      final values = await widget.controller.database.assets(query: query);
      final selection = selected == null
          ? null
          : await widget.controller.database.findAsset(selected!.id);
      if (mounted && current == request) {
        setState(() {
          assets = values;
          selected = selection;
          page = page.clamp(0, values.isEmpty ? 0 : (values.length - 1) ~/ 20);
        });
      }
    } catch (e) {
      if (mounted && current == request) {
        setState(() => error = errorMessage(e));
      }
    } finally {
      if (mounted && current == request) setState(() => loading = false);
    }
  }

  Future<void> add() async {
    if (widget.controller.employees.isEmpty ||
        widget.controller.categories.isEmpty ||
        widget.controller.branches.isEmpty) {
      if (widget.controller.employees.isEmpty) {
        widget.controller.navigate(AppSection.employees);
        message(context, 'Add an employee before registering their assets.');
      } else {
        widget.controller.navigate(
          widget.controller.branches.isEmpty
              ? AppSection.branches
              : AppSection.categories,
        );
        message(
          context,
          'Add a branch and category before registering assets.',
        );
      }
      return;
    }
    final id = await editAsset(context, widget.controller);
    if (id != null && mounted) {
      selected = await widget.controller.database.findAsset(id);
      await load();
      if (mounted) message(context, 'Asset registered.');
    }
  }

  Widget filter(
    String label,
    List<Reference> entries,
    int? value,
    ValueChanged<int?> change,
  ) => DropdownButtonFormField<int>(
    key: ValueKey('$label-$value-${entries.length}'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<int>(value: null, child: Text('All')),
      ...entries.map(
        (e) => DropdownMenuItem(
          value: e.id,
          child: Text(
            e is Employee ? e.label : e.name,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ],
    onChanged: (v) {
      change(v);
      page = 0;
      load();
    },
  );
  Widget row(Asset a, bool wide) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: selected?.id == a.id && wide
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: scheme.primary, width: 2),
              )
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            if (wide) {
              setState(() => selected = a);
            } else {
              await openAssetDetails(context, widget.controller, a.id);
              if (mounted) load();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            a.name
                                .trim()
                                .split(RegExp(r'\s+'))
                                .take(2)
                                .map((word) => word.characters.first)
                                .join()
                                .toUpperCase(),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            a.property,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  alignment: WrapAlignment.spaceBetween,
                  children: [StatusLabel(a.status), Text(money(a.price))],
                ),
                const SizedBox(height: 6),
                Text(a.employee),
                Text(
                  '${a.category} · ${a.branch}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (a.archived) const Text('Archived'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 800 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.5;
      final content = RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assets',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Text('Equipment & furniture inventory'),
                  ],
                ),
                FilledButton.icon(
                  onPressed: add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add asset'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: search,
              decoration: InputDecoration(
                labelText: 'Search assets',
                hintText: 'Name, property no. or serial no.',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    debounce?.cancel();
                    search.clear();
                    query.search = '';
                    page = 0;
                    load();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 200), () {
                  query.search = v;
                  page = 0;
                  load();
                });
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => filtersOpen = !filtersOpen),
              icon: Icon(filtersOpen ? Icons.expand_less : Icons.tune),
              label: Text(
                'Filter and sort · ${query.status.isEmpty ? 'All assets' : query.status}',
              ),
            ),
            if (filtersOpen) ...[
              const SizedBox(height: 16),
              filter(
                'Category',
                widget.controller.categories,
                query.categoryId,
                (v) => query.categoryId = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('status-${query.status}'),
                initialValue: query.status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['', ...assetStatuses]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.isEmpty ? 'All statuses' : s,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  query.status = v!;
                  page = 0;
                  load();
                },
              ),
              const SizedBox(height: 12),
              filter(
                'Branch',
                widget.controller.branches,
                query.branchId,
                (v) => query.branchId = v,
              ),
              const SizedBox(height: 12),
              filter(
                'Accountable employee',
                widget.controller.employees,
                query.employeeId,
                (v) => query.employeeId = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('sort-${query.sort}'),
                initialValue: query.sort,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items:
                    [
                          'Name',
                          'Acquisition value',
                          'Acquisition date',
                          'Property number',
                        ]
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (v) {
                  query.sort = v!;
                  page = 0;
                  load();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Archived assets'),
                value: query.archived,
                onChanged: (v) {
                  query.archived = v;
                  page = 0;
                  load();
                },
              ),
              TextButton(
                onPressed: () {
                  query.clear();
                  search.clear();
                  page = 0;
                  load();
                },
                child: const Text('Clear filters'),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in ['', 'Active', 'Obsolete'])
                  ChoiceChip(
                    label: Text(value.isEmpty ? 'All assets' : value),
                    selected: query.status == value,
                    showCheckmark: false,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: query.status == value
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    onSelected: (_) {
                      query.status = value;
                      page = 0;
                      load();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator(semanticsLabel: 'Loading assets'),
            if (error != null)
              EmptyState(
                title: 'Inventory unavailable',
                message: error!,
                action: TextButton(onPressed: load, child: const Text('Retry')),
              )
            else if (!loading && assets.isEmpty)
              EmptyState(
                title:
                    query.search.isNotEmpty ||
                        query.status.isNotEmpty ||
                        query.employeeId != null ||
                        query.branchId != null ||
                        query.categoryId != null
                    ? 'No matching assets'
                    : query.archived
                    ? 'No archived assets'
                    : 'No assets yet',
                message: 'Add an asset or adjust the search and filters. Each physical item gets its own record.',
              )
            else ...[
              Text(
                '${assets.length} assets',
                semanticsLabel: '${assets.length} matching assets',
              ),
              const SizedBox(height: 12),
              ...assets.skip(page * 20).take(20).map((a) => row(a, wide)),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  TextButton(
                    onPressed: page == 0 ? null : () => setState(() => page--),
                    child: const Text('Previous'),
                  ),
                  Text(
                    'Page ${page + 1} of ${((assets.length + 19) ~/ 20).clamp(1, 1000000000)}',
                  ),
                  TextButton(
                    onPressed: (page + 1) * 20 >= assets.length
                        ? null
                        : () => setState(() => page++),
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      );
      if (!wide) return content;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: content),
          SizedBox(
            width: 360,
            child: selected == null
                ? const Center(
                    child: EmptyState(
                      title: 'Asset details',
                      message: 'Select an asset to view its accountability, condition, and history.',
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 16, 24),
                    child: AssetDetails(
                      asset: selected!,
                      controller: widget.controller,
                      onChanged: load,
                    ),
                  ),
          ),
        ],
      );
    },
  );
}
