import 'dart:io';
import 'dart:convert';

import 'package:assetkeeper/ui/widgets/startup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget startup({
  bool reducedMotion = false,
  TargetPlatform platform = TargetPlatform.linux,
}) => MaterialApp(
  theme: ThemeData(platform: platform),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: const StartupScreen(),
  ),
);
String currentAsset(WidgetTester tester) =>
    (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

void main() {
  testWidgets(
    'Android handoff keeps a clean mark without replaying colored GIF rings',
    (tester) async {
      await tester.pumpWidget(startup(platform: TargetPlatform.android));
      expect(currentAsset(tester), 'assets/branding/mark.png');
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFF08162D));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 288);
      expect(image.height, 288);
      await tester.pump(const Duration(seconds: 4));
      expect(currentAsset(tester), 'assets/branding/mark.png');
      await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
      expect(find.text('Ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('reduced motion uses the still image immediately', (
    tester,
  ) async {
    await tester.pumpWidget(startup(reducedMotion: true));
    expect(currentAsset(tester), 'assets/branding/opening_still.jpg');
    await tester.pump(const Duration(seconds: 4));
    expect(currentAsset(tester), 'assets/branding/opening_still.jpg');
  });
  testWidgets('intro finishes once without an endless animation loop', (
    tester,
  ) async {
    await tester.pumpWidget(startup());
    expect(currentAsset(tester), 'assets/branding/opening.gif');
    await tester.pump(const Duration(milliseconds: 3331));
    expect(currentAsset(tester), 'assets/branding/opening_still.jpg');
    await tester.pump(const Duration(seconds: 5));
    expect(currentAsset(tester), 'assets/branding/opening_still.jpg');
  });
  testWidgets('readiness can dismiss the intro immediately without waiting', (
    tester,
  ) async {
    await tester.pumpWidget(startup());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const MaterialApp(home: Text('Ready')));
    expect(find.text('Ready'), findsOneWidget);
    expect(find.byType(StartupScreen), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
  test('Android resources include adaptive, themed, static and animated launch variants', () {
    const res = 'android/app/src/main/res';
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
    expect(manifest, contains('android:allowBackup="false"'));
    for (final folder in ['values-v31', 'values-night-v31']) {
      final theme = File('$res/$folder/styles.xml').readAsStringSync();
      expect(theme, contains('android:windowSplashScreenAnimatedIcon'));
      expect(theme, contains('@drawable/assetkeeper_splash_animated'));
    }
    for (final name in ['ic_launcher', 'ic_launcher_round']) {
      expect(
        File('$res/mipmap-anydpi-v26/$name.xml').readAsStringSync(),
        isNot(contains('<monochrome')),
      );
      expect(
        File('$res/mipmap-anydpi-v33/$name.xml').readAsStringSync(),
        contains('<monochrome'),
      );
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        final data = File('$res/mipmap-$density/$name.png').readAsBytesSync();
        expect(data.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      }
    }
    final animation = File('$res/drawable-v31/assetkeeper_splash_animated.xml')
        .readAsStringSync();
    expect(animation, contains('ring_rotate'));
    expect(animation, contains('mark'));
    expect(
      utf8.decode(
        File('assets/branding/opening.gif').readAsBytesSync().take(3).toList(),
      ),
      'GIF',
    );
  });
}
