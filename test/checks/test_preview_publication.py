from __future__ import annotations

import base64
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from artifacts import sha
from preview_artifacts import preview_publication


class PreviewPublicationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.run = Path(self.temporary.name)
        cases = [{"id": "atlas-one", "screenshots": ["one"]}, {"id": "atlas-two", "screenshots": ["two"]}]
        (self.run / "catalog.json").write_text(json.dumps({"atlas": cases}))
        (self.run / "junit.xml").write_text('<testsuite tests="2" failures="0"><testcase name="atlas-one"/><testcase name="atlas-two"/></testsuite>')
        png = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
        images = []
        for case in cases:
            shot = case["screenshots"][0]
            path = self.run / (shot + ".png")
            path.write_bytes(png)
            images.append({"id": case["id"] + "--" + shot, "caseId": case["id"], "shot": shot,
                           "kind": "render", "locale": "ru", "path": path.name, "sha256": sha(path), "width": 1, "height": 1})
        self.data = {"scope": "previews", "status": "passed", "functionalTestsRun": False,
                     "cleanupStatus": "passed", "suiteHash": "hash", "batchExitCodes": {"junit.xml": 0},
                     "catalogSha256": sha(self.run / "catalog.json"), "expectedCases": [c["id"] for c in cases],
                     "results": [{"id": c["id"], "exitCode": 0, "junit": "junit.xml"} for c in cases],
                     "images": images, "expectedScreenshots": 2, "junitHashes": {"junit.xml": sha(self.run / "junit.xml")}}

    def publish(self):
        (self.run / "preview-report.json").write_text(json.dumps(self.data))
        return preview_publication(self.run)

    def test_complete_preview_capture_is_publishable_without_functional_results(self):
        self.assertEqual(self.publish()["scope"], "previews")
        self.assertTrue((self.run / "preview-publication.json").exists())

    def test_a_subset_cannot_be_presented_as_a_complete_preview_collection(self):
        self.data["expectedCases"].pop()
        self.data["results"].pop()
        self.data["images"].pop()
        self.data["expectedScreenshots"] = 1
        with self.assertRaisesRegex(ValueError, "Every registered Preview"):
            self.publish()

    def test_skipped_preview_rejects_publication_even_with_updated_junit_hash(self):
        path = self.run / "junit.xml"
        path.write_text('<testsuite><testcase name="atlas-one"><skipped/></testcase><testcase name="atlas-two"/></testsuite>')
        self.data["junitHashes"]["junit.xml"] = sha(path)
        with self.assertRaisesRegex(ValueError, "failed or was skipped"):
            self.publish()

    def test_changed_image_rejects_publication(self):
        (self.run / "one.png").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "image changed"):
            self.publish()

    def test_failed_cleanup_rejects_publication(self):
        self.data["cleanupStatus"] = "failed"
        with self.assertRaises(ValueError):
            self.publish()

    def test_preview_capture_cannot_claim_functional_execution(self):
        self.data["functionalTestsRun"] = True
        with self.assertRaises(ValueError):
            self.publish()

    def test_preview_mode_rejects_a_functional_image(self):
        self.data["images"][0]["kind"] = "functional"
        with self.assertRaisesRegex(ValueError, "image changed"):
            self.publish()

    def test_image_paths_cannot_escape_the_run(self):
        self.data["images"][0]["path"] = "../outside.png"
        with self.assertRaisesRegex(ValueError, "inside its run"):
            self.publish()
