#!/usr/bin/env python3
"""Regenerate the offline prayer timezone database from a pinned IANA release.

Requires zic, Dart and a resolved Flutter package_config.json. The runtime
package stays compatible with flutter_local_notifications; only data changes.
"""
import argparse
import base64
import hashlib
import io
import json
import re
import shutil
import subprocess
import tarfile
import tempfile
import textwrap
import urllib.parse
import urllib.request
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--dart', default='dart')
    args = parser.parse_args()
    if not re.fullmatch(r'20\d\d[a-z]', args.version):
        parser.error('Expected an IANA version such as 2026d')
    root = Path(__file__).resolve().parents[1]
    config_path = root / '.dart_tool/package_config.json'
    config = json.loads(config_path.read_text())
    package = next(p for p in config['packages'] if p['name'] == 'timezone')
    uri = urllib.parse.urljoin(config_path.as_uri(), package['rootUri'])
    package_path = Path(urllib.parse.unquote(urllib.parse.urlparse(uri).path))
    url = f'https://data.iana.org/time-zones/releases/tzdata{args.version}.tar.gz'
    data = urllib.request.urlopen(url, timeout=60).read()
    source_hash = hashlib.sha256(data).hexdigest()
    files = ['africa', 'antarctica', 'asia', 'australasia', 'etcetera',
             'europe', 'northamerica', 'southamerica', 'backward']
    output = root / 'lib/data/timezone'
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='salatime-tz-') as directory:
        temp = Path(directory)
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            for name in files + ['version', 'LICENSE']:
                (temp / name).write_bytes(archive.extractfile(name).read())
        if (temp / 'version').read_text().strip() != args.version:
            raise ValueError('IANA archive version mismatch')
        subprocess.run(['zic', '-b', 'fat', '-d', str(temp / 'zoneinfo'),
                        *[str(temp / name) for name in files]], check=True)
        subprocess.run([
            args.dart, f'--packages={config_path}',
            str(package_path / 'tool/encode_tzf.dart'),
            '--zoneinfo', str(temp / 'zoneinfo'),
            '--output-all', str(temp / 'all.tzf'),
            '--output-common', str(temp / 'common.tzf'),
            '--output-10y', str(temp / '10y.tzf'),
        ], check=True, cwd=root)
        tzf = (temp / 'all.tzf').read_bytes()
        embedded = ''.join(f"    '{line}'\n" for line in textwrap.wrap(
            base64.b64encode(tzf).decode(), 100))
        (output / 'iana.dart').write_text(
            f'// Generated from IANA tzdata {args.version}. See docs/timezones.md.\n'
            "import 'dart:convert';\nimport 'package:timezone/timezone.dart' as tz;\n\n"
            f"const version = '{args.version}';\n"
            'void initializeTimeZones() => tz.initializeDatabase(base64Decode(_data));\n\n'
            'const _data =\n' + embedded + '    ;\n')
        shutil.copyfile(temp / 'LICENSE', output / 'LICENSE')
        (output / 'provenance.json').write_text(json.dumps({
            'version': args.version, 'source': url, 'source_sha256': source_hash,
            'tzf_sha256': hashlib.sha256(tzf).hexdigest(),
            'encoder': 'Locked timezone tool/encode_tzf.dart; zic -b fat',
        }, indent=2) + '\n')
    subprocess.run([args.dart, 'format', str(output / 'iana.dart')], check=True)
    print(f'Generated {args.version}; archive SHA256 {source_hash}')


if __name__ == '__main__':
    main()
