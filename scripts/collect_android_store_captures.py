#!/usr/bin/env python3
"""Collect authentic emulator screenshots requested by play_style_app_store_test.

Use only with a disposable emulator: the integration scenario resets app prefs.
Before launching: adb -s SERIAL reverse tcp:8879 tcp:8879
"""
import argparse
import io
import json
import re
import subprocess
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--serial', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--port', type=int, default=8879)
    args = parser.parse_args()
    if not args.serial.startswith('emulator-'):
        parser.error('Use a disposable emulator, not a personal device.')

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if self.path != '/capture' or not 0 < size < 1024:
                    raise ValueError('Invalid request')
                name = json.loads(self.rfile.read(size))['name']
                if not re.fullmatch(r'(fr-FR|en-US|ar)/0[1-6]-[a-z-]+', name):
                    raise ValueError('Invalid capture name')
                data = subprocess.check_output(
                    [args.adb, '-s', args.serial, 'exec-out', 'screencap', '-p'],
                    timeout=30,
                )
                with Image.open(io.BytesIO(data)) as image:
                    image.verify()
                output = args.output / (name + '.png')
                output.parent.mkdir(parents=True, exist_ok=True)
                output.write_bytes(data)
                payload = json.dumps({'ok': True, 'name': name}).encode()
                self.send_response(200)
                self.end_headers()
                self.wfile.write(payload)
                print(output, flush=True)
            except Exception as error:
                self.send_error(500, str(error))

    HTTPServer(('127.0.0.1', args.port), Handler).serve_forever()


if __name__ == '__main__':
    main()
