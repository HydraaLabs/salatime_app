"""Collect native simulator pixels while real Flutter screens are visible."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys

from capture_ios_protocol import CaptureServer

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--output', required=True)
parser.add_argument('--collection', choices=['basic', 'play-style', 'light-home-reader'], default='basic')
parser.add_argument('--family', choices=['iphone', 'ipad'])
args = parser.parse_args()
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True)
features = ['01-prayer-times', '02-home-reading', '03-quran-list',
            '04-quran-reading', '05-nearby-mosques', '06-hadith-chapters',
            '07-name-generator']
expected = ({f'{locale}/{feature}' for locale in ['fr-FR', 'en-US', 'ar'] for feature in features}
            if args.collection == 'play-style' else
            {'01-prayer-times', '02-quran-al-fatiha', '03-athkar'})
if args.collection == 'light-home-reader':
    if args.family is None:
        parser.error('--family is required for a targeted capture')
    expected = {f'{locale}/01-prayer-times' for locale in ['fr-FR', 'en-US', 'ar']}
    if args.family == 'iphone':
        expected.add('fr-FR/04-quran-reading')
target = ('play_style_app_store_test.dart' if args.collection != 'basic'
          else 'app_store_test.dart')
command = ['flutter', 'drive', '--driver=test_driver/app_store.dart',
           '--target=integration_test/' + target, '-d', args.device,
           '--dart-define=SALATIME_SENTRY_DSN=']
captures = {}


def capture_native(name):
    if name not in expected:
        raise ValueError('Unexpected capture name: ' + name)
    if name in captures:
        return
    path = output / (name + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['xcrun', 'simctl', 'io', args.device, 'screenshot', str(path)],
                   check=True, timeout=90)
    raw = path.read_bytes()
    width, height = struct.unpack('>II', raw[16:24])
    if (width, height) not in {(1320, 2868), (1290, 2796), (1242, 2688), (2064, 2752), (2048, 2732)}:
        raise RuntimeError(f'Unexpected App Store screenshot dimensions: {width}x{height}')
    captures[name] = {'file': str(path.relative_to(output)), 'width': width, 'height': height,
                      'sha256': hashlib.sha256(raw).hexdigest()}


server = None
if args.collection != 'basic':
    server = CaptureServer(capture_native)
    server.start()
    command.extend([f'--dart-define=SALATIME_CAPTURE_PORT={server.port}',
                    f'--dart-define=SALATIME_CAPTURE_SET={args.collection}',
                    f'--dart-define=SALATIME_CAPTURE_READER={str(args.family == "iphone").lower()}'])
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, bufsize=1)
with (output / 'capture.log').open('w') as log:
    for line in process.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        log.write(line)
        log.flush()
        if 'SALATIME_STORE_PREPARE_LOCATION' in line and args.collection == 'play-style':
            subprocess.run(['xcrun', 'simctl', 'privacy', args.device, 'grant', 'location',
                            'net.salatime.app'], check=True, timeout=30)
            subprocess.run(['xcrun', 'simctl', 'location', args.device, 'set',
                            '34.0331,-5.0003'], check=True, timeout=30)
        match = re.search(r'SALATIME_STORE_CAPTURE:([A-Za-z0-9/-]+)', line)
        if server is not None or not match or match[1] in captures:
            continue
        name = match[1]
        if name not in expected:
            process.terminate()
            raise RuntimeError('Unexpected capture name: ' + name)
        capture_native(name)
status = process.wait()
if server is not None:
    server.close()
(output / 'manifest.json').write_text(json.dumps({
    'capture': 'native iOS simulator pixels; no compositing or resizing',
    'collection': args.collection,
    'languages': ['fr-FR', 'en-US', 'ar'] if args.collection != 'basic' else ['fr-FR'],
    'native_capture_acknowledged': server is not None,
    'city': 'Fès', 'coordinates': [34.0331, -5.0003],
    'prayers': 'actual local calculation at capture time',
    'quran_and_athkar': 'bundled application content',
    'other_sources': ('actual Hadith CDN, Overpass mosque responses and OpenStreetMap tiles; '
                      'simulator location service at public Fès coordinates; '
                      'name form before any AI request; fresh local reading progress; '
                      'iPad reader font set to the existing user-selectable maximum 40'
                      if args.collection == 'play-style' else None),
    'captures': captures,
    'flutter_drive_exit_code': status,
}, indent=2, ensure_ascii=False) + '\n')
if status != 0 or set(captures) != expected:
    raise SystemExit(status or 1)
