# App Review preparation — 17 September 2026

App Store Connect app `6812923710`, iOS version `1.0.22` (`fec07b01-c9f0-4325-9adc-b9245542fce6`). The version remains a draft. Saving its review information does not submit or publish it.

## Review information saved and verified

The owner-confirmed review contact and a dedicated, verified SalaTime mobile account were saved in App Store Connect through the API and read back successfully. The record ID is `f73f9e57-3955-43fe-b20d-9d66a16095c6`. Contact details and credentials are deliberately excluded from this public repository; the password is kept in private owner-readable storage and the App Store Connect sign-in fields.

`demoAccountRequired` is **true**. Main app features are available to guests, but an authenticated account is needed to exercise synchronization and account management. Apple's review guidelines require access to account-based features, including when social sign-in is offered. The supplied credentials are for the app's email sign-in and are not Apple Account credentials. The account has no administration privileges, needs no one-time email code, and contains no personal user history. No registration email was sent.

[app-review-notes.txt](app-review-notes.txt) is the exact note body saved remotely, excluding its final newline: 2,047 UTF-8 bytes, below Apple's 4,000-byte limit. It explains guest access, optional permissions, account/sync access, native Apple sign-in, deletion and the explicit 1min.ai consent. [review-details-verification.json](review-details-verification.json) records non-secret API readback and verification results.

## Verified access and remaining device checks

Two HTTPS login sessions successfully accessed the dedicated account. A preference update made in one session was read from the other, then the test preferences were restored to an empty object. The reading-progress endpoint was accessible and both preparation tokens were revoked. The account remains active for review. Deletion was not executed on the review account, since that would remove the credentials supplied to Apple.

The account/API test does not prove native Apple authorization, final provisioning, notification delivery, widgets, audio or background behavior on iPhone/iPad. Verify these flows in the exact signed build before submission. The AI consent unit/widget tests cover cancellation without transmission, stored consent, revocation and translated layouts; an exact-build device check is still required. Generated answers do not have a verified universal content filter.

## Store data and readiness snapshot

At the API audit on 16 September 2026 at 23:48 UTC (17 September local time):

- EN/FR/AR listing and app-information localizations were saved; support and privacy URLs were populated. Copyright is `2026 POTIZA LLC`, confirmed from the organization account.
- Lifestyle and Reference categories were saved. The current USA price point was `0.0` USD.
- Apple calculated **12+**, and **14 in Brazil**, with all age overrides `NONE`. [age-rating-assessment.json](age-rating-assessment.json) contains the actual saved answers and their evidence, including the limitations of the source audit.
- No build was uploaded or selected, and all three localized screenshot-set collections were empty.
- The release coordinator configured all 175 territories; readback confirms all 175 have `available=true`. Each reports `CANNOT_SELL` and `AVAILABLE_FOR_SALE_UNRELEASED_APP`, consistent with an app that has not been released. This is configured distribution, not a public release.
- After the owner explicitly confirmed permission to distribute the content, `contentRightsDeclaration=USES_THIRD_PARTY_CONTENT` was saved by the release coordinator and verified by this audit.
- The Arabic keywords were shortened and read back as 90 UTF-8 bytes; EN and FR were 72 and 88 bytes. All are within the 100-byte limit in Apple's current help.
- No trader-specific blocking status appeared in the territory API results. The official API schema exposes neither a DSA/trader verification endpoint nor commercial-agreement status (only beta/EULA license resources). The release coordinator separately verified the Business screen: the free-app agreement is active from 16 September 2026 to 16 September 2027, and DSA status is Active for the 27 EU countries, updated 17 September 2026. The pending paid-app tax setup does not block this free release.
- The release coordinator opted out of automatic Mac and Vision distribution for this initial iPhone/iPad release.

This snapshot is not a claim that these fields remain unchanged after the release coordinator's subsequent work. Screenshots and an accepted signed build remain distinct from saving the review record.

## Privacy evidence

Public `/support` and `/privacy-policy` returned HTTP 200 to the release coordinator using User-Agent `SalaTime-iOS-Release/1.0`. An uncustomized direct client previously received 403; preserve access for Apple review.

The account-privacy partial now describes Apple sign-in; its deployment is coordinated separately. The public settings API persists guest IP/OS and GeoIP-derived country/city/coordinates. Nearby-mosque requests send exact coordinates to Overpass, city-search queries go to Nominatim, and map tiles go to OpenStreetMap. Cloud preferences exclude GPS coordinates and personal audio files.

The exact pinned Sentry Cocoa 8.58.4 manifest declares crash/performance/other diagnostics unlinked, for app functionality, without tracking. Its source assigns a random persistent installation ID as Sentry user ID; there is no app account `setUser` call. The release coordinator separately published the 14 data categories in App Store Connect, including the installation Device ID as linked to the device, without tracking. [privacy-assessment.json](privacy-assessment.json) documents that inventory and the disclosure decisions. This review subtask did not change the App Privacy UI.

Sources: [Apple App Review Guidelines, 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness), [platform-version fields and App Review information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information), [age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions), [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/).
