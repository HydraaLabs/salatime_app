# Android tablets

The application adapts to the available window, including split-screen:

- At least 600 logical pixels wide and 480 high: navigation rail with a Home destination.
- Smaller windows: existing phone bottom navigation.
- Home content at least 840 logical pixels wide: prayers and daily content in two columns, capped at 1400 pixels.
- Visited page state survives transitions between the two navigation layouts.
- Both tablet panes share a status-bar inset so tab headers cannot obscure the clock above the rail.
- MainActivity explicitly allows resizing; no orientation lock is applied.

## Validation

`flutter test test/view/home_return_navigation_test.dart test/view/prayer_dashboard_neighbors_test.dart`
checks navigation, resize/state retention (1280×800, 390×844, 800×350, 800×1280), and prayer boundaries.

The capture scenario uses the real Flutter screens, bundled Quran, live hadith CDN,
and optionally live OpenStreetMap/Overpass data, in French, English and Arabic.
It clears app preferences and must run on a disposable emulator only.

Profiles: Android 15/API 35, 1600×2560 at 320 dpi (800×1280 logical pixels),
and 1200×1920 at 320 dpi (600×960 logical pixels). These are emulated 10-inch
and 7-inch layouts, not physical-device certification.

```bash
python3 scripts/collect_android_store_captures.py \
  --serial emulator-5554 --output /tmp/tablet-native
adb -s emulator-5554 reverse tcp:8879 tcp:8879
adb -s emulator-5554 emu geo fix -5.0003 34.0331
flutter test integration_test/play_style_app_store_test.dart \
  -d emulator-5554 --dart-define=SALATIME_CAPTURE_PORT=8879 \
  --dart-define=SALATIME_CAPTURE_SKIP_MAP=true
```

## Store artwork

`play-store/localized/{fr-FR,en-US,ar}/tablet-{7-inch,10-inch}-screenshots/`
contains adaptations of the existing mobile marketing artwork. Original raster
headlines and decoration are retained; authentic tablet screenshots replace the
phone interface without stretching. The removed name generator is excluded. The map is also omitted from this batch:
all three public Overpass endpoints failed (504, timeout, DNS failure). Five
verified screens per language/profile remain, for 30 branded images.
`scripts/adapt_play_screenshots.py` supports `android7` and `android10`.

Output canvases are 1080×1920 and 1440×2560 RGB PNG. Native captures and SHA-256
composition provenance live in `release-artifacts/android-tablets-2026-09-19/`.

Google's [preview asset guidelines](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en-GB)
recommend at least four large-screen images, 9:16 portrait/16:9 landscape,
and favor the app interface without additional marketing text on large screens.
The raw captures are retained alongside the user-requested branded versions.

The original capture session did not upload assets or publish a release. These
assets are included in the authorized Android 1.0.25 (29) publication. Release
receipts and API readback are retained in `release-artifacts/release-1.0.25/`.
Shared iOS behavior is described in [Shared iOS and tablet changes](shared-ios-tablet-changes.md).

The Linux emulator required `-gpu host`: SwiftShader crashed the emulator process
during route changes. No app production renderer setting was changed.
