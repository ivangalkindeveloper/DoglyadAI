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

from evaluation.voice.common import CONFIG_DIR, ROOT, load_catalog, load_examination_titles
from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.runners.matrix_source_snapshot import matrix_source_snapshot
from evaluation.voice.runners.prepare_ios import FIXTURE_DIR
from evaluation.voice.runners.run_ios import copy_device_report


def run_voice_matrix_ios(
    *,
    manifest_path: Path,
    output: Path,
    device_id: str,
    engine: str | None = None,
    transcripts: list[Path] | None = None,
    server_results: Path | None = None,
    limit: int | None = None,
    methods: str = "all",
    is_publish_app_check_token: bool = False,
) -> None:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    _, vocabulary = load_catalog()
    titles = load_examination_titles()
    configuration: dict[str, Any] = {}
    application = json.loads((CONFIG_DIR / "application.json").read_text(encoding="utf-8"))["ultrasound"][
        "examinationNeuralModel"
    ]
    for locale in ("en", "ru"):
        strings = json.loads((CONFIG_DIR / locale / "l10n.json").read_text(encoding="utf-8"))
        configuration[locale] = {**application, "proposalPrompt": strings["examinationDictationProposalPrompt"]}
    originals = {row["id"]: row for row in manifest["cases"]}
    cases = []
    if engine:
        cases = list(originals.values())
    elif server_results:
        for line in server_results.read_text(encoding="utf-8").splitlines():
            result = json.loads(line)
            if result["status"] not in ("ok", "failed"):
                raise ValueError("Unexpected server generation status")
            cases.append(
                {
                    **originals[result["caseId"]],
                    **result,
                    "id": result["id"],
                    # The rules stage already produced this exact input for
                    # generation. Never correct it a second time during replay.
                    "isLexiconRequired": False,
                }
            )
    else:
        for source in transcripts or []:
            for line in source.read_text(encoding="utf-8").splitlines():
                row = json.loads(line)
                if row["status"] != "ok":
                    continue
                case_id = row.get("matrixCaseId", row["id"])
                original = originals[case_id]
                recognizer = row.get("recognizer", row.get("model"))
                cases.append(
                    {
                        **original,
                        "id": f"{recognizer}/{case_id}",
                        "matrixCaseId": case_id,
                        "recognizer": recognizer,
                        "text": row["correctedText"],
                        "rawText": row["rawText"],
                        "confidenceSpans": row.get("confidenceSpans", []),
                        "decodingSpans": row.get("decodingSpans", []),
                        "isLexiconRequired": recognizer in ("gigaam", "medasr", "nemotron", "canary"),
                        "asrSeconds": row["seconds"],
                        "asrResultSha256": file_sha256(source),
                    }
                )
    if limit:
        cases = [cases[round(i * (len(cases) - 1) / max(limit - 1, 1))] for i in range(min(limit, len(cases)))]
    output.mkdir(parents=True, exist_ok=True)
    settings_path = output / "settings.json"
    settings = {
        "schemaVersion": 2,
        "deviceId": device_id,
        "buildConfiguration": "Release-Development" if is_publish_app_check_token else "Debug-Development",
        "sourceSnapshot": matrix_source_snapshot(),
        "manifestSha256": file_sha256(manifest_path),
        "engine": engine,
        "server": server_results is not None,
        "sourceHashes": {str(path): file_sha256(path) for path in transcripts or []},
        "testSourceSha256": file_sha256(ROOT / "ios/DoglyadTests/VoiceMatrixTests.swift"),
        "caseIds": [row["id"] for row in cases],
    }
    if engine is None:
        settings["methods"] = methods
        settings["isPublishingAppCheckToken"] = is_publish_app_check_token
        if server_results:
            settings["serverResultsSha256"] = file_sha256(server_results)
    elif is_publish_app_check_token:
        settings["isPublishingAppCheckToken"] = True
        settings["buildConfiguration"] = "Release-Development"
    if settings_path.exists() and json.loads(settings_path.read_text(encoding="utf-8")) != settings:
        raise ValueError("Matrix iOS resume settings differ")
    settings_path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
    result_path = output / "results.jsonl"
    previous = (
        [json.loads(line) for line in result_path.read_text(encoding="utf-8").splitlines()]
        if result_path.exists()
        else []
    )
    if len({row["id"] for row in previous}) != len(previous):
        raise ValueError("Duplicate matrix iOS results")
    done = {row["id"] for row in previous}
    cases = [row for row in cases if row["id"] not in done]
    if not cases:
        print("All iOS matrix cases already complete")
        return
    for row in cases:
        row["contextualStrings"] = vocabulary[row["locale"]][row["examinationTypeId"]]
        row["examinationTypeTitle"] = titles[row["locale"]][row["examinationTypeId"]]
        if engine:
            path = ROOT / row["audioPath"]
            name = "matrix-" + row["audioSha256"] + ".wav"
            target = FIXTURE_DIR / name
            if not target.exists() or file_sha256(target) != row["audioSha256"]:
                shutil.copyfile(path, target)
            row["audioFile"] = name
    fixture_name = "matrix-asr" if engine else "matrix-extraction"
    fixture_path = FIXTURE_DIR / f"{fixture_name}.json"
    fixture = {
        "schemaVersion": 1,
        "manifestSha256": settings["manifestSha256"],
        "configuration": configuration,
        "cases": cases,
    }
    fixture_path.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    stamp = time.time_ns()
    os.utime(FIXTURE_DIR, ns=(stamp, stamp))
    run_id = uuid.uuid4().hex
    environment = os.environ.copy()
    environment["TEST_RUNNER_VOICE_MATRIX_FIXTURE"] = fixture_name
    environment["TEST_RUNNER_VOICE_REPORT_ID"] = run_id
    if engine:
        environment["TEST_RUNNER_VOICE_MATRIX_ASR"] = engine
    else:
        environment["TEST_RUNNER_VOICE_MATRIX_EXTRACTION"] = "1"
        environment["TEST_RUNNER_VOICE_MATRIX_METHODS"] = methods
    if server_results:
        environment["TEST_RUNNER_VOICE_MATRIX_SERVER"] = "1"
    if is_publish_app_check_token:
        environment["TEST_RUNNER_VOICE_MATRIX_EXPORT_TOKEN"] = "1"
    command = [
        "xcodebuild",
        "-quiet",
        "test",
        "-project",
        "ios/Doglyad.xcodeproj",
        "-scheme",
        "Doglyad-Debug-Development",
        "-destination",
        f"platform=iOS,id={device_id}",
        "-parallel-testing-enabled",
        "NO",
        "-test-timeouts-enabled",
        "NO",
        "-only-testing:DoglyadTests/VoiceMatrixTests/" + ("testASRMatrix" if engine else "testExtractionMatrix"),
    ]
    if is_publish_app_check_token:
        command.extend(["-configuration", "Release-Development", "ENABLE_TESTABILITY=YES"])
    (output / "active-run.json").write_text(
        json.dumps({"runId": run_id, "remaining": len(cases)}, indent=2) + "\n", encoding="utf-8"
    )
    try:
        with (output / "xcodebuild.log").open("w", encoding="utf-8") as log:
            completed = subprocess.run(
                command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, check=False
            )
    finally:
        new_rows: list[dict[str, Any]] = []
        checkpoint = output / f"device-{run_id}.jsonl"
        try:
            copy_device_report(device_id, f"voice-matrix-{run_id}.jsonl", checkpoint)
            new_rows = [json.loads(line) for line in checkpoint.read_text(encoding="utf-8").splitlines()]
            expected = {row["id"] for row in cases}
            if any(row["id"] not in expected for row in new_rows) or len({row["id"] for row in new_rows}) != len(
                new_rows
            ):
                raise ValueError("Stale or duplicate matrix report")
            temporary = result_path.with_suffix(".jsonl.tmp")
            temporary.write_text(
                "".join(json.dumps(row, ensure_ascii=False) + "\n" for row in previous + new_rows), encoding="utf-8"
            )
            temporary.replace(result_path)
        except RuntimeError:
            if not result_path.exists():
                print("No device checkpoint could be copied; inspect xcodebuild.log", flush=True)
    if completed.returncode:
        raise RuntimeError(f"iOS matrix test failed ({completed.returncode}); see {output / 'xcodebuild.log'}")
    if matrix_source_snapshot() != settings["sourceSnapshot"]:
        raise ValueError(
            "Source/configuration changed during the device run; keep the checkpoint as a diagnostic and rerun in a new directory"
        )
    if len(previous) + len(new_rows) != len(settings["caseIds"]):
        raise ValueError("iOS matrix did not return every requested case")
    print(f"Matrix iOS completed: {len(new_rows)} cases", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run paired ASR or extraction/form matrix on a physical iPhone")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--engine", choices=("speechAnalyzer", "sfSpeechRecognizer", "whisperKit"))
    parser.add_argument("--transcripts", type=Path, nargs="+")
    parser.add_argument("--server-results", type=Path)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--methods", choices=("all", "rules", "foundation"), default="all")
    parser.add_argument("--publish-app-check-token", action="store_true")
    args = parser.parse_args()
    run_voice_matrix_ios(
        manifest_path=args.manifest,
        output=args.output,
        device_id=args.device_id,
        engine=args.engine,
        transcripts=args.transcripts,
        server_results=args.server_results,
        limit=args.limit,
        methods=args.methods,
        is_publish_app_check_token=args.publish_app_check_token,
    )


if __name__ == "__main__":
    main()
