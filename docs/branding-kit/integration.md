# Android icon and startup kit integration

Version 1.0.2+3, November 15, 2026.

The user's request authorized applying the supplied icon/animation kit. The kit's
README was treated as reference material. Its generic Kotlin/AndroidX instructions
were adapted to AssetKeeper's existing Flutter launch themes; no scripts from the
archive were executed and no new playback or splash dependencies were added.

## Applied

- Original PNG launcher resources at mdpi through xxxhdpi, including round icons.
- Separate adaptive layers on Android 8+; monochrome is isolated to the Android
  13+ resource qualifier so older Android versions receive their usual two layers.
- Manifest roundIcon entry; existing package ID and allowBackup=false retained.
- Static legacy splash vector on the kit's background in light and dark themes.
- Android 12+ native animated-vector splash, with explicit float-valued ring and
  mark animators. The OS determines how long the splash is visible.
- Existing Flutter loading state now uses the supplied GIF and still artwork.
  It never delays application readiness. GIF playback ends after one 3.33-second
  pass; a slow load retains the still, and reduced motion starts with the still.
- Original SVG masters retained for future icon maintenance. Concept render and
  MP4 are reference artwork, not runtime app dependencies. Desktop launcher icons
  and the inventory design were not changed by this Android kit integration.

## Checks

The startup tests cover reduced motion, finite playback, early readiness dismissal,
and Android launcher/splash resource references. The normal regression suite and
Android resource compiler are also run for this build. Native splash timing,
launcher masking and themed-icon behavior still require device/launcher acceptance.

## References

- https://docs.flutter.dev/platform-integration/android/splash-screen
- https://developer.android.com/develop/ui/views/launch/splash-screen

## Android handoff fix, 1.0.3+4

The supplied qwe.mp4 recording showed the native cyan/lime splash followed by
the faint pink/lime/cyan rings from the opening GIF's first frames. The second
intro looked like leftover color after the first animation ended. Frame inspection
confirmed the colors match the GIF, rather than the native vector's final frame.

Android now continues with the supplied transparent mark on the same #08162D
background. It does not start the GIF or a second timer. Android 12+ removes its
splash overlay directly at the OS exit callback, following Flutter's documented
handoff. The system animation and launcher artwork are preserved. Other platforms
retain their intro. The new widget regression checks Android's image, background,
size, stable loading state and readiness dismissal. No connected phone was available
for a repeat physical-device recording.
