# Travel updates: Android and iOS parity

Implementation follow-up to iOS build 34, 24 September 2026. These changes ship
in Android 1.0.27+31 and iOS 1.0.27 (35). Build 34 on the physical iPhone does
not include this follow-up. Store submission and device-test status are recorded
in [the release report](../release-1.0.27.md); neither store release is yet public.

Both platforms use the shared travel setting, 3 km recalculation threshold,
prayer/widget/adhan refresh pipeline, authorization reconciliation on resume,
and cancellation when a manual city is selected. Background tracking is now
optional in prayer settings on both platforms, without a first-launch request.

Android previously used generic location stream settings. It now uses the
geolocator location foreground service only after opt-in and background access.
The manifest includes `FOREGROUND_SERVICE_LOCATION` for Android 14+; the plugin
declares the `location` service type. Low accuracy, a 1500 m delivery filter and
a one-minute requested interval limit sampling. A wake lock keeps processing
available with the screen locked. Cancelling the stream stops this service,
removes its notification and releases its lock.

The service notification uses the plugin's dedicated ID 75415 and channel
`geolocator_channel_01`; it does not share the prayer/reminder display IDs
9901/9902 or the adhan media playback service. The existing per-prayer sound
choices remain independent of travel tracking.

Android retains a decline option in its background explanation, as required by
the Android permission guidance. French, English and Arabic explain the system
"Allow all the time" choice and persistent tracking notification. iOS retains
the neutral Next action prepared for App Review. Foreground-only access remains
usable on both platforms; passive resume checks never request permission.

Validation covers both native channel adapters and the same lifecycle/permission
scenarios on Android and iOS: grant, downgrade, revoke, restore, opt out, manual
mode, movement threshold, failed refresh retry and stream reconnection. Layouts
are exercised on small screens and tablets with enlarged text.

Local results: 42 targeted Flutter tests passed across both platforms; the four
native-channel tests were rerun successfully after selecting the release-kept
notification icon. `flutter analyze --no-pub` reported no issues. The final
`flutter build apk --debug --no-pub` succeeded. The merged Android manifest
contains the location foreground-service permission and a non-exported location
service with the correct type. This is a debug compilation, not a store build.

No physical Android device was connected during this change. Real displacement,
background delivery and audible rescheduled adhan still require device testing.
Neither OS is guaranteed to continue tracking after force-stop, permission
revocation or system termination. The Android foreground service helps preserve
the current Flutter process; it does not create a separate headless engine.

References:
- https://developer.android.com/develop/sensors-and-location/location/permissions/background
- https://developer.android.com/about/versions/14/changes/fgs-types-required
