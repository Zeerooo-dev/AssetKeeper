import 'package:assetkeeper/core/app_theme.dart';
import 'package:assetkeeper/services/github_updates.dart';
import 'package:assetkeeper/ui/widgets/update_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

final update = AppUpdate(
  '1.0.5',
  'Fixed transfers and improved navigation.',
  Uri.parse(
    'https://github.com/Zeerooo-dev/AssetKeeper/releases/download/v1.0.5/AssetKeeper-v1.0.5-android.apk',
  ),
  1024 * 1024,
);

class FakeUpdates extends GithubUpdates {
  int calls = 0;
  bool offline = false;
  @override
  bool get supported => true;
  @override
  Future<AppUpdate?> check({
    http.Client? client,
    Future<PackageInfo> Function()? installed,
  }) async {
    calls++;
    if (offline) throw StateError('offline');
    return update;
  }
}

void main() {
  testWidgets('waits for setup, offers once, and allows a manual recheck', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final updates = FakeUpdates();
    Widget app(bool ready) => MaterialApp(
      navigatorKey: key,
      builder: (_, child) => UpdatePromptHost(
        navigatorKey: key,
        ready: ready,
        updates: updates,
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => UpdatePromptHost.checkForUpdates(context),
            child: const Text('Check'),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(updates.calls, 0);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    expect(updates.calls, 1);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(updates.calls, 1);
    expect(find.text('Update available'), findsNothing);
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(updates.calls, 2);
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('defers the popup while an editor is open', (tester) async {
    final key = GlobalKey<NavigatorState>();
    final updates = FakeUpdates();
    Widget app(bool ready) => MaterialApp(
      navigatorKey: key,
      builder: (_, child) => UpdatePromptHost(
        navigatorKey: key,
        ready: ready,
        updates: updates,
        child: child!,
      ),
      home: const Scaffold(body: Text('Inventory')),
    );
    await tester.pumpWidget(app(false));
    key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Editor')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(find.text('Update available'), findsNothing);
    key.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offline startup stays usable and manual failure is explained', (
    tester,
  ) async {
    final key = GlobalKey<NavigatorState>();
    final updates = FakeUpdates()..offline = true;
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        builder: (_, child) => UpdatePromptHost(
          navigatorKey: key,
          ready: true,
          updates: updates,
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await UpdatePromptHost.checkForUpdates(context),
              child: const Text('Check'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsNothing);
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();
    expect(result, contains('Check your connection'));
    expect(tester.takeException(), isNull);
  });

  for (final theme in [AssetKeeperTheme.defaultLight, AssetKeeperTheme.dark]) {
    testWidgets(
      'small phone dialog supports large text, download failure and retry in ${theme.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        final key = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            theme: AssetKeeperThemes.build(theme),
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(),
          ),
        );
        showDialog<void>(
          context: key.currentContext!,
          builder: (_) => UpdateDialog(
            release: update,
            open: (url) async {
              expect(url, update.download);
              return ++calls > 1;
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Download update'));
        await tester.pumpAndSettle();
        expect(find.text('Update available'), findsOneWidget);
        final content = find.text('Could not open the download. Try again.');
        await tester.ensureVisible(content);
        expect(content, findsOneWidget);
        await tester.tap(find.text('Download update'));
        await tester.pumpAndSettle();
        expect(calls, 2);
        expect(find.text('Update available'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
