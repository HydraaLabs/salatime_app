#!/usr/bin/env python3
"""Publish SalaTime Play Store localizations through Android Publisher API."""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import jwt
import requests


SCOPE = "https://www.googleapis.com/auth/androidpublisher"
TOKEN_URL = "https://oauth2.googleapis.com/token"
API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD_ROOT = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
IMAGE_TYPES = ("icon", "featureGraphic", "phoneScreenshots")


def fail(message: str) -> None:
    raise RuntimeError(message)


def checked(response: requests.Response) -> requests.Response:
    if not response.ok:
        fail(f"HTTP {response.status_code} {response.request.method} {response.url}: {response.text}")
    return response


def access_token(credentials_path: Path) -> str:
    credentials = json.loads(credentials_path.read_text(encoding="utf-8"))
    now = int(time.time())
    assertion = jwt.encode(
        {
            "iss": credentials["client_email"],
            "scope": SCOPE,
            "aud": TOKEN_URL,
            "iat": now,
            "exp": now + 3600,
        },
        credentials["private_key"],
        algorithm="RS256",
    )
    response = checked(
        requests.post(
            TOKEN_URL,
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": assertion,
            },
            timeout=30,
        )
    )
    return response.json()["access_token"]


def validate_local_data(listings: dict, root: Path, screenshots: Path, icon: Path) -> None:
    if len(listings) != 6:
        fail(f"Expected 6 new localizations, found {len(listings)}")
    for language, listing in listings.items():
        if len(listing["title"]) > 30:
            fail(f"{language}: title exceeds 30 characters")
        if len(listing["shortDescription"]) > 80:
            fail(f"{language}: short description exceeds 80 characters")
        if len(listing["fullDescription"]) > 4000:
            fail(f"{language}: full description exceeds 4000 characters")
        feature = root / language / "feature-graphic.png"
        if not feature.is_file():
            fail(f"Missing feature graphic: {feature}")
    if not icon.is_file():
        fail(f"Missing icon: {icon}")
    screenshot_files = sorted(screenshots.glob("*.png"))
    if len(screenshot_files) != 7:
        fail(f"Expected 7 screenshots, found {len(screenshot_files)} in {screenshots}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", required=True, type=Path)
    parser.add_argument("--package", default="net.salatime.app")
    parser.add_argument("--metadata", required=True, type=Path)
    parser.add_argument("--localized-assets", required=True, type=Path)
    parser.add_argument("--screenshots", required=True, type=Path)
    parser.add_argument("--icon", required=True, type=Path)
    args = parser.parse_args()

    listings = json.loads(args.metadata.read_text(encoding="utf-8"))
    validate_local_data(listings, args.localized_assets, args.screenshots, args.icon)
    screenshot_files = sorted(args.screenshots.glob("*.png"))

    token = access_token(args.credentials)
    session = requests.Session()
    session.headers.update({"Authorization": f"Bearer {token}"})
    edits_url = f"{API_ROOT}/{args.package}/edits"
    edit_id = checked(session.post(edits_url, json={}, timeout=30)).json()["id"]
    edit_url = f"{edits_url}/{edit_id}"
    committed = False

    try:
        print(f"Created Play edit {edit_id}")
        for language, listing in listings.items():
            listing_url = f"{edit_url}/listings/{language}"
            checked(session.put(listing_url, json=listing, timeout=30))
            print(f"[{language}] metadata uploaded")

            for image_type in IMAGE_TYPES:
                image_url = f"{listing_url}/{image_type}"
                checked(session.delete(image_url, timeout=30))

            uploads = [
                ("icon", args.icon),
                ("featureGraphic", args.localized_assets / language / "feature-graphic.png"),
                *(("phoneScreenshots", path) for path in screenshot_files),
            ]
            for image_type, path in uploads:
                image_url = (
                    f"{UPLOAD_ROOT}/{args.package}/edits/{edit_id}/listings/"
                    f"{language}/{image_type}?uploadType=media"
                )
                with path.open("rb") as handle:
                    response = checked(
                        session.post(
                            image_url,
                            data=handle,
                            headers={"Content-Type": "image/png"},
                            timeout=120,
                        )
                    )
                if not response.json().get("image", {}).get("id"):
                    fail(f"{language}: image upload returned no image id for {path.name}")
            print(f"[{language}] icon, feature graphic and 7 screenshots uploaded")

        replacements = {
            "en-US": (("German", "Persian"),),
            "fr-FR": (("allemand", "persan"), ("Allemand", "Persan")),
        }
        for language, pairs in replacements.items():
            listing_url = f"{edit_url}/listings/{language}"
            listing = checked(session.get(listing_url, timeout=30)).json()
            description = listing["fullDescription"]
            for old, new in pairs:
                description = description.replace(old, new)
            if description != listing["fullDescription"]:
                listing["fullDescription"] = description
                checked(session.put(listing_url, json=listing, timeout=30))
                print(f"[{language}] supported-language list corrected")

        checked(session.post(f"{edit_url}:validate", json={}, timeout=60))
        print("Play edit validated")
        checked(session.post(f"{edit_url}:commit", json={}, timeout=60))
        committed = True
        print("Play edit committed")
    finally:
        if not committed:
            try:
                session.delete(edit_url, timeout=30)
            except requests.RequestException:
                pass

    verify_id = checked(session.post(edits_url, json={}, timeout=30)).json()["id"]
    verify_url = f"{edits_url}/{verify_id}"
    try:
        remote_listings = checked(session.get(f"{verify_url}/listings", timeout=30)).json().get("listings", [])
        by_language = {item["language"]: item for item in remote_listings}
        for language in listings:
            remote = by_language.get(language)
            if not remote:
                fail(f"Readback failed: missing listing {language}")
            counts = {}
            for image_type in IMAGE_TYPES:
                image_response = checked(
                    session.get(f"{verify_url}/listings/{language}/{image_type}", timeout=30)
                ).json()
                counts[image_type] = len(image_response.get("images", []))
            if counts != {"icon": 1, "featureGraphic": 1, "phoneScreenshots": 7}:
                fail(f"Readback failed for {language}: {counts}")
            if remote["title"] != listings[language]["title"]:
                fail(f"Readback title mismatch for {language}")
            print(f"[{language}] readback OK: 1 icon, 1 feature graphic, 7 screenshots")
    finally:
        checked(session.delete(verify_url, timeout=30))

    print("All localized Play Store listings verified")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
