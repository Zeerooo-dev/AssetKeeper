import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool get _nativeHandoff =>
      !kIsWeb && Theme.of(context).platform == TargetPlatform.android;
  Timer? _finish;
  bool _playing = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nativeHandoff || MediaQuery.disableAnimationsOf(context)) {
      _finish?.cancel();
      _playing = false;
    } else if (_playing && _finish == null) {
      // Finish the supplied intro once; readiness can dismiss this screen earlier.
      _finish = Timer(const Duration(milliseconds: 3330), () {
        if (mounted) setState(() => _playing = false);
      });
    }
  }

  @override
  void dispose() {
    _finish?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _nativeHandoff
        ? const Color(0xFF08162D)
        : const Color(0xFF080E17),
    body: SafeArea(
      top: !_nativeHandoff,
      bottom: !_nativeHandoff,
      child: Semantics(
        label: 'AssetKeeper. Opening application.',
        liveRegion: true,
        child: Center(
          child: Image.asset(
            _nativeHandoff
                ? 'assets/branding/mark.png'
                : _playing
                ? 'assets/branding/opening.gif'
                : 'assets/branding/opening_still.jpg',
            key: ValueKey(
              _nativeHandoff ? 'native-handoff' : 'intro-$_playing',
            ),
            width: _nativeHandoff ? 288 : null,
            height: _nativeHandoff ? 288 : null,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stack) => const Text(
              'AssetKeeper\nOpening application…',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    ),
  );
}
