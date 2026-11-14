import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> initializeDesktopWindow() async {
  if (!_isDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1100, 700),
    minimumSize: Size(600, 500),
    center: true,
    title: 'AssetKeeper Inventory System',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> installDesktopCloseHandler(Future<bool> Function() close) async {
  if (!_isDesktop) return;
  await windowManager.setPreventClose(true);
  windowManager.addListener(_CloseHandler(close));
}

class _CloseHandler extends WindowListener {
  _CloseHandler(this.close);
  final Future<bool> Function() close;
  bool busy = false;
  @override
  void onWindowClose() async {
    if (busy) return;
    busy = true;
    try {
      if (await close()) await windowManager.destroy();
    } finally {
      busy = false;
    }
  }
}
