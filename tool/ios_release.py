#!/usr/bin/env python3
"""Prepare ephemeral iOS signing, verify an exported IPA, and clean up.

Only the prepare command reads signing secrets. They are never written to the
repository, the public validation report, or stdout. macOS/Xcode are required
for prepare and verify. Pure profile validation is covered by --self-test.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shlex
import shutil
import subprocess
import tempfile
import zipfile
import urllib.request

APP_ID = "net.salatime.app"
WIDGET_ID = f"{APP_ID}.SalaTimeWidget"
APP_GROUP = f"group.{APP_ID}"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def run(*args: str) -> bytes:
    result = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        # Security/openssl errors can include arguments. Do not echo a command
        # line or native output while private signing material is in scope.
        raise RuntimeError(f"{Path(args[0]).name} failed (exit {result.returncode})")
    return result.stdout


def secret_file(path: Path, content: bytes) -> None:
    path.write_bytes(content)
    path.chmod(0o600)


def required_env(name: str) -> str:
    value = os.environ.get(name, "")
    require(bool(value), f"Missing required configuration: {name}")
    return value


def state_directory() -> Path:
    return Path(required_env("RUNNER_TEMP")) / "salatime-ios-signing"


def write_state(directory: Path, state: dict) -> None:
    secret_file(directory / "state.json", json.dumps(state).encode())


def check_profile(profile: dict, bundle_id: str, team_id: str) -> dict:
    entitlements = profile.get("Entitlements", {})
    require(profile.get("TeamIdentifier") == [team_id], "Provisioning profile has the wrong team")
    prefixes = profile.get("ApplicationIdentifierPrefix", [])
    require(len(prefixes) == 1, "Provisioning profile has no unique App ID prefix")
    require(entitlements.get("application-identifier") == f"{prefixes[0]}.{bundle_id}",
            f"Provisioning profile does not match {bundle_id}")
    require(entitlements.get("com.apple.developer.team-identifier") == team_id,
            "Provisioning profile entitlement has the wrong team")
    require(entitlements.get("get-task-allow") is False, "Development profiles cannot be released")
    require(not profile.get("ProvisionedDevices") and not profile.get("ProvisionsAllDevices"),
            "Expected an App Store distribution profile")
    require(APP_GROUP in entitlements.get("com.apple.security.application-groups", []),
            f"App Group missing from {bundle_id} profile")
    if bundle_id == APP_ID:
        require("Default" in entitlements.get("com.apple.developer.applesignin", []),
                "Sign in with Apple is missing from the app profile")
        groups = entitlements.get("keychain-access-groups", [])
        require(f"{prefixes[0]}.*" in groups or f"{prefixes[0]}.{APP_ID}" in groups,
                "App Keychain access is missing from the app profile")
    expires = profile.get("ExpirationDate")
    require(isinstance(expires, dt.datetime), "Provisioning profile has no expiry date")
    require(expires.replace(tzinfo=dt.timezone.utc) > dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=1),
            "Provisioning profile is expired or expires within 24 hours")
    uuid = profile.get("UUID", "")
    require(bool(re.fullmatch(r"[0-9A-Fa-f-]{36}", uuid)), "Invalid provisioning profile UUID")
    certificates = [hashlib.sha1(cert).hexdigest().upper() for cert in profile.get("DeveloperCertificates", [])]
    require(bool(certificates), "Provisioning profile contains no distribution certificate")
    return {"uuid": uuid, "bundle_id": bundle_id, "prefix": prefixes[0], "certificates": certificates}


def preflight(*, require_apple: bool = False) -> None:
    require(bool(re.fullmatch(r"[1-9][0-9]{0,3}(?:\.[0-9]{1,2}){0,2}", required_env("RELEASE_BUILD_NUMBER"))),
            "Build number must use Apple's numeric CFBundleVersion format")
    require(bool(re.fullmatch(r"[A-Z0-9]{10}", required_env("IOS_TEAM_ID"))), "Invalid IOS_TEAM_ID")
    request = urllib.request.Request("https://salatime.net/api/mobile/auth/config",
                                     headers={"Accept": "application/json", "User-Agent": "SalaTime-iOS-Release/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = json.load(response)["data"]
    apple_ready = (data.get("enabled") is True and data.get("apple", {}).get("enabled") is True and
                   data.get("apple", {}).get("ios_enabled") is True)
    reverse = os.environ.get("IOS_GOOGLE_REVERSED_CLIENT_ID", "")
    if reverse:
        google = data.get("google", {})
        client = google.get("ios_client_id", "")
        require(google.get("enabled") is True and bool(google.get("server_client_id")) and
                client.endswith(".apps.googleusercontent.com") and
                reverse == "com.googleusercontent.apps." + client.removesuffix(".apps.googleusercontent.com"),
                "Google iOS URL scheme does not match the enabled production API client")
    github_env = Path(required_env("GITHUB_ENV"))
    with github_env.open("a") as output:
        output.write(f"GOOGLE_IOS_ENABLED={'true' if reverse else 'false'}\n")
    report = {"checked_at": dt.datetime.now(dt.timezone.utc).isoformat(),
              "configuration_url": "https://salatime.net/api/mobile/auth/config",
              "apple_ios_ready": apple_ready, "google_ios_enabled": bool(reverse),
              "upload_requires_apple": require_apple,
              "mode": "upload" if require_apple else "build-only"}
    report_path = Path("build/ios/provider-configuration.json")
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n")
    status = "enabled" if apple_ready else "not active"
    message = (f"Production Apple login: {status}. Mode: {report['mode']}. "
               + ("Google iOS enabled." if reverse else "Google iOS disabled (not configured)."))
    print(message)
    if summary := os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(summary).open("a") as output:
            output.write(message + "\n\n")
            if not apple_ready and not require_apple:
                output.write("The signed IPA is for build validation. Apple login still needs server activation; "
                             "this run cannot upload to App Store Connect.\n\n")
    require(not require_apple or apple_ready,
            "Upload blocked: the production API must enable native Apple login")


def api_key() -> None:
    key_id = required_env("ASC_KEY_ID")
    require(bool(re.fullmatch(r"[A-Z0-9]{10}", key_id)), "Invalid ASC_KEY_ID")
    require(bool(re.fullmatch(r"[0-9a-fA-F-]{36}", required_env("ASC_ISSUER_ID"))), "Invalid ASC_ISSUER_ID")
    directory = state_directory() / "private_keys"
    directory.mkdir(mode=0o700, exist_ok=True)
    material = required_env("ASC_API_KEY_P8")
    require(material.startswith("-----BEGIN PRIVATE KEY-----") and "-----END PRIVATE KEY-----" in material,
            "ASC_API_KEY_P8 must contain the raw PEM private key")
    secret_file(directory / f"AuthKey_{key_id}.p8", material.encode())
    print("App Store Connect authentication prepared in the temporary signing directory.")


def prepare() -> None:
    team = required_env("IOS_TEAM_ID")
    require(bool(re.fullmatch(r"[A-Z0-9]{10}", team)), "IOS_TEAM_ID must be a ten-character Apple team ID")
    directory = state_directory()
    require(not directory.exists(), "Signing directory already exists; clean up the preceding attempt first")
    directory.mkdir(mode=0o700, parents=True)
    keychain = directory / "release.keychain-db"
    state = {"team_id": team, "profiles": {}, "installed_profiles": [], "keychain": str(keychain),
             "original_keychains": shlex.split(run("security", "list-keychains", "-d", "user").decode())}
    write_state(directory, state)
    for name, bundle, variable in [("Runner", APP_ID, "IOS_APP_PROFILE_BASE64"),
                                   ("SalaTimeWidget", WIDGET_ID, "IOS_WIDGET_PROFILE_BASE64")]:
        encoded = required_env(variable)
        profile_file = directory / f"{name}.mobileprovision"
        secret_file(profile_file, base64.b64decode(encoded, validate=True))
        profile = plistlib.loads(run("security", "cms", "-D", "-i", str(profile_file)))
        state["profiles"][name] = check_profile(profile, bundle, team)
        # Xcode 16+ uses the Developer path; the legacy directory also covers
        # tooling still resolving profiles through MobileDevice.
        for relative in ["Library/Developer/Xcode/UserData/Provisioning Profiles",
                         "Library/MobileDevice/Provisioning Profiles"]:
            target = Path.home() / relative / f"{profile['UUID']}.mobileprovision"
            target.parent.mkdir(parents=True, exist_ok=True)
            require(not target.exists(), "Refusing to overwrite an existing provisioning profile")
            state["installed_profiles"].append(str(target))
            write_state(directory, state)
            secret_file(target, profile_file.read_bytes())
    certificate = directory / "distribution.p12"
    secret_file(certificate, base64.b64decode(required_env("IOS_DISTRIBUTION_P12_BASE64"), validate=True))
    password = secrets.token_urlsafe(36)
    run("security", "create-keychain", "-p", password, str(keychain))
    run("security", "set-keychain-settings", "-lut", "21600", str(keychain))
    run("security", "unlock-keychain", "-p", password, str(keychain))
    run("security", "import", str(certificate), "-P", required_env("IOS_DISTRIBUTION_P12_PASSWORD"),
        "-t", "cert", "-f", "pkcs12", "-k", str(keychain), "-T", "/usr/bin/codesign", "-T", "/usr/bin/security")
    run("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password, str(keychain))
    run("security", "list-keychains", "-d", "user", "-s", str(keychain), *state["original_keychains"])
    identities = run("security", "find-identity", "-v", "-p", "codesigning", str(keychain)).decode()
    valid = set(re.findall(r'\b([A-F0-9]{40})\b(?=\s+"Apple Distribution:)', identities))
    matching = valid.intersection(*(set(profile["certificates"]) for profile in state["profiles"].values()))
    require(len(matching) == 1, "Both profiles must contain the installed Apple Distribution identity")
    state["certificate_sha1"] = next(iter(matching))
    state["google_reversed_client_id"] = os.environ.get("IOS_GOOGLE_REVERSED_CLIENT_ID", "")
    if state["google_reversed_client_id"]:
        require(bool(re.fullmatch(r"com\.googleusercontent\.apps\.[A-Za-z0-9-]+", state["google_reversed_client_id"])),
                "Invalid Google reversed client ID")
    write_state(directory, state)
    options = {"method": "app-store-connect", "destination": "export", "teamID": team,
               "signingStyle": "manual", "signingCertificate": state["certificate_sha1"],
               "provisioningProfiles": {profile["bundle_id"]: profile["uuid"] for profile in state["profiles"].values()},
               "manageAppVersionAndBuildNumber": False, "stripSwiftSymbols": True, "uploadSymbols": True}
    secret_file(directory / "ExportOptions.plist", plistlib.dumps(options))
    print("App Store signing prepared: both profiles, certificate, App Group and Apple login validated.")


def verify() -> None:
    state = json.loads((state_directory() / "state.json").read_text())
    archives = list(Path("build/ios/archive").glob("*.xcarchive/Products/Applications/*.app"))
    require(len(archives) == 1, "Expected exactly one archived iPhone app")
    packages = list(Path("build/ios/ipa").glob("*.ipa"))
    require(len(packages) == 1, "Expected exactly one exported IPA")
    report = {"team_id": state["team_id"], "app_group": APP_GROUP, "targets": {},
              "provider_configuration": json.loads(Path("build/ios/provider-configuration.json").read_text())}
    # Check the archive as well as the exported IPA: export may re-sign bundles.
    with tempfile.TemporaryDirectory(prefix="salatime-ipa-", dir=state_directory()) as unpacked:
        with zipfile.ZipFile(packages[0]) as package:
            require(all(not Path(name).is_absolute() and ".." not in Path(name).parts for name in package.namelist()),
                    "IPA contains an unsafe path")
        run("ditto", "-x", "-k", str(packages[0]), unpacked)
        apps = list((Path(unpacked) / "Payload").glob("*.app"))
        require(len(apps) == 1, "IPA must contain exactly one app")
        for location, app in [("archive", archives[0]), ("ipa", apps[0])]:
            widget = app / "PlugIns/SalaTimeWidget.appex"
            require(widget.is_dir(), "Widget extension is missing")
            run("codesign", "--verify", "--deep", "--strict", str(app))
            for name, bundle, expected in [("Runner", app, APP_ID), ("SalaTimeWidget", widget, WIDGET_ID)]:
                info = plistlib.loads((bundle / "Info.plist").read_bytes())
                require(info.get("CFBundleIdentifier") == expected, f"Unexpected bundle ID in {name}")
                entitlements = plistlib.loads(run("codesign", "-d", "--entitlements", ":-", str(bundle)))
                profile = plistlib.loads(run("security", "cms", "-D", "-i", str(bundle / "embedded.mobileprovision")))
                checked = check_profile(profile, expected, state["team_id"])
                require(checked["uuid"] == state["profiles"][name]["uuid"], "Unexpected signing profile")
                require(entitlements.get("application-identifier") == f"{checked['prefix']}.{expected}",
                        "Signed app identifier is incorrect")
                require(entitlements.get("com.apple.developer.team-identifier") == state["team_id"],
                        "Signed team identifier is incorrect")
                require(entitlements.get("get-task-allow") is False, "Release app allows debugging")
                require(entitlements.get("com.apple.security.application-groups") == [APP_GROUP],
                        "Signed App Group is incorrect")
                if name == "Runner":
                    require(entitlements.get("com.apple.developer.applesignin") == ["Default"],
                            "Signed app is missing Sign in with Apple")
                    require(f"{checked['prefix']}.{APP_ID}" in entitlements.get("keychain-access-groups", []),
                            "Signed app has no expected Keychain group")
                report["targets"][f"{location}/{name}"] = {"bundle_id": expected,
                    "version": info["CFBundleShortVersionString"], "build": info["CFBundleVersion"]}
    require(len({item["version"] for item in report["targets"].values()}) == 1 and
            len({item["build"] for item in report["targets"].values()}) == 1,
            "App and widget versions must match in the archive and IPA")
    Path("build/ios/release-validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print("Signed archive and IPA verified: app/widget IDs, versions, profiles, App Group, Keychain and Apple login.")


def cleanup() -> None:
    directory = state_directory()
    if not directory.exists():
        return
    state_path = directory / "state.json"
    failed = False
    if state_path.exists():
        state = json.loads(state_path.read_text())
        try:
            run("security", "list-keychains", "-d", "user", "-s", *state.get("original_keychains", []))
        except RuntimeError:
            failed = True
        keychain = Path(state["keychain"])
        if keychain.exists():
            try:
                run("security", "delete-keychain", str(keychain))
            except RuntimeError:
                failed = True
        for profile in state.get("installed_profiles", []):
            Path(profile).unlink(missing_ok=True)
    shutil.rmtree(directory)
    require(not failed, "Sensitive files removed, but keychain cleanup reported an error")
    print("Temporary signing files, profiles and keychain removed.")


def self_test() -> None:
    """Exercise release-blocking profile checks without secrets or Apple tools."""
    import copy
    team = "TESTTEAM12"
    profile = {"TeamIdentifier": [team], "ApplicationIdentifierPrefix": [team],
               "UUID": "00000000-0000-0000-0000-000000000001", "DeveloperCertificates": [b"fixture"],
               "ExpirationDate": dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=7),
               "Entitlements": {"application-identifier": f"{team}.{APP_ID}",
                   "com.apple.developer.team-identifier": team, "get-task-allow": False,
                   "com.apple.security.application-groups": [APP_GROUP],
                   "com.apple.developer.applesignin": ["Default"], "keychain-access-groups": [f"{team}.*"]}}
    check_profile(profile, APP_ID, team)
    invalid = []
    for key, value in [("get-task-allow", True), ("application-identifier", f"{team}.*"),
                       ("com.apple.security.application-groups", []), ("com.apple.developer.applesignin", []),
                       ("keychain-access-groups", [])]:
        changed = copy.deepcopy(profile)
        changed["Entitlements"][key] = value
        invalid.append(changed)
    for key, value in [("ProvisionedDevices", ["device"]), ("ProvisionsAllDevices", True),
                       ("TeamIdentifier", ["OTHERTEAM1"]), ("DeveloperCertificates", []),
                       ("ExpirationDate", dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=1))]:
        changed = copy.deepcopy(profile)
        changed[key] = value
        invalid.append(changed)
    for changed in invalid:
        try:
            check_profile(changed, APP_ID, team)
        except ValueError:
            continue
        raise AssertionError("Invalid provisioning profile was accepted")
    print(f"Profile safeguards passed: one valid profile and {len(invalid)} invalid profiles.")
    # Publishing is an external side effect: test both modes and a provider
    # being disabled between the initial preflight and the final upload guard.
    import contextlib
    import io
    from unittest import mock
    original_directory = Path.cwd()
    with tempfile.TemporaryDirectory(prefix="salatime-release-tests-") as temporary:
        try:
            os.chdir(temporary)
            fixture_env = {"RELEASE_BUILD_NUMBER": "26", "IOS_TEAM_ID": team,
                           "IOS_GOOGLE_REVERSED_CLIENT_ID": "", "GITHUB_ENV": str(Path(temporary) / "env"),
                           "GITHUB_STEP_SUMMARY": str(Path(temporary) / "summary")}
            for enabled, strict, accepted in [(False, False, True), (False, True, False),
                                               (True, False, True), (True, True, True),
                                               (False, True, False)]:
                payload = {"data": {"enabled": True, "apple": {"enabled": enabled, "ios_enabled": enabled}}}
                with mock.patch.dict(os.environ, fixture_env), mock.patch.object(
                        urllib.request, "urlopen", return_value=io.BytesIO(json.dumps(payload).encode())), \
                        contextlib.redirect_stdout(io.StringIO()):
                    rejected = False
                    try:
                        preflight(require_apple=strict)
                    except ValueError as error:
                        require(str(error).startswith("Upload blocked:"), "Unexpected preflight failure")
                        rejected = True
                    require(rejected is not accepted, "Apple upload guard accepted an unsafe mode")
                    report = json.loads(Path("build/ios/provider-configuration.json").read_text())
                    require(report["apple_ios_ready"] == enabled and report["upload_requires_apple"] == strict,
                            "Provider status report does not match the verified API state")
        finally:
            os.chdir(original_directory)
    print("Release modes passed: build-only accepts inactive Apple; initial/final upload guards refuse it.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["preflight", "api-key", "prepare", "verify", "cleanup", "self-test"])
    parser.add_argument("--require-apple", action="store_true",
                        help="Block preflight unless production native Apple login is active")
    args = parser.parse_args()
    try:
        {"preflight": lambda: preflight(require_apple=args.require_apple),
         "api-key": api_key, "prepare": prepare, "verify": verify,
         "cleanup": cleanup, "self-test": self_test}[args.command]()
    except (ValueError, RuntimeError, OSError, plistlib.InvalidFileException, KeyError) as error:
        # Exception details never include secret values or subprocess arguments.
        parser.exit(1, f"iOS release: {error}\n")
