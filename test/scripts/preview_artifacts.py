"""Validate a complete rendering-only capture without granting regression status."""

from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import xml.etree.ElementTree as ET

from artifacts import dimensions, sha


def local_file(run: Path, name: str) -> Path:
    path = (run / name).resolve()
    if not path.is_relative_to(run.resolve()) or not path.is_file():
        raise ValueError("Preview evidence must remain inside its run directory")
    return path


def preview_publication(run: Path) -> dict:
    data = json.loads((run / "preview-report.json").read_text())
    if (
        data.get("scope") != "previews"
        or data.get("status") != "passed"
        or data.get("functionalTestsRun") is not False
        or data.get("cleanupStatus") != "passed"
        or not data.get("suiteHash")
        or not data.get("batchExitCodes")
        or any(code != 0 for code in data["batchExitCodes"].values())
    ):
        raise ValueError("Only a complete successful Preview capture can be published")
    catalog_path = local_file(run, "catalog.json")
    if sha(catalog_path) != data["catalogSha256"]:
        raise ValueError("Preview catalog changed")
    cases = json.loads(catalog_path.read_text())["atlas"]
    if any(case.get("previewScope") != "module" for case in cases):
        raise ValueError(
            "Only full-module Preview captures can be published; capture the current catalog"
        )
    expected = [case["id"] for case in cases]
    if (
        not expected
        or len(set(expected)) != len(expected)
        or any(not identity.startswith("atlas-") for identity in expected)
        or data["expectedCases"] != expected
        or [result["id"] for result in data["results"]] != expected
        or any(result["exitCode"] != 0 for result in data["results"])
    ):
        raise ValueError("Every registered Preview must pass before publication")
    grouped = defaultdict(list)
    for result in data["results"]:
        grouped[result["junit"]].append(result["id"])
    if set(grouped) != set(data["junitHashes"]):
        raise ValueError("Incomplete Preview JUnit evidence")
    for relative, identities in grouped.items():
        path = local_file(run, relative)
        if sha(path) != data["junitHashes"][relative]:
            raise ValueError("Preview JUnit changed")
        root = ET.parse(path).getroot()
        tests = list(root.iter("testcase"))
        if (
            sorted(test.get("name", "") for test in tests) != sorted(identities)
            or any(list(root.iter(tag)) for tag in ("failure", "error", "skipped"))
            or any(
                int(node.get(key, "0")) != 0
                for node in root.iter()
                for key in ("failures", "errors", "skipped")
            )
        ):
            raise ValueError("A Preview failed or was skipped")
    required = [(case["id"], shot) for case in cases for shot in case["screenshots"]]
    if (
        len(data["images"]) != len(required)
        or data["expectedScreenshots"] != len(required)
        or [(image["caseId"], image["shot"]) for image in data["images"]] != required
        or len({image["id"] for image in data["images"]}) != len(required)
    ):
        raise ValueError("Incomplete Preview screenshot collection")
    for image in data["images"]:
        path = local_file(run, image["path"])
        if (
            image["kind"] != "render"
            or image.get("locale") != "ru"
            or sha(path) != image["sha256"]
            or dimensions(path) != (image["width"], image["height"])
        ):
            raise ValueError("Preview image changed")
    (run / "preview-publication.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    )
    return data
