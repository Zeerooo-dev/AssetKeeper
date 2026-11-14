import 'package:assetkeeper/core/app_theme.dart';
import 'package:assetkeeper/ui/widgets/navigation_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in AssetKeeperTheme.values) {
    for (final highContrast in [false, true]) {
      testWidgets(
        'JANITRA navigation ${theme.name}, high contrast $highContrast',
        (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var selected = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AssetKeeperThemes.build(theme),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(320, 640),
                  highContrast: highContrast,
                ),
                child: StatefulBuilder(
                  builder: (context, update) => Scaffold(
                    body: const Text('Content'),
                    bottomNavigationBar: FloatingNavigation(
                      selected: selected,
                      onSelected: (i) => update(() => selected = i),
                      icons: const [
                        Icons.inventory_2_outlined,
                        Icons.dashboard_outlined,
                        Icons.swap_horiz,
                        Icons.more_horiz,
                      ],
                      labels: const [
                        'Assets',
                        'Dashboard',
                        'Transfers',
                        'More',
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          final rect = tester.getRect(find.byType(NavigationSurface));
          expect(rect.left, 16);
          expect(rect.right, 304);
          expect(rect.bottom, 628);
          final clip = tester.widget<ClipRRect>(
            find
                .descendant(
                  of: find.byType(NavigationSurface),
                  matching: find.byType(ClipRRect),
                )
                .first,
          );
          expect(clip.borderRadius, BorderRadius.circular(26));
          expect(
            find.byType(BackdropFilter),
            highContrast ? findsNothing : findsOneWidget,
          );
          await tester.tap(find.text('Transfers'));
          await tester.pumpAndSettle();
          expect(selected, 2);
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .labelBehavior,
            NavigationDestinationLabelBehavior.alwaysShow,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
