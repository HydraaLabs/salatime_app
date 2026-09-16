# App Review preparation — 17 September 2026

Prepared locally for App Store Connect app 6812923710. No remote changes were made by this preparation.

## Copy-ready review notes (finalize after signed-build verification)

SalaTime provides prayer times, Quran reading and recitation, Qibla, Athkar, a Hijri calendar and prayer widgets. The main features work without an account. Location can be declined: select a city manually during setup or in location settings. Notification permission is optional and used for prayer reminders. Online map, nearby-mosque and recitation services require internet.

The optional account is under Settings > Account. It supports saving supported preferences and Quran/Athkar reading progress across devices. Account deletion is available inside that account screen. The app may ask for a recent sign-in or password confirmation before deletion. Sign in with Apple must be activated and verified with the final signed provisioning profile before these notes are submitted.

The Classic home layout also exposes an Islamic AI assistant, and the app includes an AI name generator. These send user-entered questions or generator choices to SalaTime's server and then 1min.ai. Before the first transmission, the app names 1min.ai, describes the data sent and asks permission. Consent is saved on that device for both AI features, and the privacy icon lets users stop future sharing. Verify this flow in the exact submitted build. Do not claim generated answers have a verified universal content filter.

## Fields the owner/account must supply or confirm

- Copyright confirmed by the release coordinator from the organization account: 2026 POTIZA LLC.
- App Review contact first name, last name and reachable phone number. `contact@salatime.net` is the public support address found in code, not proof of a named reviewer contact.
- If account features require a review-only account, create that account separately and provide credentials through App Store Connect's secure review fields. Do not put credentials in Git. Guest access alone covers only guest features.
- Any trader/business identity and distribution-region declarations required by the Apple account.

## Files

- `store-listing.json`: EN/FR/AR names, subtitles, keywords, promotional text and descriptions; character limits checked. Lifestyle primary and Reference secondary are proposed categories.
- `privacy-assessment.json`: data-flow inventory, proposed purposes, known linkage and unresolved partner/SDK details. `null` means unresolved, never “No”.
- `age-rating-assessment.json`: confirmed feature flags and source-based content recommendations. Keep Apple’s calculated rating; do not force 4+ or copy Google Play.

## Specific verification still needed

- Public `/support` and `/privacy-policy` returned HTTP200 to the release coordinator using User-Agent SalaTime-iOS-Release/1.0. An uncustomized direct client previously got403; maintain public access for review.
- Apple privacy paragraphs are now in the local account-privacy Blade partial; targeted deployment is coordinated separately.
- Exact pinned Cocoa8.58.4 manifest declares crash/performance/other diagnostics unlinked, for app functionality, without tracking. Source confirms a random persistent installationID as Sentry userId. No account setUser calls exist; final label mapping of that anonymous installation identifier is documented in the privacy JSON. No real user event was needed.
- Public settings API persists guest IP/OS and GeoIP-derived country/city/coordinates. Check current runtime provider and retention before final disclosures. The repository driver default is IpApi with fallbacks; no runtime secrets were read.
- Mosque searches send exact coordinates to Overpass, city search text goes to Nominatim, and viewed map tiles go to OpenStreetMap. Cloud preferences explicitly exclude GPS and personal audio files.
- Full scriptural content and generated responses require editorial age-rating assessment. Sampled bundled Quran passages contain textual references to intoxicants, weapons and mature topics. These were recorded as content evidence, not a judgement about the religion or an assumed automatic rating.

Sources: [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details/), [current age-rating definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions), [AI disclosure update](https://developer.apple.com/news/?id=ey6d8onl).
