# Location review remediation — 24 September 2026

Status: corrections prepared for an isolated iOS test build, not submitted. The rejected build is 1.0.26 (33),
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
- All 58 distinct targeted tests passed across the final targeted run and the
  corrected UI-test rerun. The UI rerun has 7/7 passing tests; native EventChannel
  cancellation is awaited outside Flutter's fake-timer zone.
- `flutter analyze` on the changed Dart implementation and tests: no issues.
- `git diff --check`: clean.
- GitHub CLI access was restored on 24 September. A signed test build is being
  prepared on a dedicated branch, without an App Store Connect upload. Physical
  background-travel evidence remains outstanding. The review response above is
  still an unsent draft.

## References

- Review message: https://appstoreconnect.apple.com/apps/6812923710/distribution/reviewsubmissions/details/9310cc24-6213-4e64-91fb-a3970a56930b
- Apple permission design: https://developer.apple.com/design/human-interface-guidelines/privacy
- Background location: https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
