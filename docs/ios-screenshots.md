# App Store screenshots

Run the manual **iOS App Store screenshots** GitHub Actions workflow. It captures
the real Flutter application screens on separate iPhone Pro Max and 13-inch iPad
simulators using Xcode 26.3 and Flutter 3.41.8. It requires no Apple credentials.
The `family` input selects both devices by default, or a targeted iPhone/iPad
retry. Simulator startup has a five-minute deadline and one clean restart.

The optional `collection=play-style` input captures seven features in `fr-FR`,
`en-US` and `ar` during one application launch per device family. The default
`basic` collection and its original three-screen harness remain available.
The extended artifacts contain `<locale>/<feature>.png`:

| Feature filename | Actual application state |
| --- | --- |
| `01-prayer-times` | Light home screen, real Fès prayer calculation |
| `02-home-reading` | Dark home, scrolled to daily hadith and fresh local reading progress |
| `03-quran-list` | Bundled 114-surah list, selected through its normal tab |
| `04-quran-reading` | Bundled Al-Fatiha; iPad uses the ordinary reader setting of 40, within the existing slider range |
| `05-nearby-mosques` | Real Overpass results and OSM tiles for the simulator location set to public Fès coordinates |
| `06-hadith-chapters` | Real Bukhari CDN editions for the selected language |
| `07-name-generator` | Initial preference form, with no AI request or consent submitted |

The host grants the disposable simulator while-in-use location permission after
installation and sets its native location service to Fès. No location plugin or
network response is mocked. The map must contain actual results; loading or
network failures fail collection. Local features and Bukhari are captured before
the maps so their originals remain available if Overpass is unavailable. Every
map still requires visual review to ensure its actual OSM tiles loaded.
This extended run does not modify production source or existing App Store assets.

The integration entrypoint saves a French/light-theme/manual-Fès setup in the
fresh simulator. Prayer times are calculated by the production local calculator
for the current date and actual Fès coordinates (34.0331, -5.0003). Quran
Al-Fatiha and Athkar come from the application's bundled content. The screens,
translations and navigation shell are production widgets. The entrypoint skips
onboarding and alarm scheduling; it creates no account and changes no server
data. Sentry is disabled.

The driver announces each ready screen, then leaves it visible for ten seconds.
`scripts/capture_ios.py` immediately runs `xcrun simctl io screenshot` to capture
the original simulator pixels, including the active UIScene and status bar.
Images are not resized, composited or replaced with rendered mockups.
The extended harness renders thirty frames before announcing a screen, so nested
theme/text transitions complete. Its dark reading title must match the theme's
inherited text color. Two tests in
`test/integration_support/capture_frames_test.dart` cover this timing with and
without the application-style overlay; no product theme change was necessary.

Artifacts **SalaTime-App-Store-iphone** and **SalaTime-App-Store-ipad** contain:

- `01-prayer-times.png`
- `02-quran-al-fatiha.png`
- `03-athkar.png`
- A SHA-256/dimensions/provenance manifest and the capture log.

The collector rejects unsupported dimensions or a failed integration run.
Review every PNG visually before uploading: successful collection alone does not
establish that a screenshot is free of a system dialog or unexpected layout.
The screenshot job is separate from release signing/submission and does not
replace a physical-iPhone functionality check.

## Verified captures — 17 September 2026

All six final images were opened individually and checked for loading errors,
permission dialogs and visible overflow. Quran reading state was initialized and
its reading control was active. The original PNG hashes and dimensions matched
their manifests; each integration capture returned exit code zero.

| Device | Capture source | Original dimensions |
| --- | --- | --- |
| iPhone Pro Max | [Run 35164407561](https://github.com/HydraaLabs/salatime_app/actions/runs/35164407561), successful job `105022145821` | 1320×2868, three images |
| iPad Pro 13-inch | [Run 35163576197](https://github.com/HydraaLabs/salatime_app/actions/runs/35163576197), successful job `105019574370` | 2064×2752, three images |

The latter run was cancelled only after its iPad job and artifact upload had
succeeded, to stop its separate iPhone simulator from hanging during startup.
The iPhone-only retry above supplied the final iPhone images. Both sets display
French UI, actual Fès prayer calculations, and bundled Arabic Quran/Athkar.
Original simulator PNGs retain their native alpha channel; any App Store upload
copy must verify the channel is fully opaque before removing it, preserving the
RGB pixels and keeping the originals unchanged.

### Seven features in three languages

[Run 35168462494](https://github.com/HydraaLabs/salatime_app/actions/runs/35168462494)
completed both device jobs successfully on capture source `7bf817b`. It produced
21 native screenshots per family: 1320×2868 on iPhone and 2064×2752 on iPad.
All 42 PNG hashes/dimensions matched their manifests and their alpha channels
were fully opaque. Visual review approved all 21 iPad images and 20 iPhone
images: readable dark text, real Quran content, actual Fès map tiles/mosques,
and no loading screen or permission dialog. The iPad reader uses the existing
font-size setting of 40. Bukhari chapter labels returned by the live CDN are
English even in the French/Arabic editions; the surrounding app UI uses the
selected language. These are actual application screenshots, without invented
content or image-level translation.

The iPhone French `04-quran-reading` was rejected despite the successful test:
the native screenshot command took over fourteen seconds, exceeding the screen's
ten-second hold and capturing the following name screen. The rejected original
is preserved for audit. The approved French Al-Fatiha image from run
`35164407561` above supplies this one slot, with its original light theme and
provenance. The resulting source set contains 41 images from the new run and
that one previously verified reader image. No further capture run or replacement
of the original files was needed. A successful test alone therefore remains
insufficient to approve store images; visual review is mandatory.

Accepted portrait sizes are checked against Apple's
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/):
1320×2868 or 1290×2796 for the selected iPhone simulators, and 2064×2752 for
13-inch iPad Pro. Apple also accepts 2048×2732 for the 13-inch screenshot slot.

For a local Mac with a booted supported simulator:

```bash
flutter pub get
python3 scripts/capture_ios.py --device SIMULATOR_UDID --output build/app-store/local
```
