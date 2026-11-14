import 'package:flutter/material.dart';

import '../data/database_service.dart';
import '../state/assetkeeper_controller.dart';
import 'pages/inventory_page.dart';
import 'pages/overview_pages.dart';
import 'pages/records_page.dart';
import 'pages/settings_page.dart';
import 'widgets/navigation_surface.dart';

IconData sectionIcon(AppSection section) => switch (section) {
  AppSection.assets => Icons.inventory_2_outlined,
  AppSection.dashboard => Icons.dashboard_outlined,
  AppSection.employees => Icons.people_outline,
  AppSection.transfers => Icons.swap_horiz,
  AppSection.branches => Icons.business_outlined,
  AppSection.categories => Icons.category_outlined,
  AppSection.audit => Icons.history,
  AppSection.settings => Icons.settings_outlined,
};

class AssetKeeperShell extends StatefulWidget {
  const AssetKeeperShell({super.key, required this.controller});
  final AssetKeeperController controller;
  @override
  State<AssetKeeperShell> createState() => _AssetKeeperShellState();
}

class _AssetKeeperShellState extends State<AssetKeeperShell>
    with WidgetsBindingObserver {
  String? error;
  bool refreshing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    if (refreshing || !widget.controller.database.isOpen) return;
    setState(() {
      refreshing = true;
      error = null;
    });
    try {
      await widget.controller.refresh();
    } catch (e) {
      if (mounted) setState(() => error = errorMessage(e));
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  void navigate(AppSection section) {
    FocusManager.instance.primaryFocus?.unfocus();
    widget.controller.navigate(section);
    refresh();
  }

  Future<void> more() async {
    final selected = await showModalBottomSheet<AppSection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final section in [
              AppSection.employees,
              AppSection.branches,
              AppSection.categories,
              AppSection.audit,
              AppSection.settings,
            ])
              ListTile(
                leading: Icon(sectionIcon(section)),
                title: Text(section.label),
                onTap: () => Navigator.pop(context, section),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) navigate(selected);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final controller = widget.controller;
      final rail =
          box.maxWidth >= 760 &&
          box.maxHeight >= 500 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.6;
      final primary = [
        AppSection.assets,
        AppSection.dashboard,
        AppSection.transfers,
      ];
      final current = primary.indexOf(controller.section);
      final page = switch (controller.section) {
        AppSection.assets => InventoryPage(controller: controller),
        AppSection.dashboard => DashboardPage(controller: controller),
        AppSection.employees ||
        AppSection.branches ||
        AppSection.categories => RecordsPage(
          key: ValueKey(controller.section),
          controller: controller,
          section: controller.section,
        ),
        AppSection.transfers => HistoryPage(
          key: const ValueKey('transfers'),
          controller: controller,
        ),
        AppSection.audit => HistoryPage(
          key: const ValueKey('audit'),
          controller: controller,
          audit: true,
        ),
        AppSection.settings => SettingsPage(controller: controller),
      };
      final content = Column(
        children: [
          if (refreshing)
            const LinearProgressIndicator(semanticsLabel: 'Refreshing records'),
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(onPressed: refresh, child: const Text('Retry')),
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(child: page),
        ],
      );
      return PopScope(
        canPop: controller.section == AppSection.assets,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) navigate(AppSection.assets);
        },
        child: Scaffold(
          appBar: rail
              ? null
              : AppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  surfaceTintColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  title: const Text('AssetKeeper'),
                  actions: [
                    IconButton(
                      tooltip: 'Refresh records',
                      onPressed: refreshing ? null : refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
          body: SafeArea(
            child: rail
                ? Row(
                    children: [
                      SizedBox(
                        width: box.maxWidth >= 1200 ? 210 : 180,
                        child: Material(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'AssetKeeper',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              for (final section in AppSection.values)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  child: ListTile(
                                    selected: controller.section == section,
                                    selectedColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    selectedTileColor: Color.alphaBlend(
                                      Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: .08),
                                      Theme.of(context).scaffoldBackgroundColor,
                                    ),
                                    leading: Icon(sectionIcon(section)),
                                    title: Text(section.label),
                                    onTap: () => navigate(section),
                                  ),
                                ),
                              const Divider(),
                              ListTile(
                                leading: const Icon(Icons.refresh),
                                title: const Text('Refresh'),
                                onTap: refreshing ? null : refresh,
                              ),
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  controller.operatorName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
          bottomNavigationBar: rail
              ? null
              : FloatingNavigation(
                  selected: current < 0 ? 3 : current,
                  onSelected: (i) => i == 3 ? more() : navigate(primary[i]),
                  icons: [...primary.map(sectionIcon), Icons.more_horiz],
                  labels: [...primary.map((section) => section.label), 'More'],
                ),
        ),
      );
    },
  );
}
