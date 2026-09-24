# Location review remediation — 24 September 2026

Status: corrected iOS 1.0.26 (34) compiled, signed and installed on the registered
iPhone on 24 September 2026. Not uploaded or submitted to App Store Connect. The rejected build is 1.0.26 (33),
submission `9310cc24-6213-4e64-91fb-a3970a56930b`. Apple reviewed it on an
11-inch iPad Air (M3). Do not label the 2.5.4 objection resolved until the physical
background-travel test is recorded and Apple accepts the justification.

## Changes

- iOS onboarding no longer presents the optional background-location pre-prompt.
  Prayer settings now expose **Update as you travel** / **Actualiser lors des
  déplacements**, with a switch and the actual authorization state.
- The optional iOS explanation has one neutral **Next** / **Suivant** action.
  There is no Activate/No thanks choice or back dismissal before the system request.
  System refusals return to the previous screen without an automatic Settings dialog.
- While Using remains usable without Always. Returning from system Settings
  reconciles permissions: upgrade/downgrade the native watcher, stop on revocation,
  and reconnect after a location stream failure, without requesting permission.
- Explicit travel opt-in exits manual-city mode. Selecting a manual city or
  turning the option off cancels the watcher and waits for its in-flight refresh.
- A displacement of approximately 3 km refreshes prayer times, widgets and adhan
  schedules. Background refresh does not open notification permission prompts.
- French, English and Arabic explanations no longer claim coordinates never
  leave the device. Coordinates may reach prayer calculation/geocoding services.

`UIBackgroundModes.location` is deliberately retained for the existing opt-in
travel feature. This is the demonstration/justification route offered by Apple,
not the alternative of removing background travel updates. No continuous GPS
history is introduced. Native settings remain low accuracy / 1500 m delivery
filter; application refresh threshold remains 3000 m. This is not a guarantee of
tracking after force-quit, loss of location services or OS restrictions.

## Physical-device validation and recording (still required)

Use the corrected signed build; do not reuse the old September 17 video as proof.

1. Show the installed build number and device iOS version. Start from the home
   screen icon. Show that ordinary use/manual city selection does not require Always.
2. Open **Plus → Settings → Prayer time settings** (localized equivalent), then
   **Update as you travel**. Continue through the neutral explanation and grant
   location access in the system dialog. If iOS defers Always, grant it in system
   Settings and return; show the background-authorized state.
3. Show the departure city, prayer timetable, widget and upcoming notifications.
   Enable a prayer's adhan and its relevant before/after reminders.
4. Keep SalaTime in the background during a real displacement exceeding 3 km.
   Use a sufficiently different destination to make the city/times visibly change.
   Show the widget at destination **before reopening SalaTime**, then show the
   updated timetable and upcoming adhan schedule in the app. A screen recording
   plus external filming may be needed to document the locked-screen interval.
   No location simulation counts as physical travel evidence.
5. Check a scheduled adhan on the real device. Record the observed result and
   sound volume. Do not infer audible playback from schedule metadata alone.
6. Test While Using and refusal separately: ordinary app use remains possible.
   Revoke access, restore it, then disable travel updates / pick a manual city.
   Verify tracking stops and the manual city's times are retained.

Keep personal notifications/accounts out of the recording. Avoid exposing a home
address or precise route in the App Review attachment. The essential evidence is
background state, changed location/timetable and matching widget/adhan updates.

## Draft review note — send only after completing the evidence

The optional travel feature is available in Settings → Prayer time settings →
Update as you travel. It refreshes local prayer times, adhan reminders and widget
data when the device moves approximately 3 km, including while the app is in the
background when location access is authorized. The switch can disable it at any
time, and selecting a manual city also stops automatic tracking.

We removed the background-location prompt from iOS onboarding. The optional
explanation now has one neutral Next button leading to the system permission
request, with no Activate/No thanks buttons. Refusing Always leaves While Using
available; refusing location does not block manual-city use. A refusal no longer
opens an unsolicited Settings prompt.

[Insert corrected build number, recording filename, device/OS and verified
background-update timestamps here. Do not send with placeholders.]

## Local validation

- Targeted Flutter tests: location native flags, watcher lifecycle and movement
  threshold/failure retry, permission UI, settings navigation/status, onboarding,
  narrow-screen/large-text settings layout, prayer adjustment scheduling, native
  schedule batching and notification scheduler.
- Full GitHub Actions verification: **652 Flutter tests passed**, Flutter analysis
  reported no issues, and the native iOS simulator regression step succeeded.
- The signed archive and IPA both validate Runner and SalaTimeWidget as 1.0.26
  (34), including the app group, signing profiles and Google URL scheme.
- `git diff --check`: clean.

## Verified build and device installation

- Source commit: `787dd2f4df59e836c3ff14a7da8db2ef321ac1cd`.
- Signed build: https://github.com/HydraaLabs/salatime_app/actions/runs/36061014807
- Private device package: https://github.com/HydraaLabs/salatime_app/actions/runs/36063500568
- Re-signing verified unchanged code and resources and authorization for exactly
  one registered device. The connected iPhone matched the private profile.
- USB upgrade completed successfully from 1.0.22 (28) to **1.0.26 (34)** on
  **iOS 26.6.1**. A separate installed-app query confirmed the new version/build.
  The existing app was upgraded without uninstalling it.
- Local device IPA: `release-artifacts/ios-location-review-34/SalaTime-AdHoc-34.ipa`.
- Device IPA SHA-256: `aadf59a94327918e18b39f7ce74741f304f633e29048b321ae78ca81c4985a7a`.
- App Store IPA SHA-256: `d36720cb25ee57eee531a6a895ac07034a42be0685de1d66400fc463d3432ac2`.
- The temporary repository secret used to encrypt the private artifact was removed
  after download and authenticated local decryption. IPA files are git-ignored.
- **Not yet verified:** physical background travel, the destination widget before
  reopening the app, and audible adhan at the recalculated time. Installation and
  simulator tests are not evidence of those behaviors. The required recording and
  review reply remain outstanding; nothing was sent to App Review.

## References

- Review message: https://appstoreconnect.apple.com/apps/6812923710/distribution/reviewsubmissions/details/9310cc24-6213-4e64-91fb-a3970a56930b
- Apple permission design: https://developer.apple.com/design/human-interface-guidelines/privacy
- Background location: https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
