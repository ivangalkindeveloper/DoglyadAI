from __future__ import annotations

import base64
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from artifacts import finish, junit_passed, publication, validate_suite

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF6kAAAAASUVORK5CYII="
)


class PublicationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.run = Path(self.directory.name)
        self.suite = [
            {
                "id": "case-a",
                "kind": "functional",
                "screen": "Parent",
                "screenshots": ["screen-a"],
            },
            {
                "id": "case-b",
                "kind": "render",
                "previewScope": "module",
                "screen": "Parent",
                "screenshots": ["screen-b"],
            },
        ]
        self.results = []
        for case in self.suite:
            folder = self.run / case["id"]
            folder.mkdir()
            (folder / "junit.xml").write_text(
                f'<testsuites><testsuite tests="1" failures="0"><testcase name="{case["id"]}"/></testsuite></testsuites>'
            )
            (folder / (case["screenshots"][0] + ".png")).write_bytes(PNG)
            self.results.append(
                {
                    "id": case["id"],
                    "exitCode": 0,
                    "junit": case["id"] + "/junit.xml",
                    "artifacts": case["id"],
                }
            )

    def finalize(self, results=None):
        with patch("artifacts.suite_hash", return_value="reviewed-suite"):
            return finish(
                self.run,
                self.suite,
                self.results if results is None else results,
                "reviewed-suite",
                {"figmaFileKey": "test"},
            )

    def test_component_previews_cannot_be_published_with_a_full_run(self) -> None:
        self.suite[1]["previewScope"] = "component"
        with self.assertRaisesRegex(ValueError, "full-module"):
            self.finalize()
        self.assertFalse((self.run / "publication.json").exists())

    def test_complete_run_is_publishable_with_named_images(self) -> None:
        self.assertEqual(self.finalize()["status"], "passed")
        data = publication(self.run)
        self.assertEqual(len(data["images"]), 2)
        self.assertEqual(data["images"][0]["module"], "screen")
        self.assertEqual(data["images"][0]["kind"], "functional")
        self.assertEqual(data["images"][1]["kind"], "render")
        self.assertTrue((self.run / "index.html").is_file())

    def test_failed_run_links_diagnostics_and_distinguishes_unattempted_cases(
        self,
    ) -> None:
        self.results[0]["exitCode"] = 1
        (self.run / "case-a/maestro.log").write_text("UI assertion failed")
        (self.run / "failure.txt").write_text("Expected <button> was absent")
        report = self.finalize(self.results[:1])
        self.assertEqual(report["executionStatus"], "failed")
        page = (self.run / "index.html").read_text()
        self.assertIn('href="case-a/maestro.log"', page)
        self.assertIn('href="case-a/junit.xml"', page)
        self.assertIn("Expected &lt;button&gt; was absent", page)
        self.assertIn("<td>Ошибка</td>", page)
        self.assertIn("<td>case-b</td><td>Не запущен</td>", page)

    def test_missing_provider_evidence_blocks_publication(self) -> None:
        self.suite[0].update(provider="yookassa", paymentPlan="base_weekly")
        self.assertEqual(self.finalize()["executionStatus"], "failed")
        with self.assertRaises(ValueError):
            publication(self.run)

    def test_native_gesture_proof_is_required_and_immutable(self) -> None:
        with patch("artifacts.suite_hash", return_value="reviewed-suite"):
            report = finish(
                self.run,
                self.suite,
                self.results,
                "reviewed-suite",
                {},
                native_tests=["gestures"],
            )
            self.assertEqual(report["executionStatus"], "failed")
            path = self.run / "native-checks.json"
            path.write_text(
                json.dumps(
                    {
                        "requiredTests": ["gestures"],
                        "results": [{"id": "gestures", "result": "Passed"}],
                    }
                )
            )
            report = finish(
                self.run,
                self.suite,
                self.results,
                "reviewed-suite",
                {},
                native_tests=["gestures"],
            )
            self.assertEqual(report["executionStatus"], "passed")
            publication(self.run)
            path.write_text("{}")
            with self.assertRaisesRegex(ValueError, "Native test evidence changed"):
                publication(self.run)

    def test_changed_provider_evidence_blocks_publication(self) -> None:
        self.suite[0].update(provider="yookassa", paymentPlan="base_weekly")
        path = self.run / "cases/case-a/payment-evidence.json"
        path.parent.mkdir(parents=True)
        path.write_text(
            json.dumps({"test": True, "status": "succeeded", "planId": "base_weekly"})
        )
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        publication(self.run)
        path.write_text("{}")
        with self.assertRaisesRegex(ValueError, "payment evidence changed"):
            publication(self.run)

    def test_cancelled_payment_requires_no_provider_submission(self) -> None:
        self.suite[0].update(
            provider="yookassa", paymentPlan="base_weekly", paymentOutcome="canceled"
        )
        path = self.run / "cases/case-a/payment-evidence.json"
        path.parent.mkdir(parents=True)
        evidence = dict(
            test=True, status="canceled", planId="base_weekly", providerSubmitted=False
        )
        path.write_text(json.dumps(evidence))
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        path.write_text(json.dumps({**evidence, "providerSubmitted": True}))
        self.assertEqual(self.finalize()["executionStatus"], "failed")

    def test_confirmation_must_finish_the_exact_pending_order_without_access_beforehand(
        self,
    ):
        pending = dict(
            test=True,
            status="pending",
            planId="pro_weekly",
            paymentId="order",
            providerPaymentId="provider",
            paymentCount=1,
            activeTier="none",
        )
        confirmed = dict(pending, status="confirmed")
        paths = []
        for case, evidence in zip(self.suite, [pending, confirmed]):
            case.update(
                provider="yookassa",
                paymentPlan="pro_weekly",
                paymentOutcome=evidence["status"],
            )
            path = self.run / "cases" / case["id"] / "payment-evidence.json"
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(evidence))
            paths.append(path)
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        for change in [
            dict(paymentId="another-order"),
            dict(providerPaymentId="another-payment"),
            dict(paymentCount=2),
        ]:
            paths[1].write_text(json.dumps({**confirmed, **change}))
            self.assertEqual(self.finalize()["executionStatus"], "failed")
        paths[1].write_text(json.dumps(confirmed))
        paths[0].write_text(json.dumps({**pending, "activeTier": "pro"}))
        self.assertEqual(self.finalize()["executionStatus"], "failed")

    def test_rejected_active_purchase_must_keep_the_same_base_payment(self):
        base = dict(
            test=True,
            status="succeeded",
            planId="base_weekly",
            paymentId="base",
            providerPaymentId="base-provider",
            paymentCount=1,
        )
        rejected = dict(base, status="active-rejected")
        for case, evidence in zip(self.suite, [base, rejected]):
            case.update(
                provider="yookassa",
                paymentPlan="base_weekly",
                paymentOutcome=evidence["status"],
            )
            path = self.run / "cases" / case["id"] / "payment-evidence.json"
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps(evidence))
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        path.write_text(json.dumps({**rejected, "paymentId": "new-order"}))
        self.assertEqual(self.finalize()["executionStatus"], "failed")

    def test_delivery_proof_is_required_and_immutable(self) -> None:
        self.suite[0]["delivery"] = dict(
            recipient="regression@example.invalid",
            patientName="Photo regression",
            failNext=True,
            attachmentCount=1,
        )
        self.assertEqual(self.finalize()["executionStatus"], "failed")
        path = self.run / "cases/case-a/delivery-evidence.json"
        path.parent.mkdir(parents=True)
        path.write_text(
            json.dumps(
                dict(
                    status="passed",
                    clipboardMatches=True,
                    recipient="regression@example.invalid",
                    patientName="Photo regression",
                    messagesAccepted=1,
                    messagesRejected=1,
                    tls=True,
                    authenticated=True,
                    attachments=[{}],
                )
            )
        )
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        publication(self.run)
        path.write_text("{}")
        with self.assertRaisesRegex(ValueError, "Delivery evidence changed"):
            publication(self.run)

    def test_failed_case_never_creates_publication(self) -> None:
        self.results[1]["exitCode"] = 1
        report = self.finalize()
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["executionStatus"], "failed")
        self.assertFalse((self.run / "publication.json").exists())

    def test_backend_proof_must_match_the_case_and_remain_immutable(self) -> None:
        self.suite[0]["backendAssertions"] = dict(settingsAI=dict(temperature=0.7))
        self.assertEqual(self.finalize()["executionStatus"], "failed")
        path = self.run / "cases/case-a/backend-evidence.json"
        path.parent.mkdir(parents=True)
        evidence = dict(
            status="passed",
            generationRequests=1,
            expected=self.suite[0]["backendAssertions"],
        )
        for invalid in [
            dict(evidence, generationRequests=0),
            dict(evidence, expected=dict(absent=True)),
            dict(evidence, status="failed"),
        ]:
            path.write_text(json.dumps(invalid))
            self.assertEqual(self.finalize()["executionStatus"], "failed")
        path.write_text(json.dumps(evidence))
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        publication(self.run)
        path.write_text("{}")
        with self.assertRaisesRegex(ValueError, "Backend evidence changed"):
            publication(self.run)

    def test_local_proof_must_match_the_case_and_remain_immutable(self) -> None:
        self.suite[0]["localAssertions"] = dict(cleared=["reports"])
        self.assertEqual(self.finalize()["executionStatus"], "failed")
        path = self.run / "cases/case-a/local-evidence.json"
        path.parent.mkdir(parents=True)
        evidence = dict(status="passed", expected=self.suite[0]["localAssertions"])
        for invalid in [dict(evidence, status="failed"), dict(evidence, expected={})]:
            path.write_text(json.dumps(invalid))
            self.assertEqual(self.finalize()["executionStatus"], "failed")
        path.write_text(json.dumps(evidence))
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        publication(self.run)
        path.write_text("{}")
        with self.assertRaisesRegex(ValueError, "Local evidence changed"):
            publication(self.run)

    def test_saved_response_proof_must_match_the_case_and_remain_immutable(
        self,
    ) -> None:
        self.suite[0]["reportAssertions"] = dict(cleared=["reports"])
        self.assertEqual(self.finalize()["executionStatus"], "failed")
        path = self.run / "cases/case-a/report-evidence.json"
        path.parent.mkdir(parents=True)
        evidence = dict(status="passed", expected=self.suite[0]["reportAssertions"])
        for invalid in [dict(evidence, status="failed"), dict(evidence, expected={})]:
            path.write_text(json.dumps(invalid))
            self.assertEqual(self.finalize()["executionStatus"], "failed")
        path.write_text(json.dumps(evidence))
        self.assertEqual(self.finalize()["executionStatus"], "passed")
        publication(self.run)
        path.write_text("{}")
        with self.assertRaisesRegex(ValueError, "Saved response evidence changed"):
            publication(self.run)

    def test_missing_case_cannot_publish(self) -> None:
        self.assertEqual(self.finalize(self.results[:1])["status"], "failed")

    def test_skipped_or_failed_junit_is_not_a_pass(self) -> None:
        file = self.run / "case-a/junit.xml"
        for tag in ("skipped", "failure", "error"):
            file.write_text(
                f'<testsuite><testcase name="case-a"><{tag}/></testcase></testsuite>'
            )
            self.assertFalse(junit_passed(file, "case-a"))
            self.assertEqual(self.finalize()["status"], "failed")

    def test_missing_screenshot_blocks_the_whole_set(self) -> None:
        (self.run / "case-b/screen-b.png").unlink()
        self.assertEqual(self.finalize()["status"], "failed")

    def test_modified_screenshot_is_rejected_at_publication(self) -> None:
        self.finalize()
        image = next((self.run / "screenshots").glob("*.png"))
        image.write_bytes(PNG + b"changed")
        with self.assertRaises(ValueError):
            publication(self.run)

    def test_repeated_failure_cannot_leave_an_old_publication_file(self) -> None:
        self.finalize()
        self.results[0]["exitCode"] = 1
        self.finalize()
        self.assertFalse((self.run / "publication.json").exists())

    def test_changed_suite_during_run_blocks_publication(self) -> None:
        with patch("artifacts.suite_hash", return_value="changed"):
            report = finish(self.run, self.suite, self.results, "reviewed-suite", {})
        self.assertEqual(report["status"], "failed")

    def test_unautomated_module_scenarios_remain_visible_after_green_flows(
        self,
    ) -> None:
        with patch("artifacts.suite_hash", return_value="reviewed-suite"):
            report = finish(
                self.run,
                self.suite,
                self.results,
                "reviewed-suite",
                {},
                {"missingExecution": [{"id": "ScanSpeech.record"}]},
            )
        self.assertEqual(report["status"], "incomplete")
        self.assertEqual(report["executionStatus"], "passed")
        self.assertTrue((self.run / "publication.json").exists())
        data = publication(self.run)
        self.assertEqual(data["status"], "passed")
        self.assertEqual(data["coverageStatus"], "incomplete")
        self.assertEqual(data["coverage"], report["coverage"])

    def test_historical_success_can_publish_without_rewriting_its_report(self) -> None:
        self.finalize()
        (self.run / "publication.json").unlink()
        report_path = self.run / "report.json"
        report = json.loads(report_path.read_text())
        report["status"] = "incomplete"
        report["coverage"] = {"missingExecution": [{"id": "ScanSpeech.record"}]}
        report_path.write_text(json.dumps(report))
        original = report_path.read_bytes()
        self.assertEqual(publication(self.run)["status"], "passed")
        self.assertEqual(report_path.read_bytes(), original)

    def test_incomplete_report_without_execution_success_cannot_publish(self) -> None:
        self.finalize()
        (self.run / "publication.json").unlink()
        path = self.run / "report.json"
        report = json.loads(path.read_text())
        report["status"] = "incomplete"
        report.pop("executionStatus")
        path.write_text(json.dumps(report))
        with self.assertRaises(ValueError):
            publication(self.run)
        self.assertFalse((self.run / "publication.json").exists())

    def test_historical_run_rechecks_junit_before_creating_manifest(self) -> None:
        self.finalize()
        (self.run / "publication.json").unlink()
        (self.run / "case-b/junit.xml").write_text(
            '<testsuite><testcase name="case-b"><skipped/></testcase></testsuite>'
        )
        with self.assertRaises(ValueError):
            publication(self.run)
        self.assertFalse((self.run / "publication.json").exists())

    def test_cleanup_failure_cannot_publish_even_with_all_green_junit(self) -> None:
        self.finalize()
        (self.run / "publication.json").unlink()
        (self.run / "failure.txt").write_text("Environment cleanup failed")
        with self.assertRaises(ValueError):
            publication(self.run)
        self.assertFalse((self.run / "publication.json").exists())

    def test_failed_integrity_check_cannot_be_recovered_as_a_publication(self) -> None:
        with patch("artifacts.suite_hash", return_value="changed"):
            finish(self.run, self.suite, self.results, "reviewed-suite", {})
        with self.assertRaises(ValueError):
            publication(self.run)

    def test_publication_manifest_cannot_override_the_execution_report(self) -> None:
        self.finalize()
        path = self.run / "publication.json"
        manifest = json.loads(path.read_text())
        manifest["figmaFileKey"] = "another-file"
        path.write_text(json.dumps(manifest))
        with self.assertRaises(ValueError):
            publication(self.run)

    def test_zero_tests_or_wrong_test_name_cannot_pass(self) -> None:
        file = self.run / "empty.xml"
        for value in (
            '<testsuite tests="0"/>',
            '<testsuite><testcase name="other"/></testsuite>',
        ):
            file.write_text(value)
            self.assertFalse(junit_passed(file, "case-a"))

    def test_all_registered_yaml_files_and_screenshots_agree(self) -> None:
        suite = validate_suite()
        self.assertTrue(any(case.get("kind") == "functional" for case in suite))
        self.assertTrue(any(case.get("kind") == "render" for case in suite))


if __name__ == "__main__":
    unittest.main()
