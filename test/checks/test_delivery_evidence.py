from copy import deepcopy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from delivery_evidence import verify_delivery


class DeliveryEvidenceTests(unittest.TestCase):
    def setUp(self):
        fixture = json.loads(
            (
                Path(__file__).resolve().parents[2] / "backend/main/mock/ru/report.json"
            ).read_text()
        )["report"]
        self.body = (
            "Photo regression\n" + fixture["description"] + "\n" + fixture["conclusion"]
        )
        self.before = dict(messages=[], rejectedCount=0, pendingFailure=False)
        self.after = dict(
            messages=[
                dict(
                    id="new",
                    subject="Photo regression",
                    body=self.body + "\n",
                    recipient="regression@example.invalid",
                    recipients=["regression@example.invalid"],
                    tls=True,
                    authenticated=True,
                    attachments=[
                        dict(
                            fileName="ultrasound-1.jpg",
                            mimeType="image/jpeg",
                            size=2000,
                            sha256="a" * 64,
                            isJPEG=True,
                        )
                    ],
                )
            ],
            rejectedCount=1,
            pendingFailure=False,
        )
        self.expected = dict(
            patientName="Photo regression",
            recipient="regression@example.invalid",
            failNext=True,
            attachmentCount=1,
        )

    def test_actual_body_matches_clipboard_and_backend_fixture(self):
        self.assertTrue(
            verify_delivery(self.before, self.after, self.body, self.expected)[
                "clipboardMatches"
            ]
        )

    def test_wrong_content_transport_attachment_or_retry_cannot_pass(self):
        for key, value in [
            ("recipient", "wrong@example.invalid"),
            ("tls", False),
            ("authenticated", False),
            ("body", "different report"),
            ("attachments", []),
        ]:
            after = deepcopy(self.after)
            after["messages"][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_delivery(self.before, after, self.body, self.expected)
        for change in [
            dict(rejectedCount=0),
            dict(pendingFailure=True),
            dict(messages=[]),
        ]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                verify_delivery(
                    self.before, {**self.after, **change}, self.body, self.expected
                )
        with self.assertRaises(ValueError):
            verify_delivery(self.before, self.after, "stale clipboard", self.expected)

    def test_model_clipboard_must_equal_the_entire_current_response_in_the_email(self):
        catalog = json.loads(
            (
                Path(__file__).resolve().parents[2]
                / "backend/main/config/development/ru/l10n_application.json"
            ).read_text()
        )
        model = self.body.split("\n", 1)[1]
        self.after["messages"][0]["body"] = (
            "Photo regression\n\n"
            + catalog["reportActualModelResponseTitle"]
            + "\n"
            + model
        )
        expected = {**self.expected, "clipboardMode": "model-report"}
        self.assertTrue(
            verify_delivery(self.before, self.after, model, expected)[
                "clipboardMatches"
            ]
        )
        for clipboard in [model[:100], self.after["messages"][0]["body"], "stale"]:
            with self.assertRaises(ValueError):
                verify_delivery(self.before, self.after, clipboard, expected)
