# App Store screenshots

Run the manual **iOS App Store screenshots** GitHub Actions workflow. It captures
the real Flutter application screens on separate iPhone Pro Max and 13-inch iPad
simulators using Xcode 26.3 and Flutter 3.41.8. It requires no Apple credentials.

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

Accepted portrait sizes are checked against Apple's
[screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/):
1320×2868 or 1290×2796 for the selected iPhone simulators, and 2064×2752 for
13-inch iPad Pro. Apple also accepts 2048×2732 for the 13-inch screenshot slot.

For a local Mac with a booted supported simulator:

```bash
flutter pub get
python3 scripts/capture_ios.py --device SIMULATOR_UDID --output build/app-store/local
```
