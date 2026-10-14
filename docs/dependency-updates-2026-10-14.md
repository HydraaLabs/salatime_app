# Dependency updates (2026-10-14)

## Applied

- `flutter pub upgrade` within the existing constraints: 41 patch/minor
  releases (audio_service, just_audio, sentry_flutter 9.30.1,
  shared_preferences, url_launcher, flutter_map, flutter_cache_manager,
  connectivity_plus, vibration, permission_handler_apple, geolocator_apple…).
- `flutter_timezone` 4 → 5.1.1: `getLocalTimezone()` returns a `TimezoneInfo`;
  `PrayerTimeZones` reads `.identifier`.
- Android Gradle Plugin 8.11.1 → 8.12.3, required by `share_plus` ≥ 12.
  `android.enableR8=true` was removed from `gradle.properties`: R8 is always
  enabled in AGP 8 and AGP 8.12 rejects the obsolete option.
- With AGP 8.12 the `win32` 6 family resolves:
  - `share_plus` 11 → 13.3.1 (no Dart API change for SalaTime),
  - `package_info_plus` 9 → 10.2.2 (minimum iOS 13, Flutter 3.41.6),
  - `flutter_secure_storage` 10 → 11.2.0,
  - `geolocator` 13 → 14.1.1 and `flutter_qiblah` 3.1 → 3.2.0.

### flutter_secure_storage 11 and existing sessions

v11 removes the algorithms deprecated in v10. SalaTime only ever shipped v10
with its default algorithms (RSA-OAEP key wrapping, AES-GCM storage) and a
`storageNamespace`, which v11 keeps. Verified on an Android 15 emulator: a
value written by v10 with SalaTime's exact `AndroidOptions`/`IOSOptions` was
read back by v11 after an in-place upgrade. The iOS keychain path was not
exercised by a device test.

## Not applied

| Package | Reason |
| --- | --- |
| `flutter_local_notifications`, `timezone` | Pinned: native alarm adapters target the 17.2.4 storage format (see `PRAYER_RELIABILITY.md`). |
| `in_app_review`, `sign_in_with_apple` | Deliberate pins (rating fix, Apple sign-in range). |
| `permission_handler` 13 | Requires compileSdk 37 and changes Android behavior: `Permission.status` no longer reports `permanentlyDenied`, which the location and Qibla permission flows rely on. Needs a dedicated change with device tests. |
| `geocoding` 5 | Android implementation rewritten on Pigeon proxy APIs; it decides the country used for the automatic calculation method. The Linux test harness mocks the old method channel. No functional gain. |
| `sentry_flutter` 10, `google_fonts` 9, `cached_network_image` 4, `in_app_update` 5, `shimmer` 4, `cupertino_icons` 2 | Not resolvable with Flutter 3.41.8 / Dart 3.11. |

## Release note

These updates change native Android/iOS code. They need a full store release;
they cannot be delivered as a Shorebird patch to an existing release.

## Checks

- `flutter analyze`, `flutter test` (825), `./gradlew app:testDebugUnitTest` (269).
- Android 15 emulator: onboarding, notification and location permissions,
  location (test provider, Paris) with reverse geocoding, prayer times in the
  device zone, Qibla (119° from Paris), version in Settings, image sharing.
- iOS: GitHub `iOS verification` workflow on the branch.
