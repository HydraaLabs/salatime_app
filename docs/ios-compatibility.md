# iOS compatibility

This work adds an iOS WidgetKit extension and repairs native integration. A
successful simulator build does not establish that notifications, signing,
provider login or sensors work on a physical iPhone. No App Store release is
part of this change.

## Features and platform differences

| Feature | iOS implementation / remaining validation |
| --- | --- |
| Prayer calculation, methods, minute adjustments, calendar | Shared Flutter implementation; covered by the shared regression suite. |
| Quran translations, Athkar, checked readings and statistics | Shared Flutter implementation and local/cloud persistence. Cloud writes retain the one-minute debounce. |
| Light/dark/daylight appearance, language | Shared Flutter settings. Widget appearance follows the iPhone/widget system appearance. |
| Small, medium and large home widgets | New WidgetKit extension, shared App Group data, three native families, startup invitation and settings entry. iOS requires manual addition through the Home Screen widget gallery. |
| Widget data and timer | Offline snapshot of 30 days, independent of notification permissions. Elapsed time for 90 minutes after a prayer; countdown red below 45 minutes. System timer handles seconds; timeline handles phase changes. WidgetKit controls refresh timing. |
| Widget customization | Countdown, seconds, city, date, decorative symbol and background opacity are shared with iOS. Home Screen tint and system widget backgrounds can alter the final appearance. |
| Adhan, before/after reminders, additional reminders | Local iOS notifications use the existing nearest-60 scheduling budget, including other pending notifications. App opening/resuming and settings changes refill the window. With many reminders enabled this can cover only a few days. No guaranteed renewal after prolonged app closure is claimed. |
| Bundled notification sounds | 68 AIFF resources, each shorter than 30 seconds. iOS notification playback is a short excerpt; bundled in-app previews can play the full source. Normal notifications respect system silence/Focus settings. |
| Personal notification sounds | Audio document picker, conversion of the first 29 seconds to a local CAF in Library/Sounds, stable filename across container changes, preview resolution. Limit: 25 MB input and 30 unique imported sounds. Files remain device-local. |
| Qibla | Native heading uses true north when available and magnetic heading otherwise; motion/location updates stop when leaving the view. Accuracy and calibration require a physical iPhone. |
| Account and preference sync | Shared email account flow and Keychain token storage. The deployed API exposes email registration/reset. End-to-end iPhone login remains to be checked. |
| Google login | Requires an iOS OAuth client matching the signed bundle ID, its reversed URL scheme, backend `ios_client_id` and the compile-time enable flag. The deployed API had no iOS client ID at audit time. |
| Apple login | Requires an active Apple Developer configuration, Sign in with Apple capability, backend Apple provider configuration and the enable flag. The deployed API had Apple disabled at audit time. |
| Downloads / sharing | App Documents writes no longer request Android storage permission on iOS. Share sheets have a popover origin for iPad. |
| Automatic phone silence / restoring DND | Android feature; an ordinary iOS application cannot toggle the device's global silent/Focus mode. |
| Automatic wallpaper installation | Android feature. On iOS use sharing/saving and the system wallpaper settings. |
| Store review | The automatic Google Play invitation remains Android-only. The iOS settings link requires a configured App Store listing. |

## Configure a signed iPhone build

1. On a macOS machine or trusted macOS build service, install Flutter 3.41.8,
   Xcode and CocoaPods. Run `flutter pub get` and open
   `ios/Runner.xcworkspace`.
2. Select your Apple development team for **Runner** and **SalaTimeWidget**.
   Register your own bundle identifiers; the widget identifier must be prefixed
   with the Runner identifier. The repository's historical example identifiers
   are not a claim that an Apple app has been registered.
3. Enable an identical App Group for both targets. Copy
   `ios/Flutter/SalaTime.local.xcconfig.example` to the ignored
   `ios/Flutter/SalaTime.local.xcconfig` and set `SALATIME_APP_GROUP`.
   Runner's Keychain access group and Sign in with Apple entitlement also need
   to be allowed by its provisioning profile.
4. For Google, create an **iOS** OAuth client for the Runner bundle ID and set
   `SALATIME_GOOGLE_REVERSED_CLIENT_ID` in the local xcconfig. Set the matching
   public iOS client ID and server client ID in your backend configuration.
   Do not put OAuth client secrets into the app.
5. Enable Google/Apple only after their provider configuration is complete:

   ```bash
   flutter build ipa --release \
     --dart-define=SALATIME_GOOGLE_IOS_ENABLED=true \
     --dart-define=SALATIME_APPLE_IOS_ENABLED=true
   ```

   Omit either flag if that provider is not configured. Use your own backend
   through `SALATIME_API_URL` when building a fork.
6. Install with your registered-device provisioning or distribute through
   TestFlight after Apple processing. An unsigned simulator `.app` cannot be
   installed on a physical iPhone.

## Automated verification without a local Mac

`.github/workflows/ios-verification.yml` runs on GitHub's `macos-15` runner.
It analyzes/tests Flutter, compiles the simulator application and widget
extension, then runs native XCTest regressions for widget time transitions.
It does not sign or upload an IPA and does not submit an App Store release.

On macOS these checks can also be run locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --debug --no-codesign
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO -only-testing:RunnerTests test
```

Use an installed simulator name. Device checks still need to cover cold startup,
first-run language/location permissions, three widget sizes, midnight/time-zone
changes, elapsed/countdown transitions, foreground/locked/silent notifications,
imported audio, login/logout, offline reading followed by cloud synchronization,
and physical compass calibration. Do not mark these checks complete based on
unit tests alone.

## Platform references

- [Creating a WidgetKit extension](https://developer.apple.com/documentation/widgetkit/creating-a-widget-extension)
- [WidgetKit refresh policy](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/)
- [Notification sound requirements](https://developer.apple.com/documentation/usernotifications/unnotificationsound)
- [Flutter UIScene migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
