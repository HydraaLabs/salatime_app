# SalaTime

SalaTime is a Flutter prayer companion for Android and iOS. It includes prayer
times and calculation adjustments, Adhan and reminder settings, Qibla, nearby
mosques, Quran, Athkar and reading progress. Android and iOS home-screen widgets
come in three sizes. Appearance and language are configurable, and optional accounts
can synchronize preferences and reading progress with a self-hosted backend.

- **Mobile app:** [HydraaLabs/salatime_app](https://github.com/HydraaLabs/salatime_app)
- **Website and API:** [HydraaLabs/salatime](https://github.com/HydraaLabs/salatime)

## Requirements

- Flutter **3.41.x** / Dart **3.11.x**. Development checks use Flutter 3.41.8;
  the existing Android Shorebird release uses Flutter 3.41.6.
- Android development: Linux, macOS or Windows, Android SDK **36**, platform tools,
  and a compatible JDK (the project uses Java 17 language features; JDK 21 is
  used for development checks).
- iOS development: macOS, Xcode **26.1 or newer** (CI: 26.3) and CocoaPods.
  The current device-info dependency uses APIs from that SDK. iOS cannot be
  built on Linux.
- A physical phone is recommended for compass, notification and widget checks.

Run `flutter doctor` and complete the platform setup before building.
This is a mobile application; desktop and Flutter Web are not supported targets.

## Installation

```bash
git clone https://github.com/HydraaLabs/salatime_app.git
cd salatime_app
flutter pub get
flutter devices
flutter run -d YOUR_DEVICE_ID
```

No Play Console, Shorebird account, signing secret or production database is
needed for a debug build. A USB Android device must have developer mode and USB
debugging enabled and authorize your computer. A debug build cannot replace an
installed Play build with a different signature; use the companion variant:

```bash
ORG_GRADLE_PROJECT_salatimePreview=true flutter run -d YOUR_DEVICE_ID
```

This installs `net.salatime.app.preview` with separate app data.
The default API is `https://salatime.net`. For an independent installation, install
the [backend](https://github.com/HydraaLabs/salatime#installation) and supply its URL:

```bash
flutter run -d YOUR_DEVICE_ID \
  --dart-define=SALATIME_API_URL=https://your-domain.example
```

The phone must be able to reach the URL. `localhost` on a phone refers to the
phone itself. Use HTTPS for a hosted backend; platform transport policies may
block plain HTTP. Do not include `/api` at the end of the base URL.

## Optional configuration

Compile-time options can be passed with `--dart-define=NAME=value`:

| Option | Purpose |
| --- | --- |
| `SALATIME_API_URL` | Website/content API base URL; also the default account API |
| `SALATIME_ACCOUNT_API_URL` | Override the account API base URL independently |
| `SALATIME_MAPS_API_KEY` | Your key for the optional maps/directions integration |
| `SALATIME_SENTRY_DSN` | Your error-reporting DSN; pass an empty value to disable collection (used by iOS CI) |
| `SALATIME_HADITH_API_KEY` | Your key for the optional Hadith integration |
| `SALATIME_GOOGLE_IOS_ENABLED` | Set to `true` after configuring the iOS Google URL scheme/client |
| `SALATIME_APPLE_IOS_ENABLED` | Set to `true` after configuring the Sign in with Apple entitlement |

Client-side keys are extractable from a mobile build. Restrict them with the
provider and never embed server secrets. Missing optional keys can make their
corresponding external features unavailable. Google/Apple login and mail account
flows require configuration on your own backend and identity-provider projects;
see the backend guide. Core local prayer calculations do not require an account.

For a separately distributed fork, configure your own application/bundle IDs,
OAuth clients, signing keys and any associated domains. Existing native
`com.example.zabi` class names are retained for compatibility with installed
widgets and notification receivers; the displayed app and Dart package are
**SalaTime** / `salatime`. Historical filenames are not the product name.

## Build

For a locally installable Android debug APK:

```bash
flutter build apk --debug --dart-define=SALATIME_API_URL=https://your-domain.example
```

For your own signed Android release, create a keystore and an ignored
`android/key.properties` based on `android/key.properties.example`, then run:

```bash
flutter build appbundle --release \
  --dart-define=SALATIME_API_URL=https://your-domain.example
```

Keep signing files private. The release build requires your own keystore.
For iOS, configure signing and the shared App Group for **both** Runner and
SalaTimeWidget, then build with `flutter build ipa` on macOS. See the
[iOS setup and compatibility guide](docs/ios-compatibility.md) for widgets,
Google/Apple configuration and differences from Android. The GitHub macOS
verification workflow builds an unsigned simulator app without a local Mac.

Shorebird is optional. Its checked-in application ID belongs to the existing
SalaTime release; a fork must use its own Shorebird application before publishing
updates. Ordinary Flutter development does not require a Shorebird release.

## Tests

```bash
flutter analyze
flutter test
```

Android native tests can also be run after Flutter dependencies are resolved:

```bash
cd android
./gradlew app:testDebugUnitTest
```

Real-device checks remain necessary for Samsung/One UI widgets, background
alarms, silent mode, compass accuracy and Google/Apple login.

## Project structure

- `lib/`: Flutter application, controllers, UI and services.
- `assets/`: localization, fonts and reference/media assets.
- `android/`: native notification, alarm and home-screen widget integration.
- `ios/`: iOS application and platform configuration.
- `test/`, `integration_test/`: automated checks.
- `docs/`: technical notes and release history.

## License

SalaTime code that HydraaLabs can license is available under the [MIT license](LICENSE).
Dependencies and third-party texts, sounds, images and inherited components keep
their own terms; see [third-party notices](THIRD_PARTY_NOTICES.md).
