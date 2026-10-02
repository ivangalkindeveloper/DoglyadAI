from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import time
import uuid
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.freeform_model import CORPUS
from evaluation.voice.generate import file_sha256
from evaluation.voice.prepare_ios import FIXTURE_DIR
from evaluation.voice.run_ios import latest_report, simulator_id
from evaluation.voice.score_candidate import score_fields


def prepare_fixture(source_report: Path) -> dict[str, Any]:
    source = json.loads(source_report.read_text(encoding="utf-8"))
    if source["route"] != "macSwiftGuidedGeneration" or source["corpusSha256"] != file_sha256(CORPUS):
        raise ValueError("Mac guided report does not match the freeform corpus")
    source_cases = {row["caseId"]: row for row in source["cases"]}
    if len(source_cases) != len(source["cases"]):
        raise ValueError("Duplicate Mac guided case ID")
    cases = {json.loads(line)["id"]: json.loads(line) for line in CORPUS.read_text(encoding="utf-8").splitlines()}
    prepared = []
    for row in source["cases"]:
        case = cases[row["caseId"]]
        if row["locale"] != case["locale"] or not isinstance(row.get("inputText"), str):
            raise ValueError(f"Mac guided case metadata mismatch: {row['caseId']}")
        prepared.append(
            {
                "id": row["caseId"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "inputText": row["inputText"],
                "response": row["response"] if row["status"] == "ok" else None,
            }
        )
    fixture = {
        "schemaVersion": 1,
        "sourceReportSha256": file_sha256(source_report),
        "corpusSha256": file_sha256(CORPUS),
        "cases": prepared,
    }
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)
    destination = FIXTURE_DIR / "guided-cases.json"
    previous_stamp = destination.stat().st_mtime_ns if destination.exists() else 0
    temporary = destination.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    os.replace(temporary, destination)
    stamp = max(time.time_ns(), previous_stamp + 1_000_000_000, FIXTURE_DIR.stat().st_mtime_ns + 1_000_000_000)
    os.utime(destination, ns=(stamp, stamp))
    os.utime(FIXTURE_DIR, ns=(stamp, stamp))
    return fixture


def score_replay(report: dict[str, Any], source_report: Path) -> dict[str, Any]:
    source = json.loads(source_report.read_text(encoding="utf-8"))
    if report["sourceReportSha256"] != file_sha256(source_report) or report["corpusSha256"] != file_sha256(CORPUS):
        raise ValueError("iOS replay used stale model responses or corpus")
    cases = {case["id"]: case for case in map(json.loads, CORPUS.read_text(encoding="utf-8").splitlines())}
    expected_ids = {row["caseId"] for row in source["cases"]}
    if {row["id"] for row in report["results"]} != expected_ids:
        raise ValueError("iOS replay did not cover the Mac guided report")
    scored = []
    for row in report["results"]:
        case = cases[row["id"]]
        if row["locale"] != case["locale"]:
            raise ValueError(f"iOS replay locale differs: {row['id']}")
        result = row["result"]
        score = (
            score_fields(case["expectedFields"], result, locale=case["locale"], normalize_description=True)
            if result["status"] == "ok"
            else None
        )
        scored.append(
            {
                "id": row["id"],
                "locale": case["locale"],
                "scenario": case["scenario"],
                "expectedFieldIds": list(case["expectedFields"]),
                "status": result["status"],
                "score": score,
                "result": result,
            }
        )
    by_locale = {}
    for locale in ("en", "ru"):
        subset = [row for row in scored if row["locale"] == locale]
        valid = [row for row in subset if row["score"] is not None]
        by_locale[locale] = {
            "cases": len(subset),
            "parsed": len(valid),
            "exactForms": sum(row["score"]["equivalentExactCase"] for row in valid),
            "expectedPresentFields": sum(len(row["expectedFieldIds"]) for row in valid),
            "correctPresentFields": sum(
                sum(row["score"]["equivalentMatches"][field] for field in row["expectedFieldIds"]) for row in valid
            ),
            "falseFilledFields": sum(len(row["score"]["falseFilledFields"]) for row in valid),
            "unnoticedWrongFields": sum(len(row["score"]["equivalentUnnoticedWrongFields"]) for row in valid),
            "rejectedFields": sum(len(row["result"]["rejectedFieldIds"]) for row in valid),
        }
    return {
        "schemaVersion": 1,
        "sourceReportSha256": file_sha256(source_report),
        "corpusSha256": file_sha256(CORPUS),
        "byLocale": by_locale,
        "cases": scored,
    }


def run(source_report: Path, output: Path, *, device: str = "iPhone 17") -> dict[str, Any]:
    fixture = prepare_fixture(source_report)
    device_id = simulator_id(device)
    run_id = uuid.uuid4().hex
    started = time.time()
    output.mkdir(parents=True, exist_ok=True)
    command = [
        "xcodebuild",
        "-quiet",
        "test",
        "-project",
        "ios/Doglyad.xcodeproj",
        "-scheme",
        "Doglyad-Debug-Development",
        "-destination",
        f"platform=iOS Simulator,id={device_id}",
        "-parallel-testing-enabled",
        "NO",
        "-only-testing:DoglyadTests/VoiceGuidedReplayTests/testGuidedReplay",
        "CODE_SIGNING_ALLOWED=NO",
    ]
    environment = os.environ.copy()
    environment["TEST_RUNNER_VOICE_GUIDED_REPLAY_RUN"] = "1"
    environment["TEST_RUNNER_VOICE_REPORT_ID"] = run_id
    with (output / "xcodebuild.log").open("w", encoding="utf-8") as log:
        completed = subprocess.run(
            command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, check=False
        )
    if completed.returncode != 0:
        raise RuntimeError(f"xcodebuild failed; see {output / 'xcodebuild.log'}")
    report_source = latest_report(device_id, started, f"voice-guided-replay-ios-{run_id}.json")
    destination = output / "results.json"
    shutil.copy2(report_source, destination)
    report = json.loads(destination.read_text(encoding="utf-8"))
    if report["runId"] != run_id or report["sourceReportSha256"] != fixture["sourceReportSha256"]:
        raise ValueError("iOS replay returned stale output")
    summary = score_replay(report, source_report)
    (output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate Mac guided model proposals with the iOS Swift validator")
    parser.add_argument("source_report", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--device", default="iPhone 17")
    parser.add_argument("--score-only", action="store_true", help="Rescore an existing iOS results.json without Xcode")
    args = parser.parse_args()
    if args.score_only:
        raw = json.loads((args.output / "results.json").read_text(encoding="utf-8"))
        result = score_replay(raw, args.source_report)
        (args.output / "summary.json").write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    else:
        result = run(args.source_report, args.output, device=args.device)
    print(json.dumps(result["byLocale"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
