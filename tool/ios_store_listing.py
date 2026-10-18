#!/usr/bin/env python3
"""Read the public App Store listing text per locale (name, subtitle, keywords) — GET only."""
from __future__ import annotations

import json
import os

from ios_store_status import ReadOnlyClient
from ios_store_submission import APP_ID, TokenSigner, query, require


def listing(api):
    infos = api.rows(query(f'/v1/apps/{APP_ID}/appInfos', limit=20))
    result = {'app_infos': [], 'versions': []}
    for info in infos:
        locs = api.rows(query(f'/v1/appInfos/{info["id"]}/appInfoLocalizations', limit=50))
        result['app_infos'].append({
            'state': info['attributes'].get('appStoreState') or info['attributes'].get('state'),
            'localizations': [{'locale': l['attributes'].get('locale'), 'name': l['attributes'].get('name'),
                               'subtitle': l['attributes'].get('subtitle')} for l in locs]})
    versions = api.rows(query(f'/v1/apps/{APP_ID}/appStoreVersions', **{'filter[platform]': 'IOS', 'limit': 3}))
    for version in versions[:2]:
        locs = api.rows(query(f'/v1/appStoreVersions/{version["id"]}/appStoreVersionLocalizations', limit=50))
        result['versions'].append({
            'version': version['attributes'].get('versionString'), 'state': version['attributes'].get('appStoreState'),
            'localizations': [{'locale': l['attributes'].get('locale'), 'keywords': l['attributes'].get('keywords'),
                               'promotional_text': l['attributes'].get('promotionalText'),
                               'description': l['attributes'].get('description')} for l in locs]})
    return result


def main():
    material = os.environ.get('ASC_API_KEY_P8', '')
    require(bool(material), 'Apple API signing key is unavailable')
    signer = TokenSigner(material.encode(), os.environ.get('ASC_KEY_ID', ''), os.environ.get('ASC_ISSUER_ID', ''))
    try:
        result = listing(ReadOnlyClient(signer))
    finally:
        signer.close()
    os.makedirs('build/ios', exist_ok=True)
    with open('build/ios/app-store-listing.json', 'w') as handle:
        json.dump(result, handle, ensure_ascii=False, indent=2)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
