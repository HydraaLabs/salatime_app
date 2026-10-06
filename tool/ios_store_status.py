#!/usr/bin/env python3
"""Read Apple version, build and review state without saving private metadata."""
from __future__ import annotations

import argparse
import datetime
import json
import os
from pathlib import Path

from ios_store_submission import (APP_ID, BUNDLE_ID, Client, ReleaseError,
                                  TokenSigner, query, related_id, require)


class ReadOnlyClient(Client):
    def request(self, method, path, payload=None):
        require(method == 'GET' and payload is None, 'Apple status checks permit GET only')
        return super().request(method, path)


def snapshot(api):
    app = api.get(f'/v1/apps/{APP_ID}')['data']
    require(app['attributes'].get('bundleId') == BUNDLE_ID, 'Apple app bundle identifier mismatch')
    versions = api.rows(query(f'/v1/apps/{APP_ID}/appStoreVersions',
                             **{'filter[platform]': 'IOS', 'limit': 200}))
    builds = api.rows(query('/v1/builds', **{'filter[app]': APP_ID, 'limit': 200}))
    build_rows = []
    for row in builds:
        pre = api.get(f'/v1/builds/{row["id"]}/preReleaseVersion')['data']
        build_rows.append({'id': row['id'], 'number': row['attributes'].get('version'),
                           'version': pre['attributes'].get('version'),
                           'platform': pre['attributes'].get('platform'),
                           'processing_state': row['attributes'].get('processingState'),
                           'expired': row['attributes'].get('expired')})
    version_rows = []
    for row in versions:
        attached = api.get(f'/v1/appStoreVersions/{row["id"]}/build').get('data')
        version_rows.append({'id': row['id'], 'version': row['attributes'].get('versionString'),
                             'state': row['attributes'].get('appStoreState'),
                             'release_type': row['attributes'].get('releaseType'),
                             'build_id': attached['id'] if attached else None,
                             'build_number': attached['attributes'].get('version') if attached else None})
    reviews = api.rows(query(f'/v1/apps/{APP_ID}/reviewSubmissions',
                            **{'filter[platform]': 'IOS', 'limit': 200}))
    review_rows = []
    for row in reviews:
        items = api.rows(query(f'/v1/reviewSubmissions/{row["id"]}/items',
                              include='appStoreVersion', limit=200))
        review_rows.append({'id': row['id'], 'state': row['attributes'].get('state'),
                            'platform': row['attributes'].get('platform'),
                            'items': [{'id': item['id'], 'state': item['attributes'].get('state'),
                                       'version_id': related_id(item, 'appStoreVersion')}
                                      for item in items]})
    numeric = [int(row['number']) for row in build_rows
               if str(row['number']).isdigit() and row['platform'] == 'IOS']
    return {'checked_at': datetime.datetime.now(datetime.UTC).isoformat(),
            'source_commit': os.environ.get('GITHUB_SHA'), 'status': 'read_only_verified',
            'app_id': APP_ID, 'bundle_id': BUNDLE_ID,
            'maximum_ios_build_number': max(numeric, default=0),
            'versions': version_rows, 'builds': build_rows, 'review_submissions': review_rows}


def self_test():
    import unittest

    class Checks(unittest.TestCase):
        def test_snapshot_whitelist_and_exact_relationship(self):
            class Fake:
                def get(self, path):
                    if path == f'/v1/apps/{APP_ID}':
                        return {'data': {'attributes': {'bundleId': BUNDLE_ID, 'private': 'PRIVATE'}}}
                    if '/preReleaseVersion' in path:
                        return {'data': {'attributes': {'version': '1.0.28', 'platform': 'IOS'}}}
                    if path.endswith('/build'):
                        return {'data': {'id': 'b38', 'attributes': {'version': '38', 'private': 'PRIVATE'}}}
                    raise AssertionError(path)
                def rows(self, path):
                    if '/appStoreVersions?' in path:
                        return [{'id': 'v28', 'attributes': {'versionString': '1.0.28',
                                'appStoreState': 'WAITING_FOR_REVIEW', 'releaseType': 'AFTER_APPROVAL',
                                'reviewNotes': 'PRIVATE'}}]
                    if path.startswith('/v1/builds?'):
                        return [{'id': 'b38', 'attributes': {'version': '38', 'processingState': 'VALID'}}]
                    if '/reviewSubmissions?' in path:
                        return [{'id': 'review', 'attributes': {'state': 'WAITING_FOR_REVIEW', 'platform': 'IOS'}}]
                    if '/items?' in path:
                        assert 'include=appStoreVersion' in path
                        return [{'id': 'item', 'attributes': {'state': 'READY_FOR_REVIEW', 'private': 'PRIVATE'},
                                 'relationships': {'appStoreVersion': {'data': {'id': 'v28'}}}}]
                    raise AssertionError(path)
            result = snapshot(Fake())
            self.assertNotIn('PRIVATE', json.dumps(result))
            self.assertEqual(result['maximum_ios_build_number'], 38)
            self.assertEqual(result['review_submissions'][0]['items'][0]['version_id'], 'v28')

        def test_mutations_and_payloads_are_rejected_before_authentication(self):
            class Signer:
                def token(self): raise AssertionError('Must not sign a mutation')
            api = ReadOnlyClient(Signer())
            for method, payload in [('POST', {}), ('PATCH', {}), ('DELETE', None), ('GET', {})]:
                with self.assertRaisesRegex(ReleaseError, 'GET only'):
                    api.request(method, '/v1/reviewSubmissions', payload)

    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks))
    require(result.wasSuccessful(), 'Apple status self-tests failed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--receipt', type=Path, default=Path('build/ios/app-store-status.json'))
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    os.umask(0o077)
    signer = None
    try:
        material = os.environ.get('ASC_API_KEY_P8', '')
        require(bool(material), 'Apple API signing key is unavailable')
        signer = TokenSigner(material.encode(), os.environ.get('ASC_KEY_ID', ''),
                             os.environ.get('ASC_ISSUER_ID', ''))
        result = snapshot(ReadOnlyClient(signer))
    except Exception as error:
        message = str(error) if isinstance(error, ReleaseError) else 'Apple status read failed: ' + type(error).__name__
        result = {'status': 'blocked', 'error': message}
    finally:
        if signer:
            signer.close()
    args.receipt.parent.mkdir(parents=True, exist_ok=True)
    args.receipt.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if result['status'] == 'blocked':
        raise SystemExit(1)


if __name__ == '__main__':
    main()
