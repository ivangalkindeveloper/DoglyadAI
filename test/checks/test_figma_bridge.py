from __future__ import annotations

from contextlib import redirect_stdout
from http.client import HTTPConnection
from http.server import ThreadingHTTPServer
import io
import json
from pathlib import Path
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import figma_bridge


class FigmaBridgeTests(unittest.TestCase):
    def test_local_authentication_is_required_and_only_valid_receipt_completes_transfer(
        self,
    ):
        with tempfile.TemporaryDirectory() as directory:
            run = Path(directory)
            data = {"figmaFileKey": "file", "runId": "run", "images": [{"id": "one"}]}
            ready = threading.Event()
            servers = []
            result = []
            output = io.StringIO()

            def server_factory(address, handler):
                self.assertEqual(address, ("127.0.0.1", 8765))
                server = ThreadingHTTPServer((address[0], 0), handler)
                servers.append(server)
                ready.set()
                return server

            with (
                patch.object(
                    figma_bridge, "configure", return_value=run / "manifest.json"
                ),
                patch.object(
                    figma_bridge, "bridge_key", return_value="private-local-key"
                ),
                patch.object(figma_bridge, "publication", return_value=data),
                patch.object(
                    figma_bridge, "ThreadingHTTPServer", side_effect=server_factory
                ),
                redirect_stdout(output),
            ):
                worker = threading.Thread(
                    target=lambda: result.append(figma_bridge.serve(run, timeout=5))
                )
                worker.start()
                try:
                    self.assertTrue(ready.wait(2))
                    connection = HTTPConnection(*servers[0].server_address, timeout=2)
                    self.addCleanup(connection.close)
                    for credential in (None, "wrong"):
                        headers = (
                            {}
                            if credential is None
                            else {"Authorization": "Bearer " + credential}
                        )
                        connection.request("GET", "/manifest", headers=headers)
                        response = connection.getresponse()
                        self.assertEqual(response.status, 401)
                        response.read()
                    headers = {"Authorization": "Bearer private-local-key"}
                    connection.request("GET", "/manifest", headers=headers)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 426)
                    response.read()
                    headers["X-Doglyad-Regression-Protocol"] = "4"
                    connection.request("GET", "/manifest", headers=headers)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 426)
                    response.read()
                    headers["X-Doglyad-Regression-Protocol"] = "6"
                    connection.request("GET", "/manifest", headers=headers)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    self.assertEqual(json.loads(response.read()), data)
                    receipt = {
                        "runId": "wrong",
                        "fileKey": "file",
                        "imageCount": 1,
                        "nodeId": "1:2",
                        "layoutVersion": "ordered-white-text-v6",
                    }
                    connection.request("POST", "/ack", json.dumps(receipt), headers)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 400)
                    response.read()
                    self.assertFalse((run / "figma-receipt.json").exists())
                    receipt["runId"] = "run"
                    receipt["layoutVersion"] = "ordered-white-text-v4"
                    connection.request("POST", "/ack", json.dumps(receipt), headers)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 400)
                    response.read()
                    self.assertFalse((run / "figma-receipt.json").exists())
                    receipt["layoutVersion"] = "ordered-white-text-v6"
                    connection.request("POST", "/ack", json.dumps(receipt), headers)
                    response = connection.getresponse()
                    self.assertEqual(response.status, 200)
                    response.read()
                finally:
                    worker.join(6)
                self.assertFalse(worker.is_alive())
                self.assertEqual(result, [True])
                self.assertEqual(
                    json.loads((run / "figma-receipt.json").read_text()), receipt
                )
            self.assertNotIn("private-local-key", output.getvalue())
