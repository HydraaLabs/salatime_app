#!/usr/bin/env python3
"""Replace SalaTime Play Store presentation images and localized screenshots."""

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
ALL_LANGUAGES = ("en-US", "fr-FR", "ar", "es-ES", "tr-TR", "ur", "id", "ms-MY", "bn-BD", "fa-AF")
SCREENSHOT_FOLDERS = {
    "en-US": "salatime-app-store-en",
    "fr-FR": "salatime-app-store-captures",
    "ar": "salatime-app-store-ar",
    "es-ES": "salatime-app-store-es",
}


def checked(response: requests.Response) -> requests.Response:
    if not response.ok:
        raise RuntimeError(
            f"HTTP {response.status_code} {response.request.method} {response.url}: {response.text}"
        )
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
    return checked(
        requests.post(
            TOKEN_URL,
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
                "assertion": assertion,
            },
            timeout=30,
        )
    ).json()["access_token"]


def upload_image(
    session: requests.Session,
    package: str,
    edit_id: str,
    language: str,
    image_type: str,
    path: Path,
) -> None:
    url = (
        f"{UPLOAD_ROOT}/{package}/edits/{edit_id}/listings/"
        f"{language}/{image_type}?uploadType=media"
    )
    with path.open("rb") as handle:
        response = checked(
            session.post(url, data=handle, headers={"Content-Type": "image/png"}, timeout=120)
        )
    if not response.json().get("image", {}).get("id"):
        raise RuntimeError(f"No image id returned for {language}/{image_type}/{path.name}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", required=True, type=Path)
    parser.add_argument("--package", default="net.salatime.app")
    parser.add_argument("--features", required=True, type=Path)
    parser.add_argument("--screenshots-root", required=True, type=Path)
    parser.add_argument("--skip-screenshots", action="store_true")
    args = parser.parse_args()

    for language in ALL_LANGUAGES:
        feature = args.features / language / "feature-graphic.png"
        if not feature.is_file():
            raise RuntimeError(f"Missing feature graphic: {feature}")
    screenshot_sets: dict[str, list[Path]] = {}
    if not args.skip_screenshots:
        for language, folder in SCREENSHOT_FOLDERS.items():
            files = sorted((args.screenshots_root / folder).glob("*.png"))
            if len(files) != 7:
                raise RuntimeError(f"Expected 7 screenshots for {language}, found {len(files)}")
            screenshot_sets[language] = files

    session = requests.Session()
    session.headers.update({"Authorization": f"Bearer {access_token(args.credentials)}"})
    edits_url = f"{API_ROOT}/{args.package}/edits"
    edit_id = checked(session.post(edits_url, json={}, timeout=30)).json()["id"]
    edit_url = f"{edits_url}/{edit_id}"
    committed = False

    try:
        print(f"Created Play edit {edit_id}", flush=True)
        for language in ALL_LANGUAGES:
            listing_url = f"{edit_url}/listings/{language}"
            checked(session.delete(f"{listing_url}/featureGraphic", timeout=30))
            upload_image(
                session,
                args.package,
                edit_id,
                language,
                "featureGraphic",
                args.features / language / "feature-graphic.png",
            )
            print(f"[{language}] presentation image replaced", flush=True)

        for language, files in screenshot_sets.items():
            listing_url = f"{edit_url}/listings/{language}"
            checked(session.delete(f"{listing_url}/phoneScreenshots", timeout=30))
            for path in files:
                upload_image(session, args.package, edit_id, language, "phoneScreenshots", path)
            print(f"[{language}] 7 localized screenshots replaced", flush=True)

        checked(session.post(f"{edit_url}:validate", json={}, timeout=60))
        checked(session.post(f"{edit_url}:commit", json={}, timeout=60))
        committed = True
        print("Play edit validated and committed", flush=True)
    finally:
        if not committed:
            try:
                session.delete(edit_url, timeout=30)
            except requests.RequestException:
                pass

    verify_id = checked(session.post(edits_url, json={}, timeout=30)).json()["id"]
    verify_url = f"{edits_url}/{verify_id}"
    try:
        for language in ALL_LANGUAGES:
            feature_count = len(
                checked(
                    session.get(f"{verify_url}/listings/{language}/featureGraphic", timeout=30)
                ).json().get("images", [])
            )
            screenshot_count = len(
                checked(
                    session.get(f"{verify_url}/listings/{language}/phoneScreenshots", timeout=30)
                ).json().get("images", [])
            )
            if feature_count != 1 or screenshot_count != 7:
                raise RuntimeError(
                    f"Readback failed for {language}: feature={feature_count}, screenshots={screenshot_count}"
                )
            print(f"[{language}] readback OK: 1 presentation image, 7 screenshots", flush=True)
    finally:
        checked(session.delete(verify_url, timeout=30))

    print("All Play Store images verified", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
