# Signed iOS release

The manually dispatched `iOS App Store release` GitHub Actions workflow builds
SalaTime on macOS 15 with Xcode 26.3 and Flutter 3.41.8. It checks the public
production account configuration, runs the Flutter analyzer and tests plus the
iOS simulator native regression suite, archives
Runner and its WidgetKit extension, exports a signed App Store IPA, and checks
the entitlements of both the archive and the exported IPA.

## Apple configuration

Register these explicit identifiers on the same Apple Developer team:

| Target | Bundle identifier | Required capabilities |
| --- | --- | --- |
| Runner | `net.salatime.app` | Sign in with Apple, App Groups, Keychain |
| SalaTimeWidget | `net.salatime.app.SalaTimeWidget` | App Groups |

Both targets use `group.net.salatime.app`. The App Store provisioning profiles
must include that group, match the installed Apple Distribution certificate,
and remain valid for more than 24 hours. The app profile must also permit Apple
login and the app's Keychain group. Development, ad hoc and enterprise profiles
are rejected before compilation.

Create the matching app record in App Store Connect before uploading. Configure
the production account API to accept the native app's Apple audience and expose
`apple.enabled=true` and `apple.ios_enabled=true`. Upload runs require that
configuration both before compilation and immediately before contacting Apple's
upload service. Every build compiles with `SALATIME_APPLE_IOS_ENABLED=true`;
the API still controls whether the app offers Apple login at runtime.

## GitHub repository configuration

Set repository secrets through GitHub's encrypted secret interface:

| Secret | Value |
| --- | --- |
| `ASC_API_KEY_P8` | Raw PEM content of the App Store Connect API private key |
| `ASC_KEY_ID` | App Store Connect API key identifier |
| `ASC_ISSUER_ID` | App Store Connect issuer UUID |
| `IOS_DISTRIBUTION_P12_BASE64` | Single-line base64 of the Apple Distribution certificate and private key in PKCS#12 format |
| `IOS_DISTRIBUTION_P12_PASSWORD` | Password protecting that PKCS#12 file |
| `IOS_APP_PROFILE_BASE64` | Single-line base64 of the app's App Store provisioning profile |
| `IOS_WIDGET_PROFILE_BASE64` | Single-line base64 of the widget's App Store provisioning profile |

Set repository variable `IOS_TEAM_ID` to the Apple Developer team ID. The API
key needs permission to upload to the corresponding App Store Connect app.
Never paste key material into issues, logs, workflow inputs or this repository.

Google login remains disabled on iOS until its OAuth client is configured in
the production API. Once configured, set repository variable
`IOS_GOOGLE_REVERSED_CLIENT_ID` to its reversed URL scheme. The workflow compares
that scheme with the API's iOS client ID and only then enables the Google flag.
Before upload, both the archive and exported IPA must contain that exact Google
URL scheme once, with no placeholder, unresolved macro or alternate Google
scheme. A native `GIDClientID`, if present, must match the same iOS client.
Android provider settings are independent.

## Build and upload

Open the repository's Actions page, choose **iOS App Store release**, and run it
against the reviewed commit. Supply a build number that has never been uploaded
for this app version. The default `26` is only a starting value; increment it for
each upload. The app version comes from `pubspec.yaml`.

`upload_to_testflight=false` builds and saves the validated IPA without an
upload, including when the production API has not activated Apple login yet.
The workflow summary and `provider-configuration.json` explicitly record the
provider status. Such a run verifies compilation, native tests and signing;
it does not demonstrate an operational Apple login.

Set `upload_to_testflight=true` to validate with Apple and upload to App Store
Connect. This mode refuses to start when native Apple login is inactive and
reads the API again immediately before upload to prevent release after a
configuration change. Rebuild with a new build number after final account/code
configuration changes, then use that reviewed build for distribution.
There are no push or pull-request triggers. The concurrency group queues release
runs instead of cancelling an upload already in progress.

The IPA, provider configuration status and public signing report are retained
as build artifacts for seven days. Private keys, the PKCS#12 file and unembedded profile copies are held in
`RUNNER_TEMP`; an `always()` cleanup removes them and restores the runner's
keychain search list. No raw signing material is included as a CI artifact.
An IPA necessarily contains its signed distribution profiles and public
certificates, as required by iOS.

Successful upload means Apple accepted the transfer. Check processing status,
TestFlight availability and installation separately. Public App Store release
also requires listing metadata, screenshots, privacy answers, review submission
and Apple's approval. A successful CI build does not verify physical-device
Apple login, reminder delivery, location/compass behavior or widget refresh.
Use the iOS compatibility checklist for those device checks.

## Local checks without a Mac

Run `python3 tool/ios_release.py self-test` to check profile rejection safeguards
and `ruby -c tool/ios_release_signing.rb` to check Ruby syntax. macOS and real
signing material are needed to validate a signed archive and IPA.

Sources: [Flutter iOS deployment](https://docs.flutter.dev/deployment/ios),
[GitHub signing on macOS runners](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications),
[Apple build uploads](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

## Private iPhone installation for build 27

The manually dispatched `ios-adhoc-device.yml` workflow is deliberately limited
to App Store build 27 from successful run `35165814554` and its reviewed source
commit. It reuses the same distribution certificate and two single-device ad hoc
profiles (`IOS_ADHOC_APP_PROFILE_BASE64`, `IOS_ADHOC_WIDGET_PROFILE_BASE64`). It
preserves executable code, resources, bundle IDs, versions, Google callback,
Apple login, App Group and Keychain capabilities. Only signing and embedded
profiles change. It does not upload to App Store Connect.

Because an ad hoc profile contains a device identifier, only an encrypted IPA
and a sanitized validation report are retained, for one day. Encryption uses
AES-256-GCM with a random salt/nonce and PBKDF2-HMAC-SHA256 (600,000 iterations);
the report is authenticated as associated data. The random password is supplied
through `IOS_ADHOC_ARTIFACT_PASSWORD` and stored locally in a private directory.
Remove that GitHub secret after the verified artifact has been recovered.

`python3 tool/ios_adhoc.py self-test` checks entitlement restrictions, single-device
profiles, encryption roundtrip and tamper rejection. Local decryption uses the
`decrypt` command with `ENCRYPTED_ARTIFACT_DIRECTORY`, `ADHOC_PASSWORD_FILE` and
`ADHOC_OUTPUT_IPA`; it authenticates the entire artifact before writing a file
with mode 600. Installation and actual device behavior are separate checks.

Sources: [Apple provisioning profiles](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles),
[Apple signature format](https://developer.apple.com/documentation/xcode/using-the-latest-code-signature-format),
[GitHub workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data),
[AES-GCM authenticated encryption](https://cryptography.io/en/latest/hazmat/primitives/aead/).
