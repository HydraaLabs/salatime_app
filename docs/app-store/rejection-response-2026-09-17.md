# App Review 2.1 — response preparation

App: SalaTime, 6812923710. Version 1.0.22 (28), source 4e25332.
Submission: e80271c7-c411-4e24-870d-011dd4272d79.
Status checked 2026-09-17 08:31 UTC: REJECTED / UNRESOLVED_ISSUES.

Apple requests six items for an account with limited App Review history. Its
message does not identify a specific crash or assert an infringement. The
generic reminders about screenshots, purchases and user-generated content are
not separate findings about SalaTime.

**Local draft for the next build only. Not sent to Apple or saved as replacement Review Notes.**
The owner requested removal of both AI Assistant and the name generator after
build 28 was rejected. Both screens, controllers, client repositories and AI
consent have been removed locally. Build 28 still contains those features.
Build, upload and select a replacement before using the description below.
Record that replacement on the physical device and verify the video link before
submission. Preserve the existing dedicated review credentials in their secure
App Store Connect fields; do not include passwords in this file.

## Response draft

Hello App Review team,

Below is the requested information for SalaTime. The replacement build number
and recording reference must be inserted once both have been verified.

### 1. Physical-device demonstration

Pending: attach the recording and identify the device, installed iOS version,
app build, recording date, and chapter timestamps after inspecting the actual
video. The recording must begin with launching SalaTime and demonstrate the
main features plus registration, login and account deletion. Do not represent
simulator screenshots or automated tests as this recording.

### 2. Purpose and audience

SalaTime is a free public app for Muslims seeking practical help with daily
prayer and Quran study. It combines locally calculated prayer times, reminders,
Qibla direction, Quran reading and recitations, Athkar, Hadith, a Hijri calendar,
nearby mosques and prayer widgets. Its purpose is to make these daily activities
accessible from one app, including offline Quran reading and translations.
It is available to individual members of the public, without an organization
invitation or business membership.

### 3. Setup and access

Launch the app, select a language and set a location. Users can select a city
manually if they decline location permission. Notification permission is
optional. The principal reading and prayer features work without an account.
Open the Quran reader, choose a chapter and read its Arabic text, translation,
source information and notes. Recitations and nearby-mosque maps require an
internet connection. Widgets are added through the iOS widget picker.

Settings > Account provides email registration/login, Sign in with Apple and
Google sign-in. The dedicated, verified email/password review account is in
the App Review sign-in fields; it needs no one-time email code. Account features
include synchronization of supported preferences and reading progress.
No sample file is required.

To delete an account, sign in, open Settings > Account > Delete account and
confirm. An email/password account requires its password. A social account may
require a recent sign-in. Deletion removes the SalaTime account and its cloud
data. For the demonstration we will use a separate disposable account, preserving
the credentials supplied for review.

The replacement app contains no AI Assistant or name generator and makes no
requests to an AI provider. There are no public user posts, feeds or user-to-user
messaging. There are no paid features, subscriptions or in-app purchases.

### 4. External services

- SalaTime's HTTPS backend at salatime.net: account management, synchronization,
  and application configuration.
- Apple and Google: optional native social authentication.
- MP3Quran: reciter catalog and Quran audio streaming/downloads.
- QuranEnc: published Quran translations/commentary, imported with source
  metadata into the app for offline reading; no live translation API request
  is needed when reading a bundled chapter.
- OpenStreetMap tiles, Nominatim city search and Overpass mosque queries.
- jsDelivr hosting the fawazahmed0/hadith-api corpus: Hadith reference content.
- Mailgun: account-related email delivery through the backend.
- Sentry: application diagnostics and crash reporting.

Prayer calculations use the bundled Adhan library and device location/time
settings. They do not depend on a remote prayer-time provider. There is no
payment processor because all app features are free.

### 5. Regional behavior

The same feature set is offered in the 174 configured App Store territories.
Mainland China is excluded from this initial distribution. Interface language
and published Quran edition follow the user's language choice; prayer times
and mosque results depend on the selected location and calculation settings.
These are expected localization differences, not region-specific paywalls.
Network service availability and local map coverage can affect online features.

### 6. Third-party content

MP3Quran's published Copyrights provision allows visitors and developers to
copy its materials and use its links:
https://www.mp3quran.net/eng/privacy
Developer interface: https://www.mp3quran.net/eng/api

QuranEnc permits downloading and republishing translations subject to its
published terms, including preserving content, identifying the publisher and
source, retaining metadata, stating the version and keeping editions current:
https://quranenc.com/en/home/api

SalaTime's bundled editions retain source text and notes, publisher, version
and source links. The reader displays attribution and provides the source link.
The edition inventory and implementation evidence are in the accompanying
content-source dossier. These public permissions are the basis for use; we do
not claim a private exclusivity agreement or official endorsement.

## Completion checklist (internal)

- Replacement iOS build without either AI feature: required, not yet built/uploaded.
- Remove the six localized iPhone/iPad screenshot 07 assets showing the name
  generator from App Store Connect; retain the six other screenshots per set.
- Reassess App Privacy and age-rating answers for the replacement build; remove
  only disclosures that no remaining feature requires. The backend still serves
  older installed app versions.
- Physical video: pending; USB device unavailable despite user reconnecting.
- Device iOS version/current update availability: verify on the physical phone.
- Video inspection, privacy check, upload/link and timestamps: pending.
- Source permissions: official MP3Quran/QuranEnc pages checked 17 September.
- Apple login: user confirmed working after the platform-case fix.
- Google login, account registration/deletion and representative main features:
  demonstrate on the physical phone; do not infer from API/unit tests.
- Paste the completed six-point information into Review Notes within the field
  limit and reply to App Review with the complete dossier/video reference.
- Sending the App Review message remains a separate action; this draft has not
  been sent and the app has not been resubmitted.
