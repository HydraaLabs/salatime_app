#!/usr/bin/env python3
"""Validate native analytics safeguards in sources or assembled build files.

The default checks parse the app manifest and plist, not formatting or comments.
Pass --merged-manifest and/or --info-plist to verify Android/iOS build outputs.
This checks configuration only; actual SDK behavior still needs device testing.
"""

import argparse
import pathlib
import plistlib
import re
import xml.etree.ElementTree as ET


PROJECT = pathlib.Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'
TOOLS = '{http://schemas.android.com/tools}'
ANDROID_DISABLED = (
    'firebase_analytics_collection_enabled',
    'google_analytics_automatic_screen_reporting_enabled',
    'google_analytics_adid_collection_enabled',
    'google_analytics_default_allow_analytics_storage',
    'google_analytics_default_allow_ad_storage',
    'google_analytics_default_allow_ad_user_data',
    'google_analytics_default_allow_ad_personalization_signals',
)
IOS_DISABLED = (
    'FIREBASE_ANALYTICS_COLLECTION_ENABLED',
    'FirebaseAutomaticScreenReportingEnabled',
    'GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED',
    'GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE',
    'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE',
    'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA',
    'GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS',
)
AD_PERMISSIONS = (
    'com.google.android.gms.permission.AD_ID',
    'android.permission.ACCESS_ADSERVICES_AD_ID',
    'android.permission.ACCESS_ADSERVICES_ATTRIBUTION',
    'android.permission.ACCESS_ADSERVICES_TOPICS',
)


def check_manifest(path, *, merged=False):
    manifest = ET.parse(path).getroot()
    application = manifest.find('application')
    if application is None:
        raise ValueError(f'{path}: application missing')
    for key in ANDROID_DISABLED:
        matches = [
            tag for tag in application.findall('meta-data')
            if tag.get(ANDROID + 'name') == key
        ]
        if len(matches) != 1 or matches[0].get(ANDROID + 'value') != 'false':
            raise ValueError(f'{path}: {key} must have one false metadata value')
    permissions = (
        manifest.findall('uses-permission')
        + manifest.findall('uses-permission-sdk-23')
    )
    for key in AD_PERMISSIONS:
        matches = [tag for tag in permissions if tag.get(ANDROID + 'name') == key]
        if merged and matches:
            raise ValueError(f'{path}: advertising permission remains: {key}')
        if not merged and (
            len(matches) != 1 or matches[0].get(TOOLS + 'node') != 'remove'
        ):
            raise ValueError(f'{path}: {key} must be removed during manifest merge')


def check_plist(path, *, deactivated=None):
    with pathlib.Path(path).open('rb') as stream:
        info = plistlib.load(stream)
    for key in IOS_DISABLED:
        if info.get(key) is not False:
            raise ValueError(f'{path}: {key} must be a Boolean false')
    guard = info.get('FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED')
    if type(guard) is not bool or (deactivated is not None and guard is not deactivated):
        expected = 'a Boolean' if deactivated is None else f'Boolean {str(deactivated).lower()}'
        raise ValueError(f'{path}: FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED must be {expected}')


def check_podfile(path):
    active_lines = '\n'.join(
        line for line in pathlib.Path(path).read_text().splitlines()
        if not line.lstrip().startswith('#')
    )
    if not re.search(r'^\s*\$FirebaseAnalyticsWithoutAdIdSupport\s*=\s*true\s*$',
                     active_lines, re.MULTILINE):
        raise ValueError(f'{path}: FirebaseAnalyticsWithoutAdIdSupport not enabled')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--merged-manifest', type=pathlib.Path)
    parser.add_argument('--info-plist', type=pathlib.Path)
    parser.add_argument('--ios-deactivated', choices=('true', 'false'),
                        help='Expected compiled iOS guard (true for Debug/Profile by default)')
    options = parser.parse_args()
    check_manifest(PROJECT / 'android/app/src/main/AndroidManifest.xml')
    check_plist(PROJECT / 'ios/Runner/Info.plist', deactivated=False)
    check_podfile(PROJECT / 'ios/Podfile')
    if options.merged_manifest:
        check_manifest(options.merged_manifest, merged=True)
    if options.info_plist:
        expected = None if options.ios_deactivated is None else options.ios_deactivated == 'true'
        check_plist(options.info_plist, deactivated=expected)
    print('Analytics native privacy configuration passed.')


if __name__ == '__main__':
    main()
