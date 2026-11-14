# AssetKeeper — Android Icon & Splash Animation Kit

AssetKeeper: Equipment & Furniture Inventory and Accountability.

## Included artwork

- `assetkeeper_icon_preview.png`: side-by-side previews (Android adaptive, circle, black/white Nothing style).
- `assetkeeper_icon_1024.png`: flat full-color square preview.
- `assetkeeper_foreground_1024.png`, `assetkeeper_background_1024.png`, `assetkeeper_monochrome_1024.png`: separate adaptive layers.
- `svg/`: vector master artwork; source of all rendered icon assets.
- `AssetKeeper_Opening_Animation.mp4` and `.gif`: 3.3-second branded animation preview inspired by the attached reference video.
- `android/app/src/main/res/`: adaptive icon, themed/monochrome layer, legacy densities, and a native animated splash vector and animators.
- `concept_render.png`: initial visual concept (not the shape-safe production icon).

## Integration — Android or Flutter

1. Back up your existing icon resources.
2. Merge this kit's `android/app/src/main/res/` directory into the Android module at the same path. Do not replace other app resources.
3. Ensure `<application android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round" ...>` in `AndroidManifest.xml`.
4. Keep Android's automatic home-screen masking; do not pre-mask the adaptive foreground PNG. It is centered inside the 108dp canvas, within the 66dp safe region.
5. `mipmap-anydpi-v26/ic_launcher.xml` includes foreground/background plus `<monochrome>` for Android 13+ themed launchers. Monochrome support makes the icon compatible with system-powered themes; behavior of Nothing Launcher / Nothing Icon Pack varies by version and user settings.

## Native Android splash animation

The kit includes `drawable-v31/assetkeeper_splash_animated.xml` with two animated vector targets. This is intended for Android 12+ splash screens. Pre-Android-12 variants fall back to the static `drawable/assetkeeper_splash_animated.xml`.

For Kotlin/Java apps using `androidx.core:core-splashscreen`, define in the existing `styles.xml`:

```xml
<style name="Theme.AssetKeeper.Starting" parent="Theme.SplashScreen">
    <item name="windowSplashScreenBackground">@color/assetkeeper_splash_background</item>
    <item name="windowSplashScreenAnimatedIcon">@drawable/assetkeeper_splash_animated</item>
    <item name="windowSplashScreenAnimationDuration">900</item>
    <item name="postSplashScreenTheme">@style/Theme.YourExistingAppTheme</item>
</style>
```

Replace `Theme.YourExistingAppTheme` with your current app theme, assign `Theme.AssetKeeper.Starting` to the launching activity in AndroidManifest, then call `installSplashScreen()` before `super.onCreate()` per AndroidX docs. The native splash animation is approximately 0.9 s and does NOT display the full 3.3 s MP4.

### Flutter consideration

If the original Smart-Stock or AssetKeeper project is Flutter, native Android icon resources can be used directly. The **3.3-second branded in-app intro** should be recreated with Flutter animation widgets/Rive/Lottie after the Android system splash (rather than embedding the supplied MP4 as the Android splash icon). Android's system splash expects vector/animated-vector drawables and dismisses when the first frame is ready. Avoid artificial launch delays solely to watch an animation. Respect reduced-motion settings.

## Notes

- This is an artwork and sample-resource kit, **not an APK** and not yet integrated into the actual AssetKeeper project.
- Adaptive/themed icons have been generated following the 108 dp, 66 dp central safe zone guidance.
- The XML assets and animation have been prepared, but have **not** been compiled on a real Android device in this session; test via Android Studio / device before release.
- Generated PNGs are high-resolution. SVG source files are the masters for future variations.
- Original palette: ink `#08162D`, cyan `#1CE2DB`, mint `#45E8EC`, lime `#B7FE45`.

References: https://developer.android.com/develop/ui/compose/system/icon_design_adaptive and https://developer.android.com/develop/ui/views/launch/splash-screen
