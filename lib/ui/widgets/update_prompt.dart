import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/github_updates.dart';

class UpdatePromptHost extends StatefulWidget {
  const UpdatePromptHost({
    super.key,
    required this.navigatorKey,
    required this.ready,
    required this.child,
    this.updates,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final bool ready;
  final Widget child;
  final GithubUpdates? updates;

  static Future<String?> checkForUpdates(BuildContext context) async =>
      context.findAncestorStateOfType<_UpdatePromptHostState>()?.check(
        manual: true,
      ) ??
      'Update checking is unavailable.';

  @override
  State<UpdatePromptHost> createState() => _UpdatePromptHostState();
}

class _UpdatePromptHostState extends State<UpdatePromptHost>
    with WidgetsBindingObserver {
  late final updates = widget.updates ?? GithubUpdates();
  DateTime? _lastCheck;
  AppUpdate? _pending;
  String? _offeredVersion;
  Timer? _waiting;
  bool _checking = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant UpdatePromptHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) {
      _showWhenReady();
      _schedule();
    }
  }

  void _schedule() {
    if (!widget.ready || !updates.supported) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(check());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_pending != null) {
        _showWhenReady();
      } else {
        unawaited(check());
      }
    }
  }

  Future<String?> check({bool manual = false}) async {
    if (!widget.ready) return 'Finish setup before checking for updates.';
    if (!updates.supported) {
      return 'Update downloads are available for Android, Windows, and Linux.';
    }
    if (_checking || _dialogOpen) return 'An update check is already open.';
    if (!manual &&
        _lastCheck != null &&
        DateTime.now().difference(_lastCheck!) < const Duration(hours: 4)) {
      return null;
    }
    _checking = true;
    _lastCheck = DateTime.now();
    try {
      final release = await updates.check();
      if (!mounted || !widget.ready) return null;
      if (release == null) return manual ? 'AssetKeeper is up to date.' : null;
      if (manual || release.version != _offeredVersion) {
        _pending = release;
        _showWhenReady();
      }
      return null;
    } catch (_) {
      // Offline work must never depend on GitHub being reachable.
      return manual
          ? 'Could not check for updates. Check your connection and try again.'
          : null;
    } finally {
      _checking = false;
    }
  }

  void _showWhenReady() {
    _waiting?.cancel();
    if (!mounted || !widget.ready || _pending == null || _dialogOpen) return;
    final navigator = widget.navigatorKey.currentState;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if (navigator == null || navigator.canPop()) {
      _waiting = Timer(const Duration(seconds: 2), _showWhenReady);
      return;
    }
    final release = _pending!;
    _pending = null;
    _offeredVersion = release.version;
    _dialogOpen = true;
    unawaited(
      showDialog<void>(
        context: navigator.overlay!.context,
        builder: (_) => UpdateDialog(release: release),
      ).whenComplete(() => _dialogOpen = false),
    );
  }

  @override
  void dispose() {
    _waiting?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.release, this.open});
  final AppUpdate release;
  final Future<bool> Function(Uri)? open;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final opened =
          await (widget.open?.call(widget.release.download) ??
              launchUrl(
                widget.release.download,
                mode: LaunchMode.externalApplication,
              ));
      if (!opened) throw StateError('Could not open browser');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the download. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    constraints: const BoxConstraints(maxWidth: 480),
    title: const Text('Update available'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AssetKeeper ${widget.release.version}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${(widget.release.size / (1024 * 1024)).toStringAsFixed(1)} MB · GitHub release',
            ),
            const SizedBox(height: 16),
            Text('What’s new', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              widget.release.notes.isEmpty
                  ? 'A new version of AssetKeeper is ready.'
                  : widget.release.notes,
            ),
            const SizedBox(height: 16),
            const Text(
              'Download opens in your browser. Install the Android update when prompted. On PC, close AssetKeeper and replace the application folder with the extracted download. Keep your device’s saved data and keys.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('Later'),
      ),
      FilledButton.icon(
        onPressed: _busy ? null : _download,
        icon: const Icon(Icons.system_update_alt),
        label: Text(_busy ? 'Opening download…' : 'Download update'),
      ),
    ],
  );
}
