#!/usr/bin/env python3
"""Re-sign the authorized App Store IPA for one registered test device.

Private profiles and the resulting IPA never leave RUNNER_TEMP unencrypted.
No source, resource, Info.plist or executable code may change during re-signing.
"""
from __future__ import annotations

import argparse
import base64
import copy
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shlex
import shutil
import zipfile

from ios_release import (APP_ID, APP_GROUP, WIDGET_ID, check_google_url_scheme,
                         check_profile, cleanup, require, required_env, run,
                         secret_file, state_directory, write_state)

SOURCE_RUN = 36065913929
SOURCE_SHA = "e8b1df346eb33a4fc42c5a9db0bb37b9ef8f2008"
BUILD = "35"
VERSION = "1.0.27"


def check_adhoc_profile(profile: dict, bundle: str, team: str) -> dict:
    devices = profile.get("ProvisionedDevices", [])
    require(len(devices) == 1 and isinstance(devices[0], str) and bool(devices[0]),
            "Expected exactly one registered device in each ad hoc profile")
    store_shape = copy.deepcopy(profile)
    del store_shape["ProvisionedDevices"]
    checked = check_profile(store_shape, bundle, team)
    checked["devices"] = devices
    return checked


def authorized(value: object, permission: object) -> bool:
    if isinstance(value, str) and isinstance(permission, str):
        return fnmatch.fnmatchcase(value, permission)
    if isinstance(value, list) and isinstance(permission, list):
        return all(any(authorized(item, allowed) for allowed in permission) for item in value)
    return type(value) is type(permission) and value == permission


def signing_entitlements(old: dict, profile: dict) -> dict:
    result = copy.deepcopy(old)
    permitted = profile["Entitlements"]
    # TestFlight's distribution entitlement has no meaning in an ad hoc profile.
    if "beta-reports-active" not in permitted:
        result.pop("beta-reports-active", None)
    require(all(key in permitted and authorized(value, permitted[key])
                for key, value in result.items()),
            "The ad hoc profile does not authorize the app's existing entitlements")
    return result


def code_hash(executable: Path, directory: Path) -> str:
    """Compare executable bytes after codesign removes only its signature."""
    temporary = directory / "signature-free-code"
    shutil.copy2(executable, temporary)
    run("codesign", "--remove-signature", str(temporary))
    digest = hashlib.sha256(temporary.read_bytes()).hexdigest()
    temporary.unlink()
    return digest


def content_manifest(app: Path, executables: set[Path]) -> dict:
    result = {}
    for path in sorted(app.rglob("*")):
        relative = path.relative_to(app)
        if "_CodeSignature" in relative.parts or path.name == "embedded.mobileprovision" or path in executables:
            continue
        if path.is_symlink():
            result[str(relative)] = {"symlink": os.readlink(path)}
        elif path.is_file():
            result[str(relative)] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    return result


def validate_source() -> None:
    metadata = json.loads(Path(required_env("SOURCE_RUN_METADATA")).read_text())
    require(metadata.get("id") == SOURCE_RUN and metadata.get("head_sha") == SOURCE_SHA and
            metadata.get("path") == ".github/workflows/ios-release.yml" and
            metadata.get("event") == "workflow_dispatch" and metadata.get("status") == "completed" and
            metadata.get("conclusion") == "success", "Source must be the successful authorized App Store release")
    print("Authorized App Store source run verified.")


def resign() -> None:
    validate_source()
    team = required_env("IOS_TEAM_ID")
    require(bool(re.fullmatch(r"[A-Z0-9]{10}", team)), "Invalid Apple team")
    directory = state_directory()
    require(not directory.exists(), "Signing state already exists")
    directory.mkdir(mode=0o700, parents=True)
    keychain = directory / "adhoc.keychain-db"
    state = {"keychain": str(keychain), "installed_profiles": [],
             "original_keychains": shlex.split(run("security", "list-keychains", "-d", "user").decode())}
    write_state(directory, state)
    profiles = {}
    for name, bundle, variable in [("app", APP_ID, "IOS_ADHOC_APP_PROFILE_BASE64"),
                                   ("widget", WIDGET_ID, "IOS_ADHOC_WIDGET_PROFILE_BASE64")]:
        path = directory / f"{name}.mobileprovision"
        secret_file(path, base64.b64decode(required_env(variable), validate=True))
        profile = plistlib.loads(run("security", "cms", "-D", "-i", str(path)))
        profiles[name] = (path, profile, check_adhoc_profile(profile, bundle, team))
    require(profiles["app"][2]["devices"] == profiles["widget"][2]["devices"],
            "The app and widget must authorize the same single registered device")
    certificate = directory / "distribution.p12"
    secret_file(certificate, base64.b64decode(required_env("IOS_DISTRIBUTION_P12_BASE64"), validate=True))
    password = secrets.token_urlsafe(36)
    run("security", "create-keychain", "-p", password, str(keychain))
    run("security", "set-keychain-settings", "-lut", "3600", str(keychain))
    run("security", "unlock-keychain", "-p", password, str(keychain))
    run("security", "import", str(certificate), "-P", required_env("IOS_DISTRIBUTION_P12_PASSWORD"),
        "-t", "cert", "-f", "pkcs12", "-k", str(keychain), "-T", "/usr/bin/codesign", "-T", "/usr/bin/security")
    run("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", password, str(keychain))
    run("security", "list-keychains", "-d", "user", "-s", str(keychain), *state["original_keychains"])
    identities = run("security", "find-identity", "-v", "-p", "codesigning", str(keychain)).decode()
    valid = set(re.findall(r'\b([A-F0-9]{40})\b(?=\s+"Apple Distribution:)', identities))
    matching = valid.intersection(*(set(item[2]["certificates"]) for item in profiles.values()))
    require(len(matching) == 1, "Profiles must authorize the installed distribution certificate")
    identity = next(iter(matching))
    sources = list(Path(required_env("SOURCE_ARTIFACT_DIRECTORY")).glob("ipa/*.ipa"))
    require(len(sources) == 1, "Expected exactly one source IPA")
    with zipfile.ZipFile(sources[0]) as package:
        require(all(not Path(name).is_absolute() and ".." not in Path(name).parts for name in package.namelist()),
                "Unsafe IPA path")
    unpacked = directory / "unpacked"
    run("ditto", "-x", "-k", str(sources[0]), str(unpacked))
    apps = list((unpacked / "Payload").glob("*.app"))
    require(len(apps) == 1, "Source IPA must have exactly one app")
    app = apps[0]
    widget = app / "PlugIns/SalaTimeWidget.appex"
    require(widget.is_dir(), "Widget extension is absent")
    run("codesign", "--verify", "--deep", "--strict", str(app))
    targets = []
    for name, bundle, expected in [("widget", widget, WIDGET_ID), ("app", app, APP_ID)]:
        info = plistlib.loads((bundle / "Info.plist").read_bytes())
        require(info.get("CFBundleIdentifier") == expected and info.get("CFBundleVersion") == BUILD and
                info.get("CFBundleShortVersionString") == VERSION, "Unexpected source bundle or version")
        if name == "app":
            check_google_url_scheme(info, required_env("IOS_GOOGLE_REVERSED_CLIENT_ID"))
        source_profile = plistlib.loads(run("security", "cms", "-D", "-i", str(bundle / "embedded.mobileprovision")))
        original = check_profile(source_profile, expected, team)
        require(original["prefix"] == profiles[name][2]["prefix"], "App ID prefix must remain unchanged")
        certificate_prefix = directory / f"{name}-original-certificate-"
        run("codesign", "-d", f"--extract-certificates={certificate_prefix}", str(bundle))
        original_certificate = Path(str(certificate_prefix) + "0").read_bytes()
        require(hashlib.sha1(original_certificate).hexdigest().upper() == identity,
                "Re-signing must use the exact source distribution certificate")
        old = plistlib.loads(run("codesign", "-d", "--entitlements", ":-", str(bundle)))
        require(old.get("application-identifier") == f"{original['prefix']}.{expected}" and
                old.get("com.apple.developer.team-identifier") == team and old.get("get-task-allow") is False and
                old.get("com.apple.security.application-groups") == [APP_GROUP], "Source capabilities differ")
        if name == "app":
            require(old.get("com.apple.developer.applesignin") == ["Default"] and
                    f"{original['prefix']}.{APP_ID}" in old.get("keychain-access-groups", []),
                    "Source Apple login or Keychain capability is absent")
        entitlements = signing_entitlements(old, profiles[name][1])
        executable_name = info["CFBundleExecutable"]
        require(Path(executable_name).name == executable_name, "Invalid executable path")
        executable = bundle / executable_name
        load_commands = run("otool", "-l", str(executable)).decode()
        require(all(value == "0" for value in re.findall(r"^\s*cryptid\s+(\d+)\s*$", load_commands, re.M)),
                "FairPlay-encrypted binaries cannot be re-signed for device testing")
        targets.append((name, bundle, executable, entitlements, code_hash(executable, directory)))
    before = content_manifest(app, {target[2] for target in targets})
    for name, bundle, executable, entitlements, original_code in targets:
        shutil.copyfile(profiles[name][0], bundle / "embedded.mobileprovision")
        entitlement_file = directory / f"{name}-entitlements.plist"
        secret_file(entitlement_file, plistlib.dumps(entitlements))
        run("codesign", "--force", "--sign", identity, "--keychain", str(keychain),
            "--entitlements", str(entitlement_file), "--generate-entitlement-der",
            "--preserve-metadata=identifier,requirements,flags,runtime", str(bundle))
        require(code_hash(executable, directory) == original_code, "Executable code changed during re-signing")
        actual = plistlib.loads(run("codesign", "-d", "--entitlements", ":-", str(bundle)))
        require(actual == entitlements, "Signed entitlements differ from the validated profile permissions")
        embedded = plistlib.loads(run("security", "cms", "-D", "-i", str(bundle / "embedded.mobileprovision")))
        require(embedded == profiles[name][1], "Unexpected embedded ad hoc profile")
        run("codesign", "--verify", "--deep", "--strict", str(bundle))
    require(content_manifest(app, {target[2] for target in targets}) == before,
            "An application resource or embedded framework changed during re-signing")
    result = directory / "SalaTime-AdHoc-34.ipa"
    run("ditto", "-c", "-k", "--keepParent", str(unpacked / "Payload"), str(result))
    output = Path(required_env("ENCRYPTED_ARTIFACT_DIRECTORY"))
    output.mkdir(mode=0o700, parents=True, exist_ok=True)
    report = {"source_run": SOURCE_RUN, "source_sha": SOURCE_SHA, "version": VERSION, "build": BUILD,
              "app_id": APP_ID, "widget_id": WIDGET_ID, "app_group": APP_GROUP,
              "registered_device_count": 1, "unchanged_code_and_resources": True,
              "ipa_sha256": hashlib.sha256(result.read_bytes()).hexdigest(),
              "encryption": "AES-256-GCM/PBKDF2-HMAC-SHA256/600000"}
    report_bytes = (json.dumps(report, indent=2) + "\n").encode()
    payload = result.read_bytes()
    sealed = seal(payload, required_env("IOS_ADHOC_ARTIFACT_PASSWORD").encode(), report_bytes)
    require(unseal(sealed, required_env("IOS_ADHOC_ARTIFACT_PASSWORD").encode(), report_bytes) == payload,
            "Private artifact encryption roundtrip failed")
    secret_file(output / "SalaTime-AdHoc-34.ipa.enc", sealed)
    (output / "validation.json").write_bytes(report_bytes)
    print("Ad hoc app and widget verified for one registered device; only the encrypted IPA and sanitized report will be uploaded.")


def seal(payload: bytes, password: bytes, report: bytes) -> bytes:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    require(len(password) >= 32, "Artifact encryption requires a strong random password")
    salt, nonce = secrets.token_bytes(16), secrets.token_bytes(12)
    header = b"STADHOC1" + salt + nonce
    key = hashlib.pbkdf2_hmac("sha256", password, salt, 600000, dklen=32)
    return header + AESGCM(key).encrypt(nonce, payload, header + report)


def unseal(sealed: bytes, password: bytes, report: bytes) -> bytes:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    require(sealed[:8] == b"STADHOC1" and len(sealed) >= 52, "Invalid encrypted artifact")
    header, salt, nonce = sealed[:36], sealed[8:24], sealed[24:36]
    key = hashlib.pbkdf2_hmac("sha256", password, salt, 600000, dklen=32)
    return AESGCM(key).decrypt(nonce, sealed[36:], header + report)


def decrypt() -> None:
    directory = Path(required_env("ENCRYPTED_ARTIFACT_DIRECTORY"))
    report_bytes = (directory / "validation.json").read_bytes()
    password = Path(required_env("ADHOC_PASSWORD_FILE")).read_bytes().strip()
    payload = unseal((directory / "SalaTime-AdHoc-34.ipa.enc").read_bytes(), password, report_bytes)
    report = json.loads(report_bytes)
    require(report.get("source_run") == SOURCE_RUN and report.get("source_sha") == SOURCE_SHA and
            report.get("build") == BUILD and report.get("ipa_sha256") == hashlib.sha256(payload).hexdigest(),
            "Decrypted artifact does not match the authorized release")
    destination = Path(required_env("ADHOC_OUTPUT_IPA"))
    require(not destination.exists(), "Refusing to overwrite an existing IPA")
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    secret_file(destination, payload)
    print("Authenticated device IPA decrypted and its digest verified in the private local directory.")


def self_test() -> None:
    require(authorized(["TEAM.bundle"], ["TEAM.*"]), "Wildcard Keychain permission was rejected")
    require(not authorized(["OTHER.bundle"], ["TEAM.*"]), "Unrelated Keychain permission accepted")
    require(not authorized(True, 1), "Boolean permission confused with integer")
    old = {"keychain-access-groups": ["TEAM.bundle"], "get-task-allow": False, "beta-reports-active": True}
    profile = {"Entitlements": {"keychain-access-groups": ["TEAM.*"], "get-task-allow": False}}
    require(signing_entitlements(old, profile) == {"keychain-access-groups": ["TEAM.bundle"], "get-task-allow": False},
            "Unexpected ad hoc entitlement conversion")
    try:
        signing_entitlements({**old, "unknown-capability": True}, profile)
    except ValueError:
        pass
    else:
        raise AssertionError("Unauthorized entitlement accepted")
    import datetime as dt
    profile_fixture = {"TeamIdentifier": ["TESTTEAM12"], "ApplicationIdentifierPrefix": ["TESTTEAM12"],
        "UUID": "00000000-0000-0000-0000-000000000001", "DeveloperCertificates": [b"fixture"],
        "ExpirationDate": dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=7),
        "ProvisionedDevices": ["private-test-device"],
        "Entitlements": {"application-identifier": f"TESTTEAM12.{APP_ID}",
            "com.apple.developer.team-identifier": "TESTTEAM12", "get-task-allow": False,
            "com.apple.security.application-groups": [APP_GROUP],
            "com.apple.developer.applesignin": ["Default"], "keychain-access-groups": ["TESTTEAM12.*"]}}
    check_adhoc_profile(profile_fixture, APP_ID, "TESTTEAM12")
    for devices in [[], ["first", "second"]]:
        try:
            check_adhoc_profile({**profile_fixture, "ProvisionedDevices": devices}, APP_ID, "TESTTEAM12")
        except ValueError:
            pass
        else:
            raise AssertionError("Non-single-device profile accepted")
    password, report = b"test-password-that-is-long-enough-12345", b'{"source":"test"}'
    sealed = seal(b"test IPA", password, report)
    require(unseal(sealed, password, report) == b"test IPA", "Encryption roundtrip failed")
    for changed, associated in [(sealed[:-1] + bytes([sealed[-1] ^ 1]), report), (sealed, b"changed report")]:
        try:
            unseal(changed, password, associated)
        except Exception as error:
            from cryptography.exceptions import InvalidTag
            require(isinstance(error, InvalidTag), "Unexpected authentication failure")
        else:
            raise AssertionError("Tampered encrypted artifact accepted")
    print("Ad hoc entitlement and authenticated encryption safeguards passed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["resign", "cleanup", "self-test", "decrypt"])
    args = parser.parse_args()
    {"resign": resign, "cleanup": cleanup, "self-test": self_test, "decrypt": decrypt}[args.command]()
