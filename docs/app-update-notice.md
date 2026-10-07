# Store update banner

The home navigation shell displays a non-modal banner above the navigation bar
when a store reports a newer SalaTime release. It offers **Update** (opens the
SalaTime store page) and **Later** (dismisses this release for 24 hours). On iOS
the available marketing version is shown; Android uses generic update text
because Play Core supplies a version code, not a marketing version.

The first check starts after two seconds on the visible home screen, without
awaiting it during app startup or prayer calculation. Checks also run when
returning home or resuming the app, with a six-hour session cache. Errors retry
after 30 minutes. Each optional dependency/network request has a five-second
timeout. Slow, invalid and offline responses leave the app usable and do not
show a false update. The rating invitation pauses while checking or showing
the banner. No modal update dialog or forced installation is requested.

## Store sources

- **Android:** `in_app_update` 4.2.5 wraps the official Play Core app-update API.
  The app accepts `updateAvailable` / `developerTriggeredUpdateInProgress` only
  for `net.salatime.app`, with a version code above the installed build. This
  respects the actual update available to the Google Play user, including
  store rollout eligibility. Local/sideload builds without Play ownership can
  receive `ERROR_API_NOT_AVAILABLE` and will silently skip the banner.
  No Play HTML scraping or private developer key is used.
- **iOS:** a native `net.salatime.app/store_updates` method channel returns
  `getContext` with StoreKit's actual storefront ISO2 `storeCountry` and
  UIDevice's `systemVersion`. The public Apple lookup API queries App Store ID
  `6812923710` in that storefront's country. There is no UI-language, GPS or US
  fallback when the storefront/system context is unknown or malformed. The
  result must contain exactly one software app, the matching numeric track ID,
  matching bundle `net.salatime.app`, and a higher numeric marketing version.
  The lookup's numeric `minimumOsVersion` must be known and no higher than the
  device's numeric system version; unknown, malformed or unsupported OS versions
  skip the banner. Build numbers do not trigger an update at the same marketing version. An
  unavailable country listing is not replaced with another country's result.
  The App Store itself remains the authority when opened.
- Both buttons use fixed HTTPS SalaTime store links. A response-provided URL
  is never launched. A failed launch leaves the banner present with retry text.

Checks are disabled in debug/profile builds, on web/desktop, and for package
variants such as `net.salatime.app.preview`. Test services inject `enabled:true`
and fake store responses. The local snooze setting is not synced to the cloud.
No email, account ID, GPS, reading contents or SalaTime hosting requests are
added. Store requests are subject to the stores' own data handling.

## Validation

```sh
flutter test --no-pub test/service/app_update_service_test.dart \
  test/view/app_update_banner_test.dart test/view/bottom_navbar_test.dart
flutter analyze --no-pub lib/service/app_update_service.dart \
  lib/view/base/app_update_banner.dart lib/view/base/app_update_notice_host.dart \
  lib/view/base/bottom_navbar.dart test/service/app_update_service_test.dart \
  test/view/app_update_banner_test.dart
```

The 28 tests cover identity/version checks, Android availability, native StoreKit
context, supported/minimum iOS versions, unknown system/storefront suppression,
lookup, same-version builds, coalescing, timeout/error recovery, persistent
snooze and dismissal races, store links, home/lifecycle visibility, rating
coordination, and French/Arabic text at 200% on 320px phones and 800px tablets.

To render an optional preview from the actual widget:

```sh
SALATIME_UPDATE_PREVIEW_PATH=/tmp/salatime-update-banner-preview.png \
  flutter test --no-pub test/view/app_update_banner_test.dart
```

The Play Core dependency and iOS StoreKit bridge require new Android and iOS
binaries. A Shorebird patch alone cannot add these native components. This feature is
prepared locally; tests and an Android compile do not prove a real Play-owned
device saw an available update. Test the final release through a Play test
track or internal app sharing with the same package/signing identity. For iOS,
test an installed release older than the public country listing. The banner
will only reach existing users after this code is distributed in an app update.

The Android release APK compiled successfully with the Analytics and Play Core
plugins. After running tests, use `flutter build apk --release` so Flutter
regenerates the release plugin registrant and excludes development plugins.
Using `--no-pub` can preserve a test registrant that references `integration_test`.
The StoreKit bridge and its new native XCTest still need a macOS/Xcode build;
the Dart context/compatibility contract is covered by the tests above.

Official references:

- [Google Play in-app updates](https://developer.android.com/guide/playcore/in-app-updates)
- [Google Play update testing](https://developer.android.com/guide/playcore/in-app-updates/test)
- [Apple lookup API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/LookupExamples.html)
- [Apple API country parameters](https://performance-partners.apple.com/search-api)
- [Flutter wrapper](https://pub.dev/packages/in_app_update)
