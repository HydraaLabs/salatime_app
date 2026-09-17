"""Acknowledge a simulator screenshot only after native capture has completed."""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from threading import Thread


class CaptureServer:
    def __init__(self, capture):
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                try:
                    length = int(self.headers.get('Content-Length', '0'))
                    if self.path != '/capture' or not 0 < length <= 1024:
                        raise ValueError('Invalid capture request')
                    data = json.loads(self.rfile.read(length))
                    name = data['name']
                    if not isinstance(name, str):
                        raise ValueError('Invalid capture name')
                except (ValueError, KeyError, TypeError):
                    self.respond(400, {'ok': False})
                    return
                try:
                    capture(name)
                except Exception:
                    self.respond(500, {'ok': False})
                    return
                self.respond(200, {'ok': True, 'name': name})

            def respond(self, status, payload):
                content = json.dumps(payload).encode()
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)

            def log_message(self, *_):
                pass

        self.server = HTTPServer(('127.0.0.1', 0), Handler)
        self.port = self.server.server_address[1]
        self.thread = Thread(target=self.server.serve_forever, daemon=True)

    def start(self):
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
