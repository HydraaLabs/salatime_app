"""Protocol tests: the app must hold its screen until the screenshot is saved."""
import json
import threading
import unittest
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from capture_ios_protocol import CaptureServer


class CaptureProtocolTests(unittest.TestCase):
    def request(self, server, body):
        return urllib.request.urlopen(urllib.request.Request(
            f'http://127.0.0.1:{server.port}/capture', data=body,
            headers={'Content-Type': 'application/json'}), timeout=5)

    def test_ack_waits_for_native_capture_to_finish(self):
        started, release = threading.Event(), threading.Event()
        completed = []

        def capture(name):
            started.set()
            self.assertTrue(release.wait(timeout=3))
            completed.append(name)

        server = CaptureServer(capture)
        server.start()
        try:
            with ThreadPoolExecutor(max_workers=1) as pool:
                future = pool.submit(self.request, server, b'{"name":"fr-FR/04-quran-reading"}')
                self.assertTrue(started.wait(timeout=2))
                self.assertFalse(future.done())
                self.assertEqual(completed, [])
                release.set()
                with future.result() as response:
                    self.assertEqual(json.load(response), {'ok': True, 'name': 'fr-FR/04-quran-reading'})
                self.assertEqual(completed, ['fr-FR/04-quran-reading'])
        finally:
            release.set()
            server.close()

    def test_failed_capture_never_acknowledges_success(self):
        def capture(_):
            raise RuntimeError('Native capture failed')

        server = CaptureServer(capture)
        server.start()
        try:
            with self.assertRaises(urllib.error.HTTPError) as failure:
                self.request(server, b'{"name":"fr-FR/04-quran-reading"}')
            self.assertEqual(failure.exception.code, 500)
        finally:
            server.close()

    def test_invalid_payload_never_calls_capture(self):
        captured = []
        server = CaptureServer(captured.append)
        server.start()
        try:
            with self.assertRaises(urllib.error.HTTPError) as failure:
                self.request(server, b'not-json')
            self.assertEqual(failure.exception.code, 400)
            self.assertEqual(captured, [])
        finally:
            server.close()


if __name__ == '__main__':
    unittest.main()
