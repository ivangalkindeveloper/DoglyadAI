import asyncio
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch


class BackendObserverTests(unittest.TestCase):
    def test_forwards_original_messages_without_persisting_secrets_or_photos(self):
        module_path = Path(__file__).resolve().parents[1] / "backend/observed_main.py"
        spec = importlib.util.spec_from_file_location(
            "regression_test_observer", module_path
        )
        module = importlib.util.module_from_spec(spec)
        backend = types.ModuleType("app.main")
        backend.app = object()
        with patch.dict(
            sys.modules, {"app": types.ModuleType("app"), "app.main": backend}
        ):
            spec.loader.exec_module(module)
        request = {
            "requestId": "request",
            "examination": {
                "settingsAI": {"isMarkdown": True},
                "template": "template text",
                "examinationData": {
                    "patientName": "Regression",
                    "photos": [{"data": "PRIVATE_IMAGE_BYTES"}],
                },
            },
        }
        incoming = {
            "type": "http.request",
            "body": json.dumps(request).encode(),
            "more_body": False,
        }
        sent = []
        scope = {
            "type": "http",
            "path": "/v1/ultrasound/report_generations",
            "method": "POST",
            "headers": [
                (b"authorization", b"PRIVATE_BEARER"),
                (b"x-firebase-appcheck", b"PRIVATE_APP_CHECK"),
            ],
        }

        async def receive():
            return incoming

        async def send(message):
            sent.append(message)

        async def application(actual_scope, actual_receive, actual_send):
            self.assertIs(actual_scope, scope)
            self.assertIs(await actual_receive(), incoming)
            await actual_send(
                {"type": "http.response.start", "status": 202, "headers": []}
            )
            await actual_send(
                {
                    "type": "http.response.body",
                    "body": b'{"generationId":"job","status":"queued"}',
                }
            )

        with tempfile.TemporaryDirectory() as folder:
            module.DIRECTORY = Path(folder)
            asyncio.run(module.RegressionObserver(application)(scope, receive, send))
            files = list(Path(folder).glob("*.json"))
            self.assertEqual(len(files), 1)
            raw = files[0].read_text()
            event = json.loads(raw)
            self.assertEqual(event["request"]["photoCount"], 1)
            self.assertEqual(event["response"]["generationId"], "job")
            self.assertNotIn("PRIVATE_", raw)
            self.assertEqual(sent[0]["status"], 202)
