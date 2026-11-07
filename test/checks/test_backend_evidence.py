import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from backend_evidence import verify_requests


class BackendEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.identity = "12345678-1234-1234-1234-123456789abc"
        self.event = dict(
            method="POST",
            path="/v1/ultrasound/report_generations",
            status=202,
            truncated=False,
            request=dict(
                requestId="request",
                settingsAI=dict(selectedNeuralModelId="model", temperature=0.7),
            ),
            response=dict(generationId=self.identity),
        )
        self.expected = dict(settingsAI=dict(temperature=0.7))
        self.job = dict(
            id=self.identity, request_id="request", status="completed", model_id="model"
        )

    def test_request_parameters_must_match_the_completed_job(self):
        with patch(
            "backend_evidence.subprocess.check_output",
            return_value=json.dumps(self.job),
        ):
            self.assertEqual(
                verify_requests([self.event], self.expected, "doglyad-regression-unit")[
                    "generationId"
                ],
                self.identity,
            )
            with self.assertRaises(ValueError):
                verify_requests(
                    [self.event],
                    dict(settingsAI=dict(temperature=2)),
                    "doglyad-regression-unit",
                )
        with patch(
            "backend_evidence.subprocess.check_output",
            return_value=json.dumps({**self.job, "status": "failed"}),
        ):
            with self.assertRaises(ValueError):
                verify_requests([self.event], self.expected, "doglyad-regression-unit")

    def test_invalid_form_cannot_send_even_an_unsuccessful_post(self):
        self.assertEqual(
            verify_requests([], dict(absent=True), "doglyad-regression-unit")[
                "generationRequests"
            ],
            0,
        )
        with self.assertRaises(ValueError):
            verify_requests(
                [{**self.event, "status": 422}],
                dict(absent=True),
                "doglyad-regression-unit",
            )

    def test_restricted_email_cannot_reach_the_delivery_endpoint(self):
        expected = dict(absent=True, emailAbsent=True)
        self.assertEqual(
            verify_requests([], expected, "doglyad-regression-unit")["status"], "passed"
        )
        for status in [200, 403, 500]:
            with self.assertRaisesRegex(ValueError, "SMTP delivery"):
                verify_requests(
                    [dict(method="POST", path="/v1/send_report_email", status=status)],
                    expected,
                    "doglyad-regression-unit",
                )

    def test_cancelled_dictation_cannot_send_a_request(self):
        expected = dict(absent=True, dictationAbsent=True)
        self.assertEqual(
            verify_requests([], expected, "doglyad-regression-unit")["status"], "passed"
        )
        with self.assertRaisesRegex(ValueError, "Cancelled speech"):
            verify_requests(
                [
                    dict(
                        method="POST", path="/v1/ultrasound/parse_dictation", status=499
                    )
                ],
                expected,
                "doglyad-regression-unit",
            )

    def test_edited_dictation_requires_its_exact_protected_request(self):
        event = dict(
            method="POST",
            path="/v1/ultrasound/parse_dictation",
            status=200,
            request=dict(transcript="Edited transcript"),
        )
        expected = dict(dictationText="Edited transcript")
        self.assertEqual(
            verify_requests([event], expected, "doglyad-regression-unit")[
                "dictationRequests"
            ],
            1,
        )
        for events in [
            [],
            [event, event],
            [{**event, "status": 500}],
            [{**event, "request": {"transcript": "old text"}}],
        ]:
            with self.subTest(events=events), self.assertRaises(ValueError):
                verify_requests(events, expected, "doglyad-regression-unit")

    def test_retry_requires_two_distinct_jobs_and_the_observed_partial_report(self):
        import copy

        identity2 = "22345678-1234-1234-1234-123456789abc"
        second = copy.deepcopy(self.event)
        second["response"]["generationId"] = identity2
        second["request"]["requestId"] = "retry"
        failed = dict(
            method="GET",
            path="/events",
            response=dict(generationId=self.identity, status="failed"),
            streamSnapshots=[
                dict(
                    generationId=self.identity,
                    status="streaming",
                    partialReport=dict(description="Actual partial response"),
                )
            ],
        )
        completed = dict(
            method="GET",
            path="/events",
            response=dict(generationId=identity2, status="completed"),
        )
        events = [self.event, failed, second, completed]
        expected = {
            **self.expected,
            "attemptStatuses": ["failed", "completed"],
            "partialAttempt": 0,
        }
        jobs = [
            json.dumps({**self.job, "status": "failed"}),
            json.dumps({**self.job, "id": identity2, "request_id": "retry"}),
        ]
        with patch("backend_evidence.subprocess.check_output", side_effect=jobs):
            self.assertEqual(
                verify_requests(events, expected, "doglyad-regression-unit")[
                    "generationRequests"
                ],
                2,
            )
        failed["streamSnapshots"] = []
        with (
            patch("backend_evidence.subprocess.check_output", side_effect=jobs),
            self.assertRaisesRegex(ValueError, "partial report"),
        ):
            verify_requests(events, expected, "doglyad-regression-unit")
        with self.assertRaises(ValueError):
            verify_requests(events[:2], expected, "doglyad-regression-unit")
