#!/usr/bin/env python3
"""Set the native Analytics build guard on Runner's compiled Info.plist.

Invoked by Xcode's Thin Binary phase, after plist processing and before signing.
Debug/Profile deactivate Analytics even if a previous SDK preference enabled it;
Release leaves the runtime collection choice available. For deliberate DebugView
tests, pass --dart-define=SALATIME_ANALYTICS_DEBUG=true to Flutter (or set the
Xcode environment SALATIME_ANALYTICS_DEBUG=1 as well as the Dart define).

This script needs only Python's standard library. Its Linux tests prove the plist
mutation, not the order or result of an unexecuted Xcode archive.
"""

import argparse
import base64
import binascii
import os
import pathlib
import plistlib
import stat
import tempfile


DEACTIVATED_KEY = 'FIREBASE_ANALYTICS_COLLECTION_DEACTIVATED'


def build_mode(environment):
    """Match Flutter xcode_backend's mode priority and custom configuration names."""
    value = environment.get('FLUTTER_BUILD_MODE')
    if value is None:
        value = environment.get('CONFIGURATION', '')
    lowered = value.lower()
    for mode in ('release', 'profile', 'debug'):
        if mode in lowered:
            return mode
    raise ValueError('Unknown Flutter/Xcode build mode; Analytics guard not changed')


def debug_override(environment):
    if environment.get('SALATIME_ANALYTICS_DEBUG', '').lower() in ('true', '1'):
        return True
    override = False
    for encoded in environment.get('DART_DEFINES', '').split(','):
        if not encoded:
            continue
        try:
            define = base64.b64decode(encoded, validate=True).decode('utf-8')
        except (binascii.Error, UnicodeDecodeError) as error:
            raise ValueError('Invalid DART_DEFINES; Analytics guard not changed') from error
        key, separator, value = define.partition('=')
        if separator and key == 'SALATIME_ANALYTICS_DEBUG':
            # Dart's bool.fromEnvironment accepts the literal "true" only.
            override = value == 'true'
    return override


def configure_plist(path, environment):
    mode = build_mode(environment)
    deactivated = mode != 'release' and not debug_override(environment)
    path = pathlib.Path(path)
    original = path.read_bytes()
    info = plistlib.loads(original)
    if not isinstance(info, dict):
        raise ValueError('Compiled Info.plist must contain a dictionary')
    if info.get(DEACTIVATED_KEY) is deactivated:
        return deactivated

    info[DEACTIVATED_KEY] = deactivated
    output_format = (
        plistlib.FMT_BINARY if original.startswith(b'bplist00') else plistlib.FMT_XML
    )
    content = plistlib.dumps(info, fmt=output_format, sort_keys=False)
    permissions = stat.S_IMODE(path.stat().st_mode)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode='wb', prefix='.analytics-plist-', dir=path.parent, delete=False
        ) as stream:
            temporary_path = pathlib.Path(stream.name)
            stream.write(content)
        temporary_path.chmod(permissions)
        os.replace(temporary_path, path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
    return deactivated


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--info-plist', type=pathlib.Path, required=True)
    options = parser.parse_args()
    try:
        deactivated = configure_plist(options.info_plist, os.environ)
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        parser.exit(1, f'error: iOS Analytics guard: {error}\n')
    print(f'iOS Analytics native deactivated: {str(deactivated).lower()}')


if __name__ == '__main__':
    main()
