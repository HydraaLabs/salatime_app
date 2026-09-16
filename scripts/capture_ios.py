"""Collect native simulator pixels while real Flutter screens are visible."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--device', required=True)
parser.add_argument('--output', required=True)
args = parser.parse_args()
output = Path(args.output)
output.mkdir(parents=True, exist_ok=True)
command = ['flutter', 'drive', '--driver=test_driver/app_store.dart',
           '--target=integration_test/app_store_test.dart', '-d', args.device,
           '--dart-define=SALATIME_SENTRY_DSN=']
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           text=True, bufsize=1)
captures = {}
with (output / 'capture.log').open('w') as log:
    for line in process.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        log.write(line)
        log.flush()
        match = re.search(r'SALATIME_STORE_CAPTURE:([a-z0-9-]+)', line)
        if not match or match[1] in captures:
            continue
        name = match[1]
        path = output / (name + '.png')
        subprocess.run(['xcrun', 'simctl', 'io', args.device, 'screenshot', str(path)], check=True)
        raw = path.read_bytes()
        width, height = struct.unpack('>II', raw[16:24])
        if (width, height) not in {(1320, 2868), (1290, 2796), (1242, 2688), (2064, 2752), (2048, 2732)}:
            process.terminate()
            raise RuntimeError(f'Unexpected App Store screenshot dimensions: {width}x{height}')
        captures[name] = {'file': path.name, 'width': width, 'height': height,
                          'sha256': hashlib.sha256(raw).hexdigest()}
status = process.wait()
(output / 'manifest.json').write_text(json.dumps({
    'capture': 'native iOS simulator pixels; no compositing or resizing',
    'language': 'fr-FR', 'city': 'Fès', 'coordinates': [34.0331, -5.0003],
    'prayers': 'actual local calculation at capture time',
    'quran_and_athkar': 'bundled application content', 'captures': captures,
    'flutter_drive_exit_code': status,
}, indent=2, ensure_ascii=False) + '\n')
if status != 0 or set(captures) != {'01-prayer-times', '02-quran-al-fatiha', '03-athkar'}:
    raise SystemExit(status or 1)
