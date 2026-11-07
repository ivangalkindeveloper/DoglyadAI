import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from external_evidence import verify


class ExternalEvidenceTests(unittest.TestCase):
    config = json.loads(
        (
            Path(__file__).resolve().parents[1] / "fixtures/development/ru.json"
        ).read_text()
    )["application"]

    def check(self, url, expected, canceled=True):
        return verify(
            {},
            {"event": dict(url=url, canceled=canceled, adapter="external-application")},
            [expected],
        )

    def test_store_destination_requires_the_exact_application_id(self):
        base = self.config["appleUpdateUrl"]
        identity = self.config["appStoreId"]
        self.assertEqual(
            self.check(base + identity, dict(kind="store"))["status"], "passed"
        )
        for url in (
            base + "/" + identity,
            base + "0",
            "https://example.invalid/app/id" + identity,
        ):
            with self.assertRaises(ValueError):
                self.check(url, dict(kind="store"))

    def test_support_requires_exact_recipient_subject_and_cancel(self):
        url = "mailto:" + self.config["contactEmail"] + "?subject=Support&body="
        expected = dict(kind="support", subject="Support")
        self.assertEqual(self.check(url, expected)["status"], "passed")
        for altered in (
            url.replace(self.config["contactEmail"], "wrong@example.invalid"),
            url.replace("Support", "wrong"),
        ):
            with self.assertRaises(ValueError):
                self.check(altered, expected)
        with self.assertRaises(ValueError):
            self.check(url, expected, canceled=False)

    def test_report_matches_the_exact_delivered_subject_and_full_body(self):
        from urllib.parse import urlencode

        expected = [dict(kind="report", patientName="Patient ABC")]
        message = dict(
            subject="Patient ABC report", body="Full report\r\nConclusion\r\n"
        )

        def event(body="Full report\nConclusion", subject=message["subject"]):
            return {
                "event": dict(
                    url="mailto:?" + urlencode(dict(subject=subject, body=body)),
                    canceled=True,
                    adapter="external-application",
                )
            }

        self.assertEqual(
            verify({}, event(), expected, delivered=[message])["status"], "passed"
        )
        for altered in [event(body="Full report"), event(subject="Another report")]:
            with self.assertRaises(ValueError):
                verify({}, altered, expected, delivered=[message])
        with self.assertRaises(ValueError):
            verify({}, event(), expected)

    def test_report_body_is_verified_without_copying_it_into_the_receipt(self):
        expected = dict(
            kind="share",
            subject="Report",
            bodyContains=["Patient ABC", "Conclusion DEF"],
        )
        proof = self.check(
            "mailto:?subject=Report&body=Patient%20ABC%0AConclusion%20DEF", expected
        )
        self.assertNotIn("Patient ABC", str(proof["actions"]))
        with self.assertRaises(ValueError):
            self.check("mailto:?subject=Report&body=Unrelated", expected)
        with self.assertRaises(ValueError):
            verify({}, {}, [expected])


if __name__ == "__main__":
    unittest.main()
