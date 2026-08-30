#!/usr/bin/env python3
"""Publish the six generated SalaTime screenshot localizations."""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

import jwt
import requests


LANGUAGES = ("tr-TR", "ur", "id", "ms-MY", "bn-BD", "fa-AF")
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
TOKEN_URL = "https://oauth2.googleapis.com/token"
API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD_ROOT = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"


def checked(response: requests.Response) -> requests.Response:
    if not response.ok:
        raise RuntimeError(
            f"HTTP {response.status_code} {response.request.method} {response.url}: {response.text}"
        )
    return response


def token(credentials_path: Path) -> str:
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--credentials", required=True, type=Path)
    parser.add_argument("--package", default="net.salatime.app")
    parser.add_argument("--assets-root", required=True, type=Path)
    args = parser.parse_args()

    screenshots: dict[str, list[Path]] = {}
    for language in LANGUAGES:
        files = sorted((args.assets_root / language / "phone-screenshots").glob("*.png"))
        if len(files) != 7:
            raise RuntimeError(f"Expected 7 screenshots for {language}, found {len(files)}")
        screenshots[language] = files

    session = requests.Session()
    session.headers.update({"Authorization": f"Bearer {token(args.credentials)}"})
    edits_url = f"{API_ROOT}/{args.package}/edits"
    edit_id = checked(session.post(edits_url, json={}, timeout=30)).json()["id"]
    edit_url = f"{edits_url}/{edit_id}"
    committed = False

    try:
        print(f"Created Play edit {edit_id}", flush=True)
        for language, files in screenshots.items():
            listing_url = f"{edit_url}/listings/{language}/phoneScreenshots"
            checked(session.delete(listing_url, timeout=30))
            upload_url = (
                f"{UPLOAD_ROOT}/{args.package}/edits/{edit_id}/listings/"
                f"{language}/phoneScreenshots?uploadType=media"
            )
            for path in files:
                with path.open("rb") as handle:
                    response = checked(
                        session.post(
                            upload_url,
                            data=handle,
                            headers={"Content-Type": "image/png"},
                            timeout=120,
                        )
                    )
                if not response.json().get("image", {}).get("id"):
                    raise RuntimeError(f"No image id returned for {language}/{path.name}")
            print(f"[{language}] 7 translated screenshots uploaded", flush=True)

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
        for language in LANGUAGES:
            images = checked(
                session.get(
                    f"{verify_url}/listings/{language}/phoneScreenshots",
                    timeout=30,
                )
            ).json().get("images", [])
            if len(images) != 7:
                raise RuntimeError(f"Readback failed for {language}: {len(images)} screenshots")
            print(f"[{language}] readback OK: 7 screenshots", flush=True)
    finally:
        checked(session.delete(verify_url, timeout=30))

    print("All generated screenshot localizations verified", flush=True)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
