# iOS compatibility

SalaTime includes an iOS WidgetKit extension and native platform integration. A
successful simulator build does not establish that notifications, signing,
provider login or sensors work on a physical iPhone. Compilation, physical-device
validation and App Store publication are separate checks. The application,
widget and Flutter framework target iOS
15 or newer, matching [Apple’s supported deployment range for Xcode 26.3](https://developer.apple.com/xcode/system-requirements).

## Features and platform differences

| Feature | iOS implementation / remaining validation |
| --- | --- |
| Prayer calculation, methods, minute adjustments, calendar | Shared Flutter implementation; covered by the shared regression suite. |
| Quran translations, Athkar, checked readings and statistics | Shared Flutter implementation and local/cloud persistence. Cloud writes retain the one-minute debounce. |
| Light/dark/daylight appearance, language | Shared Flutter settings. Widget appearance follows the iPhone/widget system appearance. |
| Small, medium and large home widgets | New WidgetKit extension, shared App Group data, three native families, startup invitation and settings entry. iOS requires manual addition through the Home Screen widget gallery. |
| Widget data and timer | Offline snapshot of 30 days, independent of notification permissions. Elapsed time for 90 minutes after a prayer, switching to the next prayer once it is at most one hour away; countdown red below 45 minutes. System timer handles seconds; timeline handles phase changes. The displayed date follows the displayed prayer and the large schedule keeps a late Isha with its original prayer day. Minute countdowns round remaining time up, matching Android. WidgetKit controls refresh timing. |
| Widget customization | Countdown, seconds, city, date, decorative symbol and background opacity are shared with iOS. Home Screen tint and system widget backgrounds can alter the final appearance. |
| Adhan, before/after reminders, additional reminders | Local iOS notifications use the existing nearest-60 scheduling budget, including other pending notifications. App opening/resuming and settings changes refill the window. With many reminders enabled this can cover only a few days. No guaranteed renewal after prolonged app closure is claimed. |
| Bundled notification sounds | 68 AIFF resources, each shorter than 30 seconds. iOS notification playback is a short excerpt; bundled in-app previews can play the full source. Normal notifications respect system silence/Focus settings. |
| Stopping sound with side buttons | Android hardware-button interception is not used on iOS. The system handles notification playback; volume/side-button behavior must be verified on a physical iPhone. |
| Personal notification sounds | Audio document picker, conversion of the first 29 seconds to a local CAF in Library/Sounds, stable filename across container changes, preview resolution. Limit: 25 MB input and 30 unique imported sounds. Files remain device-local. |
| Qibla | Native heading uses true north when available and magnetic heading otherwise; motion/location updates stop when leaving the view. Accuracy and calibration require a physical iPhone. |
| Account and preference sync | Shared email account flow and Keychain token storage. The deployed API exposes email registration/reset. End-to-end iPhone login remains to be checked. |
| Google login | Requires an iOS OAuth client matching the signed bundle ID, its reversed URL scheme, backend `ios_client_id` and the compile-time enable flag. The deployed API had no iOS client ID at audit time. |
| Apple login | Requires an active Apple Developer configuration, Sign in with Apple capability, backend Apple provider configuration and the enable flag. The deployed API had Apple disabled at audit time. |
| Downloads / sharing | App Documents writes no longer request Android storage permission on iOS. Share sheets have a popover origin for iPad. |
| Wallpaper | Download/share flow is shared. Directly applying a wallpaper remains Android-only; iPhone users select the saved image through iOS. |
| Automatic phone silence / restoring DND | Android feature; an ordinary iOS application cannot toggle the device's global silent/Focus mode. |
| Store review | The automatic Google Play invitation remains Android-only. The iOS settings link requires a configured App Store listing. |

## Verification record — 14 September 2026

[GitHub Actions run 34791584226](https://github.com/HydraaLabs/salatime_app/actions/runs/34791584226)
completed successfully for commit `8dd9782b5be995c3dddab0b012ed0ba83405da37`
on the `ios-compatibility` branch, using Flutter 3.41.8 and Xcode 26.3:

- Flutter analysis reported no issues and all 523 Flutter tests passed.
- The simulator application and embedded WidgetKit extension compiled.
- The unsigned physical-iPhone release compiled (Runner.app, 139.9 MB).
- The Runner XCTest suite completed successfully: five tests cover widget timing,
  bounded timelines/options, and all 68 bundled notification sounds.
- The simulator launched the app. Its captured first-run screen was visually
  checked: the SalaTime theme, language picker and Next button display without
  visible overflow. This is a launch check, not an end-to-end UI audit.

The run retains a simulator archive and launch screenshot for seven days. The
unsigned iPhone build is a compilation check; it was not installed or submitted.
No physical iPhone, signed App Group, provider login, background notification or
compass calibration was verified. The public account configuration was rechecked
on this date: email enabled, Google iOS client absent, Apple provider disabled.
Cloud writes remain delayed by one minute, but iOS suspension can postpone a
pending write until the app resumes.

## Local parity review — 17 September 2026

The shared regression suite passed **590 Flutter tests**, and `flutter analyze`
reported no issues on the Linux workspace. The suite includes iOS notification
sound/silence and badge behavior, widget onboarding/settings, imported audio,
offline Quran, prayer calculations/adjustments, cloud synchronization, sharing,
and layout tests. These are automated code checks, not physical-iPhone results.

The review repaired two native widget differences from Android:

- The large widget's timetable and displayed date now follow the displayed
  prayer when the countdown switches to tomorrow before midnight. Prayer-day
  grouping also keeps an Isha adjusted past midnight with its original timetable.
- With seconds hidden, the countdown rounds remaining minutes up, preventing
  `00:00` from appearing while a prayer is still up to 59 seconds away. Elapsed
  minutes continue to round down.

Native regression coverage now includes these boundaries and late-Isha grouping.
The additional XCTest cases must run on macOS; the Linux Flutter suite cannot
execute WidgetKit or XCTest. The historical macOS run above does not validate
these later native edits or a signed release.

Before claiming iPhone parity, record results on a signed physical-device build:

| Check | Required result |
| --- | --- |
| Installation and first launch | Cold startup, language selection, permission refusal/retry, and saved/manual city all work. |
| Widgets | Add all three sizes; change options; check tomorrow before midnight, late Isha, city time zone, elapsed/next switch, and last minute. |
| Prayer notifications | Receive adhan and before/after/additional reminders in foreground, background, and with the phone locked; check silent/Focus behavior and imported audio. Reopen after the rolling schedule expires and confirm renewal. |
| Quran and audio | Read/bookmark/check passages offline; resume cloud synchronization when online; play/pause Quran with lock-screen audio controls. |
| Location and Qibla | Revoke/regrant location, change manual city, move with auto-update enabled, rotate/calibrate the compass, and leave the screen to stop sensors. |
| Account | Complete email, enabled provider logins, logout/relogin, account deletion, and preference restoration. |
| iPad | Check both orientations, text scaling, calendar export, and share sheets. |

An adhan notification's short audio excerpt, the rolling notification window,
manual widget addition, and the absence of global silent/Focus control are
documented iOS differences; they are not evidence of Android-equivalent behavior.

## Configure a signed iPhone build

1. On a macOS machine or trusted macOS build service, install Flutter 3.41.8,
   Xcode 26.1 or newer (CI uses 26.3) and CocoaPods. Run `flutter pub get` and open
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

`.github/workflows/ios-verification.yml` runs on GitHub's `macos-15` runner
with Xcode 26.3 explicitly selected. Xcode 16.4 cannot compile the current
`device_info_plus` dependency because its SDK lacks `isiOSAppOnVision`.
It analyzes/tests Flutter, compiles the simulator application and widget
extension, runs native XCTest regressions for widget time transitions and bundled
audio, and compiles an unsigned iPhone release.
The simulator build disables Sentry reporting. It does not sign or upload an IPA and does not submit an App Store release.

On macOS these checks can also be run locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator --debug --no-codesign --dart-define=SALATIME_SENTRY_DSN=
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
