#!/usr/bin/env python3
"""Submit the exact SalaTime rating release from CI without logging private data.

Only --submit mutates App Store Connect. --preflight is GET-only. New versions
inherit Apple's metadata; preservation is verified before creating any review
submission. No review password/contact, signing key, JWT or raw API body is saved.
"""
from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

APP_ID = '6812923710'
BUNDLE_ID = 'net.salatime.app'
API = 'https://api.appstoreconnect.apple.com'
LOCALIZATION_FIELDS = ('description', 'keywords', 'marketingUrl', 'supportUrl', 'promotionalText')
REVIEW_FIELDS = ('contactFirstName', 'contactLastName', 'contactPhone', 'contactEmail',
                 'demoAccountName', 'demoAccountPassword', 'demoAccountRequired')
EDITABLE = {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED',
            'METADATA_REJECTED', 'READY_FOR_REVIEW'}
SUBMITTED = {'WAITING_FOR_REVIEW', 'IN_REVIEW', 'PENDING_DEVELOPER_RELEASE',
             'PENDING_APPLE_RELEASE', 'PROCESSING_FOR_APP_STORE', 'READY_FOR_SALE',
             'READY_FOR_DISTRIBUTION'}
WHATS_NEW = {
    'fr-FR': 'Demande de notation native après plusieurs jours d’utilisation et accès direct à la page d’avis depuis les paramètres.',
    'en-US': 'Native rating requests after several days of use and direct access to the store review page from Settings.',
    'ar-SA': 'طلب التقييم عبر واجهة المتجر الأصلية بعد عدة أيام من الاستخدام، والوصول مباشرةً إلى صفحة التقييم من الإعدادات.',
}
REVIEW_NOTE = ('Rating update: the automatic request uses Apple StoreKit after three distinct '
               'calendar usage days and 72 hours, following ten quiet seconds on Home. '
               'There is no custom prompt or satisfaction question. StoreKit controls display '
               'and does not display review requests in TestFlight. Settings > Rate SalaTime '
               'opens the App Store write-review page immediately.')


class ReleaseError(RuntimeError):
    """Messages are fixed, public release diagnostics, never server details."""


class APIError(ReleaseError):
    def __init__(self, status, body=b''):
        self.status = status
        try:
            errors = json.loads(body).get('errors', [])
            codes = [e.get('code', '') for e in errors]
            codes = [c for c in codes if isinstance(c, str) and re.fullmatch(r'[A-Z0-9_.-]+', c)]
        except (ValueError, TypeError, AttributeError):
            codes = []
        super().__init__(f'App Store Connect HTTP {status}; codes={",".join(codes) or "unavailable"}')


def require(condition, message):
    if not condition:
        raise ReleaseError(message)


def b64url(value):
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode('ascii')


def der_signature_to_raw(der):
    # P-256 signatures contain exactly two ASN.1 INTEGERs in a short SEQUENCE.
    require(len(der) >= 8 and der[0] == 0x30 and der[1] == len(der) - 2,
            'Invalid ES256 signature sequence')
    offset, values = 2, []
    for _ in range(2):
        require(offset + 2 <= len(der) and der[offset] == 2, 'Invalid ES256 signature integer')
        size = der[offset + 1]
        value = der[offset + 2:offset + 2 + size]
        require(len(value) == size and size > 0 and not value[0] & 0x80,
                'Invalid ES256 signature value')
        value = value.lstrip(b'\x00')
        require(len(value) <= 32, 'ES256 signature exceeds P-256 size')
        values.append(value.rjust(32, b'\x00'))
        offset += size + 2
    require(offset == len(der), 'Trailing ES256 signature data')
    return b''.join(values)


class TokenSigner:
    def __init__(self, private_key, key_id, issuer_id):
        require(bool(re.fullmatch(r'[A-Z0-9]{10}', key_id)), 'Invalid ASC key identifier')
        require(bool(re.fullmatch(r'[a-fA-F0-9-]{36}', issuer_id)), 'Invalid ASC issuer identifier')
        self.key_id, self.issuer_id = key_id, issuer_id
        self.directory = tempfile.TemporaryDirectory(prefix='salatime-asc-')
        self.path = Path(self.directory.name) / 'key.p8'
        self.path.write_bytes(private_key)
        self.path.chmod(0o600)

    def close(self):
        self.directory.cleanup()

    def token(self):
        now = int(time.time())
        header = b64url(json.dumps({'alg': 'ES256', 'kid': self.key_id, 'typ': 'JWT'}).encode())
        claims = b64url(json.dumps({'iss': self.issuer_id, 'iat': now, 'exp': now + 120,
                                   'aud': 'appstoreconnect-v1'}).encode())
        message = f'{header}.{claims}'.encode()
        result = subprocess.run(['openssl', 'dgst', '-sha256', '-sign', str(self.path)],
                                input=message, capture_output=True)
        require(result.returncode == 0, 'Apple API authentication signing failed')
        return f'{header}.{claims}.{b64url(der_signature_to_raw(result.stdout))}'


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file_pointer, code, message, headers, new_url):
        raise ReleaseError('App Store Connect redirects are not permitted')


class Client:
    def __init__(self, signer, opener=None, sleep=time.sleep):
        self.signer, self.opener, self.sleep = signer, opener or urllib.request.build_opener(NoRedirect()).open, sleep
        self.deadline = None

    def request(self, method, path, payload=None):
        url = urllib.parse.urljoin(API, path)
        parsed = urllib.parse.urlsplit(url)
        require(parsed.scheme == 'https' and parsed.netloc == 'api.appstoreconnect.apple.com'
                and parsed.path.startswith('/v1/'), 'Unexpected App Store Connect endpoint')
        body = json.dumps(payload).encode() if payload is not None else None
        # Retry reads only. An ambiguous mutation is reconciled by the next run,
        # never blindly repeated with potentially duplicate POST resources.
        for attempt in range(4 if method == 'GET' else 1):
            remaining = self.deadline - time.monotonic() if self.deadline is not None else 30
            require(remaining > 0, 'Apple build processing wait reached its time limit')
            request = urllib.request.Request(url, data=body, method=method,
                                            headers={'Authorization': 'Bearer ' + self.signer.token(),
                                                     'Content-Type': 'application/json'})
            try:
                with self.opener(request, timeout=min(30, remaining)) as response:
                    raw = response.read()
                    return json.loads(raw) if raw else {}
            except urllib.error.HTTPError as error:
                raw = error.read()
                if method == 'GET' and error.code in (429, 500, 502, 503, 504) and attempt < 3:
                    self.sleep(min(2 ** attempt, max(0, self.deadline - time.monotonic()))
                               if self.deadline is not None else 2 ** attempt)
                    continue
                raise APIError(error.code, raw) from None
            except (urllib.error.URLError, TimeoutError, OSError):
                if method == 'GET' and attempt < 3:
                    self.sleep(min(2 ** attempt, max(0, self.deadline - time.monotonic()))
                               if self.deadline is not None else 2 ** attempt)
                    continue
                raise ReleaseError('App Store Connect connection failed; rerun to reconcile state') from None
        raise ReleaseError('App Store Connect read retry limit reached')

    def get(self, path):
        return self.request('GET', path)

    def rows(self, path):
        rows = []
        for _ in range(20):
            response = self.get(path)
            rows.extend(response.get('data', []))
            path = response.get('links', {}).get('next')
            if not path:
                return rows
        raise ReleaseError('App Store Connect pagination limit reached')


def resource(kind, identifier=None, attributes=None, relationships=None):
    data = {'type': kind}
    if identifier is not None:
        data['id'] = identifier
    if attributes is not None:
        data['attributes'] = attributes
    if relationships is not None:
        data['relationships'] = relationships
    return {'data': data}


def relation(kind, identifier):
    return {'data': {'type': kind, 'id': identifier}}


def related_id(row, name):
    return (row.get('relationships', {}).get(name, {}).get('data') or {}).get('id')


def query(path, **parameters):
    return path + '?' + urllib.parse.urlencode(parameters)


def verify_source_version(version, path=Path('pubspec.yaml')):
    match = re.search(r'^version:\s*([^+\s]+)', path.read_text(), re.MULTILINE)
    require(match is not None and match[1] == version,
            'Local Flutter version does not match the requested App Store release')


def asset_signature(rows):
    result = []
    for row in rows:
        attributes = row['attributes']
        require(attributes.get('assetDeliveryState', {}).get('state') == 'COMPLETE',
                'Inherited review asset is not complete')
        checksum = attributes.get('sourceFileChecksum')
        require(bool(checksum), 'Inherited review asset has no source checksum')
        result.append((attributes.get('fileName'), attributes.get('fileSize'), checksum.lower()))
    return result


class Submission:
    def __init__(self, api, version, build_number, previous_version='1.0.27',
                 wait_seconds=1200, sleep=time.sleep, clock=time.monotonic, receipt=None):
        require(bool(re.fullmatch(r'\d+\.\d+\.\d+', version)), 'Invalid release version')
        require(bool(re.fullmatch(r'\d+\.\d+\.\d+', previous_version)), 'Invalid previous version')
        require(tuple(map(int, version.split('.'))) > tuple(map(int, previous_version.split('.'))),
                'Release version must increase')
        require(bool(re.fullmatch(r'[1-9]\d*', build_number)), 'Invalid build number')
        require(0 <= wait_seconds <= 1200, 'Processing wait exceeds twenty minutes')
        self.api, self.version, self.build_number = api, version, build_number
        self.previous_version, self.wait_seconds = previous_version, wait_seconds
        self.sleep, self.clock = sleep, clock
        self.report = {'app_id': APP_ID, 'bundle_id': BUNDLE_ID, 'version': version,
                       'build_number': build_number, 'source_commit': os.environ.get('GITHUB_SHA'),
                       'status': 'started', 'stage': 'preflight'}
        self.receipt = receipt

    def save(self, **values):
        self.report.update(values)
        if self.receipt:
            self.receipt.parent.mkdir(parents=True, exist_ok=True)
            self.receipt.write_text(json.dumps(self.report, ensure_ascii=False, indent=2) + '\n')

    def versions(self):
        return self.api.rows(query(f'/v1/apps/{APP_ID}/appStoreVersions',
                                   **{'filter[platform]': 'IOS', 'limit': 200}))

    def target_build(self):
        response = self.api.get(query('/v1/builds', **{'filter[app]': APP_ID,
                                'filter[version]': self.build_number,
                                'include': 'preReleaseVersion', 'limit': 200}))
        require(not response.get('links', {}).get('next'), 'Exact build query requires pagination')
        versions = {row['id']: (row['attributes'].get('version'), row['attributes'].get('platform'))
                    for row in response.get('included', []) if row['type'] == 'preReleaseVersions'}
        matches = []
        for row in response.get('data', []):
            if row['attributes'].get('version') != self.build_number:
                continue
            pre_id = related_id(row, 'preReleaseVersion')
            if pre_id not in versions:
                pre = self.api.get(f'/v1/builds/{row["id"]}/preReleaseVersion')['data']
                versions[pre_id] = (pre['attributes'].get('version'), pre['attributes'].get('platform'))
            if versions[pre_id] == (self.version, 'IOS'):
                matches.append(row)
        require(len(matches) <= 1, 'Multiple builds match requested version and number')
        return matches[0] if matches else None

    def preflight(self, for_upload=False):
        app = self.api.get(f'/v1/apps/{APP_ID}')['data']
        require(app['attributes'].get('bundleId') == BUNDLE_ID, 'Apple app bundle identifier mismatch')
        versions = self.versions()
        previous = [row for row in versions if row['attributes'].get('versionString') == self.previous_version]
        require(len(previous) == 1, 'Expected one previous public iOS version')
        target = [row for row in versions if row['attributes'].get('versionString') == self.version]
        require(len(target) <= 1, 'Multiple target App Store versions')
        previous_state = previous[0]['attributes'].get('appStoreState')
        require(previous_state in ('READY_FOR_SALE', 'READY_FOR_DISTRIBUTION') or
                (previous_state == 'REPLACED_WITH_NEW_VERSION' and target and
                 target[0]['attributes'].get('appStoreState') in SUBMITTED),
                'Previous iOS version is not ready for distribution')
        build = self.target_build()
        all_builds = self.api.rows(query('/v1/builds', **{'filter[app]': APP_ID, 'limit': 200}))
        codes = [int(row['attributes']['version']) for row in all_builds
                 if str(row.get('attributes', {}).get('version', '')).isdigit()]
        self.save(status='preflight_complete', previous_version_id=previous[0]['id'],
                  version_id=target[0]['id'] if target else None,
                  versions=[{'version': r['attributes'].get('versionString'),
                             'state': r['attributes'].get('appStoreState')} for r in versions],
                  maximum_uploaded_build=max(codes, default=0),
                  exact_build_id=build['id'] if build else None,
                  exact_build_state=build['attributes'].get('processingState') if build else None)
        if for_upload:
            require(build is None, 'Exact target build already exists; do not upload it again')
            require(int(self.build_number) > max(codes, default=0), 'Build number does not exceed existing uploads')
        return previous[0], target[0] if target else None

    def wait_build(self):
        deadline = self.clock() + self.wait_seconds
        if isinstance(self.api, Client):
            self.api.deadline = deadline
        try:
            while True:
                build = self.target_build()
                state = build['attributes'].get('processingState') if build else 'NOT_VISIBLE'
                self.save(stage='apple_processing', status='waiting', exact_build_state=state,
                          exact_build_id=build['id'] if build else None)
                if state == 'VALID':
                    require(build['attributes'].get('expired') is not True, 'Exact build has expired')
                    return build
                require(state not in ('FAILED', 'INVALID'), 'Apple rejected processing of the exact build')
                if self.clock() >= deadline:
                    raise ReleaseError('Apple build processing remains pending; rerun submission after processing')
                self.sleep(min(30, max(0, deadline - self.clock())))
        finally:
            if isinstance(self.api, Client):
                self.api.deadline = None

    def metadata(self, version_id):
        localizations = self.api.rows(f'/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=200')
        locales = {}
        for localization in localizations:
            locale = localization['attributes']['locale']
            require(locale not in locales, 'Duplicate App Store localization')
            sets = self.api.rows(f'/v1/appStoreVersionLocalizations/{localization["id"]}/appScreenshotSets?limit=200')
            screenshots = {}
            for screenshot_set in sets:
                display = screenshot_set['attributes']['screenshotDisplayType']
                require(display not in screenshots, 'Duplicate App Store screenshot display type')
                screenshots[display] = asset_signature(self.api.rows(
                    f'/v1/appScreenshotSets/{screenshot_set["id"]}/appScreenshots?limit=200'))
            locales[locale] = {'row': localization, 'screenshots': screenshots}
        try:
            review = self.api.get(f'/v1/appStoreVersions/{version_id}/appStoreReviewDetail').get('data')
        except APIError as error:
            if error.status != 404:
                raise
            review = None
        attachments = asset_signature(self.api.rows(
            f'/v1/appStoreReviewDetails/{review["id"]}/appStoreReviewAttachments?limit=200')) if review else []
        return {'locales': locales, 'review': review, 'attachments': attachments}

    def preserve_metadata(self, source, target_id):
        require(set(source['locales']) == set(WHATS_NEW), 'Expected existing FR/EN/AR store localizations')
        require(source['review'] is not None, 'Previous review information is missing')
        expected_review = source['review']['attributes']
        require(all(expected_review.get(field) for field in ('contactFirstName', 'contactLastName',
                'contactEmail', 'contactPhone')), 'Previous review contact is incomplete')
        if expected_review.get('demoAccountRequired'):
            require(bool(expected_review.get('demoAccountName')) and bool(expected_review.get('demoAccountPassword')),
                    'Previous demo account information is incomplete')
        destination = self.metadata(target_id)
        require(not (set(destination['locales']) - set(source['locales'])),
                'Target version has unexpected localizations')
        for locale, original in source['locales'].items():
            attributes = original['row']['attributes']
            target = destination['locales'].get(locale)
            if target is None:
                # Apple normally inherits these; fill text only and verify the
                # assets before submitting. Never invent or replace screenshots.
                attrs = {'locale': locale, **{k: attributes[k] for k in LOCALIZATION_FIELDS if attributes.get(k) is not None}}
                self.api.request('POST', '/v1/appStoreVersionLocalizations', resource(
                    'appStoreVersionLocalizations', attributes=attrs,
                    relationships={'appStoreVersion': relation('appStoreVersions', target_id)}))
                destination = self.metadata(target_id)
                target = destination['locales'][locale]
            expected_screenshots = original['screenshots']
            require(any(expected_screenshots.values()), 'Previous localization has no complete screenshots')
            require(target['screenshots'] == expected_screenshots,
                    'Inherited screenshots differ or are missing; supply verified originals before submission')
            current = target['row']['attributes']
            updates = {}
            for field in LOCALIZATION_FIELDS:
                expected, actual = attributes.get(field), current.get(field)
                if expected != actual:
                    require(actual in (None, ''), 'Inherited localization metadata differs; review before submission')
                    updates[field] = expected
            if current.get('whatsNew') != WHATS_NEW[locale]:
                updates['whatsNew'] = WHATS_NEW[locale]
            if updates:
                self.api.request('PATCH', f'/v1/appStoreVersionLocalizations/{target["row"]["id"]}',
                                 resource('appStoreVersionLocalizations', target['row']['id'], updates))
        if destination['review'] is None:
            attrs = {k: expected_review[k] for k in (*REVIEW_FIELDS, 'notes') if expected_review.get(k) is not None}
            self.api.request('POST', '/v1/appStoreReviewDetails', resource('appStoreReviewDetails', attributes=attrs,
                             relationships={'appStoreVersion': relation('appStoreVersions', target_id)}))
            destination = self.metadata(target_id)
        review = destination['review']
        updates = {}
        for field in REVIEW_FIELDS:
            expected, actual = expected_review.get(field), review['attributes'].get(field)
            if expected != actual:
                require(actual in (None, ''), 'Inherited private review information differs; review before submission')
                updates[field] = expected
        notes = (expected_review.get('notes') or '').rstrip()
        inherited_attachments = destination['attachments']
        require(all(item in source['attachments'] for item in inherited_attachments),
                'Inherited review attachment does not match the previous version')
        history_note = ''
        if inherited_attachments != source['attachments']:
            history_note = (f'Historical review information from version {self.previous_version}: '
                            'any demonstration attachment mentioned below remains attached to that previous '
                            'version. This rating-only update does not add or replace a physical-device '
                            'demonstration. The previous demonstration links and limitations remain applicable.\n\n')
        expected_notes = history_note + notes + ('\n\n' if notes else '') + REVIEW_NOTE
        require(len(expected_notes) <= 4000, 'Preserved review notes exceed Apple limit; edit before submission')
        current_notes = review['attributes'].get('notes') or ''
        require(current_notes in (notes, expected_review.get('notes') or '', expected_notes, ''),
                'Target review notes differ; review before submission')
        if current_notes != expected_notes:
            updates['notes'] = expected_notes
        if updates:
            self.api.request('PATCH', f'/v1/appStoreReviewDetails/{review["id"]}',
                             resource('appStoreReviewDetails', review['id'], updates))
        # Re-read every text, ordered image checksum and private field before
        # creating a review submission. Private fields are never added to report.
        verified = self.metadata(target_id)
        for locale, original in source['locales'].items():
            target = verified['locales'][locale]
            require(target['screenshots'] == original['screenshots'], 'Screenshot preservation readback failed')
            require(all(target['row']['attributes'].get(f) == original['row']['attributes'].get(f)
                        for f in LOCALIZATION_FIELDS), 'Localization preservation readback failed')
            require(target['row']['attributes'].get('whatsNew') == WHATS_NEW[locale], 'Release notes readback failed')
        require(all(verified['review']['attributes'].get(f) == expected_review.get(f) for f in REVIEW_FIELDS),
                'Private review preservation readback failed')
        require(verified['review']['attributes'].get('notes') == expected_notes, 'Review note readback failed')
        require(verified['attachments'] == inherited_attachments, 'Review attachment preservation readback failed')
        signature = {locale: item['screenshots'] for locale, item in verified['locales'].items()}
        count = sum(len(rows) for item in signature.values() for rows in item.values())
        self.save(stage='metadata_verified', locales=sorted(signature), screenshot_count=count,
                  screenshot_signature=hashlib.sha256(json.dumps(signature, sort_keys=True).encode()).hexdigest(),
                  review_attachment_count=len(inherited_attachments),
                  historical_review_attachment_count=len(source['attachments']),
                  historical_attachments_inherited=inherited_attachments == source['attachments'],
                  previous_review_attachments_unchanged=True, review_contact_preserved=True,
                  demo_account_preserved=True, privacy_unchanged=True)

    def review_submission(self, target_id):
        submissions = self.api.rows(f'/v1/apps/{APP_ID}/reviewSubmissions?filter[platform]=IOS&limit=200')
        matching, empty = [], []
        for submission in submissions:
            state = submission['attributes'].get('state')
            if state not in ('READY_FOR_REVIEW', 'WAITING_FOR_REVIEW', 'IN_REVIEW'):
                continue
            items = self.api.rows(f'/v1/reviewSubmissions/{submission["id"]}/items?limit=200')
            ids = [related_id(item, 'appStoreVersion') for item in items]
            if target_id in ids:
                require(len(items) == 1, 'Review submission contains other items; review before submitting')
                matching.append(submission)
            elif items:
                raise ReleaseError('Another review submission is active; do not replace it automatically')
            elif state == 'READY_FOR_REVIEW':
                empty.append(submission)
        require(len(matching) <= 1 and len(empty) <= 1, 'Multiple active review submissions need inspection')
        if matching:
            return matching[0]
        if empty:
            submission = empty[0]
        else:
            submission = self.api.request('POST', '/v1/reviewSubmissions', resource('reviewSubmissions',
                attributes={'platform': 'IOS'}, relationships={'app': relation('apps', APP_ID)}))['data']
        self.save(stage='review_draft', review_submission_id=submission['id'])
        self.api.request('POST', '/v1/reviewSubmissionItems', resource('reviewSubmissionItems', relationships={
            'reviewSubmission': relation('reviewSubmissions', submission['id']),
            'appStoreVersion': relation('appStoreVersions', target_id)}))
        items = self.api.rows(f'/v1/reviewSubmissions/{submission["id"]}/items?limit=200')
        require(len(items) == 1 and related_id(items[0], 'appStoreVersion') == target_id,
                'Exact version review item readback failed')
        return submission

    def submit(self):
        previous, target = self.preflight()
        build = self.wait_build()
        if target and target['attributes'].get('appStoreState') in SUBMITTED:
            attached = self.api.get(f'/v1/appStoreVersions/{target["id"]}/build').get('data')
            require(attached and attached['id'] == build['id'], 'Already submitted version uses another build')
            self.save(stage='review_submission', status='already_submitted', version_id=target['id'],
                      app_store_state=target['attributes']['appStoreState'])
            return
        source = self.metadata(previous['id'])
        if target is None:
            attributes = {'platform': 'IOS', 'versionString': self.version, 'releaseType': 'AFTER_APPROVAL'}
            for field in ('copyright', 'usesIdfa'):
                if previous['attributes'].get(field) is not None:
                    attributes[field] = previous['attributes'][field]
            target = self.api.request('POST', '/v1/appStoreVersions', resource('appStoreVersions',
                        attributes=attributes, relationships={'app': relation('apps', APP_ID)}))['data']
        self.save(stage='version_ready', version_id=target['id'])
        require(target['attributes'].get('appStoreState') in EDITABLE, 'Target version is not editable')
        require(target['attributes'].get('releaseType') == 'AFTER_APPROVAL',
                'Target release settings differ; review before submission')
        for field in ('copyright', 'usesIdfa'):
            require(target['attributes'].get(field) == previous['attributes'].get(field),
                    'Target version metadata differs from previous version')
        self.preserve_metadata(source, target['id'])
        attached = self.api.get(f'/v1/appStoreVersions/{target["id"]}/build').get('data')
        if not attached or attached['id'] != build['id']:
            require(target['attributes'].get('appStoreState') != 'READY_FOR_REVIEW',
                    'Ready-for-review version uses another build; review before replacing it')
            self.api.request('PATCH', f'/v1/appStoreVersions/{target["id"]}/relationships/build',
                             {'data': {'type': 'builds', 'id': build['id']}})
        attached = self.api.get(f'/v1/appStoreVersions/{target["id"]}/build').get('data')
        require(attached and attached['id'] == build['id'], 'Exact build attachment readback failed')
        submission = self.review_submission(target['id'])
        self.save(stage='review_submission', review_submission_id=submission['id'])
        if submission['attributes'].get('state') == 'READY_FOR_REVIEW':
            self.api.request('PATCH', f'/v1/reviewSubmissions/{submission["id"]}',
                             resource('reviewSubmissions', submission['id'], {'submitted': True}))
        readback = self.api.get(f'/v1/reviewSubmissions/{submission["id"]}')['data']
        version = self.api.get(f'/v1/appStoreVersions/{target["id"]}')['data']
        state = readback['attributes'].get('state')
        require(state in ('WAITING_FOR_REVIEW', 'IN_REVIEW', 'COMPLETE'), 'Apple submission is not confirmed')
        self.save(status='submitted', submission_state=state,
                  app_store_state=version['attributes'].get('appStoreState'), release_type='AFTER_APPROVAL')


def self_test():
    import unittest

    class FakeClient:
        def __init__(self, mismatched_images=False, build_version='1.0.28', inherit_attachments=True):
            self.calls, self.target, self.attached, self.submission, self.items = [], None, None, None, []
            self.previous = {'id': 'old', 'attributes': {'versionString': '1.0.27',
                'appStoreState': 'READY_FOR_SALE', 'copyright': 'SalaTime', 'usesIdfa': False}}
            self.build = {'id': 'build38', 'attributes': {'version': '38', 'processingState': 'VALID', 'expired': False},
                          'relationships': {'preReleaseVersion': relation('preReleaseVersions', 'pre') }}
            self.build_version, self.mismatched_images = build_version, mismatched_images
            self.inherit_attachments = inherit_attachments
            self.locales, self.reviews = {}, {}
            for version in ('old', 'new'):
                self.locales[version] = [ {'id': version + '-' + locale,
                    'attributes': {'locale': locale, 'description': 'Existing description', 'keywords': 'existing',
                                   'supportUrl': 'https://salatime.net', 'marketingUrl': None,
                                   'promotionalText': None, 'whatsNew': 'Old release'}} for locale in WHATS_NEW]
                self.reviews[version] = {'id': 'review-' + version, 'attributes': {
                    **dict.fromkeys(REVIEW_FIELDS, 'PRIVATE-DO-NOT-LOG'), 'demoAccountRequired': True, 'notes': 'Existing notes'}}

        def rows(self, path):
            return self.get(path)['data']

        def get(self, path):
            return self.request('GET', path)

        def request(self, method, path, payload=None):
            self.calls.append((method, path))
            base = urllib.parse.urlsplit(path).path
            if method == 'GET':
                if base == f'/v1/apps/{APP_ID}': return {'data': {'attributes': {'bundleId': BUNDLE_ID}}}
                if base.endswith('/appStoreVersions'): return {'data': [self.previous] + ([self.target] if self.target else [])}
                if base == '/v1/builds': return {'data': [self.build], 'included': [
                    {'id': 'pre', 'type': 'preReleaseVersions', 'attributes': {'version': self.build_version, 'platform': 'IOS'}}]}
                if base.endswith('/appStoreVersionLocalizations'):
                    return {'data': copy.deepcopy(self.locales[base.split('/')[3]])}
                if base.endswith('/appScreenshotSets'):
                    return {'data': [{'id': base.split('/')[3], 'attributes': {'screenshotDisplayType': 'APP_IPHONE_65'}}]}
                if base.endswith('/appScreenshots'):
                    checksum = 'bad' if self.mismatched_images and '/new-' in base else 'abc123'
                    return {'data': [{'attributes': {'fileName': 'existing.png', 'fileSize': 100,
                        'sourceFileChecksum': checksum, 'assetDeliveryState': {'state': 'COMPLETE'}}}]}
                if base.endswith('/appStoreReviewDetail'): return {'data': copy.deepcopy(self.reviews[base.split('/')[3]])}
                if base.endswith('/appStoreReviewAttachments'):
                    if base.split('/')[3] == 'review-new' and not self.inherit_attachments:
                        return {'data': []}
                    return {'data': [{'attributes': {'fileName': 'existing.pdf', 'fileSize': 10,
                        'sourceFileChecksum': '123abc', 'assetDeliveryState': {'state': 'COMPLETE'}}}]}
                if base.endswith('/build'):
                    return {'data': {**self.build, 'id': self.attached} if self.attached else None}
                if base.endswith('/reviewSubmissions'): return {'data': [self.submission] if self.submission else []}
                if base.endswith('/items'): return {'data': self.items}
                if base == '/v1/reviewSubmissions/submission': return {'data': self.submission}
                if base == '/v1/appStoreVersions/new': return {'data': self.target}
            elif method == 'POST':
                if base == '/v1/appStoreVersions':
                    self.target = {'id': 'new', 'attributes': {'appStoreState': 'PREPARE_FOR_SUBMISSION',
                                   **payload['data']['attributes']}}
                    return {'data': self.target}
                if base == '/v1/reviewSubmissions':
                    self.submission = {'id': 'submission', 'attributes': {'state': 'READY_FOR_REVIEW'}}
                    return {'data': self.submission}
                if base == '/v1/reviewSubmissionItems':
                    self.items = [payload['data']]
                    self.target['attributes']['appStoreState'] = 'READY_FOR_REVIEW'
                    return {'data': self.items[0]}
            elif method == 'PATCH':
                if base.startswith('/v1/appStoreVersionLocalizations/'):
                    for row in self.locales['new']:
                        if row['id'] == payload['data']['id']: row['attributes'].update(payload['data']['attributes'])
                    return {'data': payload['data']}
                if base == '/v1/appStoreReviewDetails/review-new':
                    self.reviews['new']['attributes'].update(payload['data']['attributes'])
                    return {'data': self.reviews['new']}
                if base.endswith('/relationships/build'):
                    self.attached = payload['data']['id']
                    return {}
                if base == '/v1/reviewSubmissions/submission':
                    self.submission['attributes']['state'] = 'WAITING_FOR_REVIEW'
                    self.target['attributes']['appStoreState'] = 'WAITING_FOR_REVIEW'
                    return {'data': self.submission}
            raise AssertionError(f'Unexpected fake operation {method} {base}')

    class Checks(unittest.TestCase):
        def test_es256_signature_is_verified_by_openssl(self):
            with tempfile.TemporaryDirectory() as directory:
                key = subprocess.run(['openssl', 'genpkey', '-algorithm', 'EC', '-pkeyopt', 'ec_paramgen_curve:P-256'],
                                     capture_output=True, check=True).stdout
                signer = TokenSigner(key, 'ABCDEFGHIJ', '00000000-0000-0000-0000-000000000000')
                try:
                    token = signer.token()
                    header, claims, signature = token.split('.')
                    raw = base64.urlsafe_b64decode(signature + '==')
                    self.assertEqual(len(raw), 64)
                    self.assertEqual(json.loads(base64.urlsafe_b64decode(claims + '=='))['aud'], 'appstoreconnect-v1')
                    integers = []
                    for value in (raw[:32], raw[32:]):
                        value = value.lstrip(b'\x00') or b'\x00'
                        if value[0] & 0x80: value = b'\x00' + value
                        integers.append(b'\x02' + bytes([len(value)]) + value)
                    encoded = b''.join(integers)
                    sig = Path(directory) / 'signature.der'; sig.write_bytes(b'\x30' + bytes([len(encoded)]) + encoded)
                    pub = Path(directory) / 'public.pem'
                    pub.write_bytes(subprocess.run(['openssl', 'pkey', '-in', str(signer.path), '-pubout'],
                                                   capture_output=True, check=True).stdout)
                    result = subprocess.run(['openssl', 'dgst', '-sha256', '-verify', str(pub), '-signature', str(sig)],
                                            input=f'{header}.{claims}'.encode(), capture_output=True)
                    self.assertEqual(result.returncode, 0)
                finally: signer.close()

        def test_read_only_preflight_and_duplicate_upload_guard(self):
            api = FakeClient(); flow = Submission(api, '1.0.28', '38')
            flow.preflight()
            self.assertTrue(all(method == 'GET' for method, _ in api.calls))
            self.assertEqual(flow.report['maximum_uploaded_build'], 38)
            with self.assertRaisesRegex(ReleaseError, 'already exists'): flow.preflight(for_upload=True)

        def test_exact_marketing_version_required(self):
            api = FakeClient(build_version='1.0.27')
            with self.assertRaisesRegex(ReleaseError, 'processing remains pending'):
                Submission(api, '1.0.28', '38', wait_seconds=0).submit()
            self.assertTrue(all(method == 'GET' for method, _ in api.calls))

        def test_source_version_guard_applies_to_resuming_submission(self):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / 'pubspec.yaml'
                path.write_text('name: salatime\nversion: 1.0.28+33\n')
                verify_source_version('1.0.28', path)
                with self.assertRaisesRegex(ReleaseError, 'Local Flutter version'):
                    verify_source_version('1.0.27', path)

        def test_submit_preserves_metadata_and_rerun_is_idempotent(self):
            api = FakeClient(); flow = Submission(api, '1.0.28', '38')
            original = copy.deepcopy(api.reviews['old'])
            flow.submit()
            self.assertEqual(flow.report['status'], 'submitted')
            self.assertEqual(flow.report['screenshot_count'], 3)
            self.assertNotIn('PRIVATE-DO-NOT-LOG', json.dumps(flow.report))
            self.assertEqual(api.reviews['old'], original)
            before = len(api.calls)
            rerun = Submission(api, '1.0.28', '38'); rerun.submit()
            self.assertEqual(rerun.report['status'], 'already_submitted')
            self.assertTrue(all(method == 'GET' for method, _ in api.calls[before:]))

        def test_missing_inherited_images_blocks_review_submission(self):
            api = FakeClient(mismatched_images=True)
            with self.assertRaisesRegex(ReleaseError, 'screenshots differ'):
                Submission(api, '1.0.28', '38').submit()
            self.assertFalse(any(method == 'POST' and path == '/v1/reviewSubmissions' for method, path in api.calls))

        def test_published_version_rerun_accepts_replaced_previous_version(self):
            api = FakeClient(); Submission(api, '1.0.28', '38').submit()
            api.previous['attributes']['appStoreState'] = 'REPLACED_WITH_NEW_VERSION'
            api.target['attributes']['appStoreState'] = 'READY_FOR_SALE'
            before = len(api.calls)
            flow = Submission(api, '1.0.28', '38'); flow.submit()
            self.assertEqual(flow.report['status'], 'already_submitted')
            self.assertTrue(all(method == 'GET' for method, _ in api.calls[before:]))
            api.attached = 'another-build'
            with self.assertRaisesRegex(ReleaseError, 'another build'):
                Submission(api, '1.0.28', '38').submit()

        def test_replaced_previous_version_cannot_prepare_another_submission(self):
            api = FakeClient()
            api.previous['attributes']['appStoreState'] = 'REPLACED_WITH_NEW_VERSION'
            with self.assertRaisesRegex(ReleaseError, 'not ready for distribution'):
                Submission(api, '1.0.28', '38').submit()
            self.assertTrue(all(method == 'GET' for method, _ in api.calls))

        def test_historical_attachment_stays_on_previous_version(self):
            api = FakeClient(inherit_attachments=False)
            original = copy.deepcopy(api.reviews['old'])
            flow = Submission(api, '1.0.28', '38'); flow.submit()
            self.assertEqual(flow.report['status'], 'submitted')
            self.assertFalse(flow.report['historical_attachments_inherited'])
            self.assertEqual(flow.report['review_attachment_count'], 0)
            self.assertEqual(api.reviews['old'], original)
            self.assertIn('remains attached to that previous version', api.reviews['new']['attributes']['notes'])
            self.assertFalse(any(method != 'GET' and 'appStoreReviewAttachments' in path for method, path in api.calls))

        def test_ready_review_draft_resumes_without_reattaching_build(self):
            api = FakeClient(); first = Submission(api, '1.0.28', '38')
            old_request = api.request
            failed = False
            def interrupt(method, path, payload=None):
                nonlocal failed
                if method == 'PATCH' and path == '/v1/reviewSubmissions/submission' and not failed:
                    failed = True
                    raise ReleaseError('Simulated interruption before submission')
                return old_request(method, path, payload)
            api.request = interrupt
            with self.assertRaisesRegex(ReleaseError, 'Simulated interruption'): first.submit()
            self.assertEqual(api.target['attributes']['appStoreState'], 'READY_FOR_REVIEW')
            before = len(api.calls)
            rerun = Submission(api, '1.0.28', '38'); rerun.submit()
            self.assertEqual(rerun.report['status'], 'submitted')
            self.assertFalse(any(method == 'POST' or path.endswith('/relationships/build')
                                 for method, path in api.calls[before:]))

        def test_api_error_never_logs_private_details_and_http_host_guard(self):
            error = APIError(422, json.dumps({'errors': [{'code': 'ENTITY_ERROR',
                            'detail': 'PRIVATE-PASSWORD'}]}).encode())
            self.assertNotIn('PRIVATE-PASSWORD', str(error))
            client = Client(None)
            with self.assertRaisesRegex(ReleaseError, 'Unexpected'):
                client.get('https://unrelated.example/v1/builds')
            with self.assertRaisesRegex(ReleaseError, 'Invalid ES256'):
                der_signature_to_raw(b'invalid')
            with self.assertRaisesRegex(ReleaseError, 'redirects'):
                NoRedirect().redirect_request(None, None, 302, '', {}, 'https://unrelated.example')

        def test_http_get_retries_but_post_is_not_repeated(self):
            class Signer:
                def token(self): return 'PRIVATE-JWT'
            attempts = []
            def opener(request, timeout):
                attempts.append(request.method)
                if len(attempts) < 2:
                    raise urllib.error.HTTPError(request.full_url, 503, 'error', {}, io.BytesIO(b'PRIVATE'))
                class Response:
                    def __enter__(self): return self
                    def __exit__(self, *args): return None
                    def read(self): return b'{"data": []}'
                return Response()
            client = Client(Signer(), opener=opener, sleep=lambda _: None)
            self.assertEqual(client.get('/v1/builds')['data'], [])
            self.assertEqual(attempts, ['GET', 'GET'])
            attempts.clear()
            with self.assertRaises(APIError): client.request('POST', '/v1/reviewSubmissions', {})
            self.assertEqual(attempts, ['POST'])

    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(Checks))
    require(result.wasSuccessful(), 'App Store submission self-tests failed')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--preflight', action='store_true')
    mode.add_argument('--submit', action='store_true')
    mode.add_argument('--self-test', action='store_true')
    parser.add_argument('--for-upload', action='store_true')
    parser.add_argument('--version', default='1.0.28')
    parser.add_argument('--previous-version', default='1.0.27')
    parser.add_argument('--build-number', default='38')
    parser.add_argument('--wait-seconds', type=int, default=1200)
    parser.add_argument('--receipt', type=Path, default=Path('build/ios/app-store-submission.json'))
    args = parser.parse_args()
    os.umask(0o077)
    if args.self_test:
        self_test()
        return
    require(not args.for_upload or args.preflight, '--for-upload requires --preflight')
    signer, flow = None, None
    try:
        verify_source_version(args.version)
        key_id = os.environ.get('ASC_KEY_ID', '')
        material = os.environ.get('ASC_API_KEY_P8')
        if material:
            private_key = material.encode()
        else:
            directory = os.environ.get('API_PRIVATE_KEYS_DIR', '')
            require(bool(directory), 'Apple API signing key is unavailable')
            private_key = (Path(directory) / f'AuthKey_{key_id}.p8').read_bytes()
        signer = TokenSigner(private_key, key_id, os.environ.get('ASC_ISSUER_ID', ''))
        flow = Submission(Client(signer), args.version, args.build_number,
                          args.previous_version, args.wait_seconds, receipt=args.receipt)
        if args.submit:
            flow.submit()
        else:
            flow.preflight(for_upload=args.for_upload)
        print(json.dumps(flow.report, ensure_ascii=False, indent=2))
    except Exception as error:
        message = str(error) if isinstance(error, ReleaseError) else 'Local submission operation failed: ' + type(error).__name__
        if flow:
            flow.save(status='blocked', error=message)
        else:
            args.receipt.parent.mkdir(parents=True, exist_ok=True)
            args.receipt.write_text(json.dumps({'status': 'blocked', 'stage': 'authentication', 'error': message}) + '\n')
        raise SystemExit(message) from None
    finally:
        if signer:
            signer.close()


if __name__ == '__main__':
    main()
