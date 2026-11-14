import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'data/database_service.dart';
import 'platform/database_factory.dart';
import 'platform/window_control.dart';
import 'state/assetkeeper_controller.dart';
import 'ui/assetkeeper_shell.dart';
import 'ui/pages/settings_page.dart';
import 'ui/widgets/startup_screen.dart';
import 'ui/widgets/update_prompt.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDesktopWindow();
  final info = await createAssetKeeperDatabaseFactory(
    sandbox: args.contains('--test'),
  );
  final controller = AssetKeeperController(
    DatabaseService(info.factory, info.path, protectAtRest: !kIsWeb),
  );
  runApp(AssetKeeperApp(controller: controller));
  await installDesktopCloseHandler(() async {
    try {
      await controller.closeDatabase();
      return true;
    } catch (_) {
      return false;
    }
  });
  unawaited(controller.initialize());
}

class AssetKeeperApp extends StatefulWidget {
  const AssetKeeperApp({super.key, required this.controller});
  final AssetKeeperController controller;
  @override
  State<AssetKeeperApp> createState() => _AssetKeeperAppState();
}

class _AssetKeeperAppState extends State<AssetKeeperApp>
    with WidgetsBindingObserver {
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(
        widget.controller.database.close().catchError((Object error) {
          debugPrint('Database close failed: $error');
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final Widget home;
      if (c.loading) {
        home = const StartupScreen();
      } else if (c.error != null || c.closed) {
        home = Scaffold(
          appBar: AppBar(title: const Text('AssetKeeper')),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.closed ? Icons.lock_outline : Icons.error_outline,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        c.closed
                            ? 'Database closed'
                            : 'Could not open AssetKeeper',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        c.error ?? 'Your saved records remain on this device.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: c.initialize,
                        child: Text(c.closed ? 'Reopen database' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (c.operatorName.isEmpty) {
        home = Scaffold(
          appBar: AppBar(title: const Text('AssetKeeper')),
          body: SafeArea(child: SettingsPage(controller: c, firstRun: true)),
        );
      } else {
        home = AssetKeeperShell(controller: c);
      }
      return MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => UpdatePromptHost(
          navigatorKey: navigatorKey,
          ready:
              !c.loading &&
              !c.closed &&
              c.error == null &&
              c.operatorName.isNotEmpty,
          child: child!,
        ),
        title: 'AssetKeeper',
        debugShowCheckedModeBanner: false,
        theme: AssetKeeperThemes.build(c.theme),
        home: home,
      );
    },
  );
}
