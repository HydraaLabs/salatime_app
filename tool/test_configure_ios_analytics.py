"""Run with python3 -m unittest discover -s tool -p test_configure_ios_analytics.py."""

import base64
import datetime
import json
import os
import pathlib
import plistlib
import re
import subprocess
import tempfile
import unittest

from configure_ios_analytics import (
    DEACTIVATED_KEY,
    build_mode,
    configure_plist,
)


def encoded_define(value):
    return base64.b64encode(value.encode('utf-8')).decode('ascii')


class ConfigureIOSAnalyticsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.path = pathlib.Path(self.temporary.name) / 'Info.plist'
        self.original = {
            'CFBundleIdentifier': 'net.salatime.app',
            'FIREBASE_ANALYTICS_COLLECTION_ENABLED': False,
            'Unrelated': {
                'Enabled': True,
                'Languages': ['fr', 'العربية'],
                'Data': b'\x00\x01\xff',
                'Date': datetime.datetime(2026, 10, 7, 12, 30),
                'Count': 7,
            },
        }

    def write_original(self, output_format=plistlib.FMT_XML):
        self.path.write_bytes(plistlib.dumps(self.original, fmt=output_format))
        self.path.chmod(0o640)

    def test_all_modes_preserve_unrelated_values_and_actual_boolean_type(self):
        for output_format in (plistlib.FMT_XML, plistlib.FMT_BINARY):
            for mode, expected in (('Debug', True), ('Profile', True), ('Release', False)):
                with self.subTest(format=output_format, mode=mode):
                    self.write_original(output_format)
                    self.assertIs(
                        configure_plist(self.path, {'CONFIGURATION': mode}), expected
                    )
                    result = plistlib.loads(self.path.read_bytes())
                    self.assertIs(result.pop(DEACTIVATED_KEY), expected)
                    self.assertEqual(result, self.original)
                    self.assertEqual(self.path.stat().st_mode & 0o777, 0o640)
                    self.assertEqual(
                        self.path.read_bytes().startswith(b'bplist00'),
                        output_format == plistlib.FMT_BINARY,
                    )

    def test_native_guard_overwrites_existing_or_string_like_build_values(self):
        for previous in (False, 'false', 1):
            with self.subTest(previous=previous):
                self.original[DEACTIVATED_KEY] = previous
                self.write_original()
                configure_plist(self.path, {'CONFIGURATION': 'Profile'})
                self.assertIs(plistlib.loads(self.path.read_bytes())[DEACTIVATED_KEY], True)

    def test_debug_override_from_flutter_define(self):
        for mode in ('Debug', 'Profile'):
            self.write_original()
            defines = ','.join((
                encoded_define('OTHER_SETTING=kept'),
                encoded_define('SALATIME_ANALYTICS_DEBUG=true'),
            ))
            configure_plist(self.path, {'CONFIGURATION': mode, 'DART_DEFINES': defines})
            self.assertIs(plistlib.loads(self.path.read_bytes())[DEACTIVATED_KEY], False)

    def test_false_or_non_boolean_dart_override_does_not_unlock(self):
        for value in ('false', '1', 'True'):
            self.write_original()
            configure_plist(self.path, {
                'CONFIGURATION': 'Debug',
                'DART_DEFINES': encoded_define(f'SALATIME_ANALYTICS_DEBUG={value}'),
            })
            self.assertIs(plistlib.loads(self.path.read_bytes())[DEACTIVATED_KEY], True)

    def test_xcode_override_and_flutter_build_mode_priority(self):
        self.write_original()
        configure_plist(self.path, {
            'FLUTTER_BUILD_MODE': 'profile',
            'CONFIGURATION': 'Release',
            'SALATIME_ANALYTICS_DEBUG': '1',
        })
        self.assertIs(plistlib.loads(self.path.read_bytes())[DEACTIVATED_KEY], False)
        self.assertEqual(build_mode({'CONFIGURATION': 'Debug-Custom'}), 'debug')
        self.assertEqual(build_mode({'FLUTTER_BUILD_MODE': 'profile', 'CONFIGURATION': 'Release'}), 'profile')

    def test_unsafe_configuration_errors_leave_original_untouched(self):
        for environment in (
            {'CONFIGURATION': 'Unknown'},
            {'CONFIGURATION': 'Debug', 'DART_DEFINES': 'not-base64'},
        ):
            self.write_original()
            before = self.path.read_bytes()
            with self.assertRaises(ValueError):
                configure_plist(self.path, environment)
            self.assertEqual(self.path.read_bytes(), before)

    def test_repeating_same_configuration_does_not_rewrite_plist(self):
        self.write_original()
        configure_plist(self.path, {'CONFIGURATION': 'Debug'})
        before = self.path.read_bytes()
        modified = self.path.stat().st_mtime_ns
        configure_plist(self.path, {'CONFIGURATION': 'Debug'})
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(self.path.stat().st_mtime_ns, modified)

    def test_actual_thin_binary_shell_runs_guard_and_propagates_backend_failure(self):
        # This executes the real phase on Linux with only Flutter embedding stubbed.
        # It checks quoting/order, but cannot substitute for an Xcode archive.
        project = pathlib.Path(__file__).resolve().parents[1]
        pbx = (project / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        phase = re.search(r'/\* Thin Binary \*/ = \{(.*?)\n\t\t\};', pbx, re.S)
        self.assertIsNotNone(phase)
        encoded_shell = re.search(r'shellScript = (".*");', phase.group(1)).group(1)
        shell = json.loads(encoded_shell)
        flutter_root = pathlib.Path(self.temporary.name) / 'Flutter SDK'
        backend = flutter_root / 'packages/flutter_tools/bin/xcode_backend.sh'
        backend.parent.mkdir(parents=True)
        environment = {
            'PATH': os.environ['PATH'],
            'FLUTTER_ROOT': str(flutter_root),
            'SRCROOT': str(project / 'ios'),
            'TARGET_BUILD_DIR': str(self.path.parent),
            'INFOPLIST_PATH': self.path.name,
            'CONFIGURATION': 'Debug',
        }
        for backend_status in (0, 7):
            with self.subTest(backend_status=backend_status):
                self.write_original()
                backend.write_text(f'test "$1" = embed_and_thin || exit 9\nexit {backend_status}\n')
                completed = subprocess.run(
                    ['/bin/sh', '-c', shell], env=environment,
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(completed.returncode, backend_status, completed.stderr)
                result = plistlib.loads(self.path.read_bytes())
                if backend_status == 0:
                    self.assertIs(result[DEACTIVATED_KEY], True)
                else:
                    self.assertNotIn(DEACTIVATED_KEY, result)


if __name__ == '__main__':
    unittest.main()
