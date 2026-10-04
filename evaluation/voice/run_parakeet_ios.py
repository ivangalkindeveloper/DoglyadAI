from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
import uuid
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.export_whisperkit_ios import export_whisperkit_report
from evaluation.voice.prepare_ios import prepare_fixtures
from evaluation.voice.run_ios import copy_device_report

DEFAULT_MODEL_DIR = ROOT / "build/voice-eval/models/parakeet-tdt-0.6b-v3"


def run_parakeet_ios(
    *,
    mode: str,
    variant: str,
    device_id: str,
    locale: str | None = None,
    limit: int | None = None,
    model_dir: Path = DEFAULT_MODEL_DIR,
) -> dict[str, Any]:
    fixture = prepare_fixtures(mode=mode, variant=variant, measure_gold=False, locale=locale, limit=limit)
    suffix = f"-smoke-{locale or 'both'}-{limit}" if limit is not None else ""
    output = ROOT / "build/voice-eval" / f"ios-parakeet-device-{mode}-{variant}{suffix}"
    output.mkdir(parents=True, exist_ok=True)
    run_id = uuid.uuid4().hex
    state_path = output / "run-state.json"
    state_path.write_text(json.dumps({"status": "running", "runId": run_id}, indent=2) + "\n", encoding="utf-8")

    if not (model_dir / "Encoder.mlmodelc").is_dir():
        raise FileNotFoundError(f"Parakeet Core ML model is missing: {model_dir}")
    copied = subprocess.run(
        [
            "xcrun",
            "devicectl",
            "device",
            "copy",
            "to",
            "--device",
            device_id,
            "--source",
            str(model_dir),
            "--domain-type",
            "appDataContainer",
            "--domain-identifier",
            "com.medical.doglyad.development",
            "--destination",
            "Documents/VoiceParakeetModel",
            "--timeout",
            "600",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if copied.returncode != 0:
        raise RuntimeError(f"Could not install Parakeet in the iPhone app container: {copied.stderr.strip()}")

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
        "-only-testing:DoglyadTests/VoiceParakeetTests/testBundledVoiceFiles",
    ]
    environment = os.environ.copy()
    environment["TEST_RUNNER_VOICE_PARAKEET_RUN"] = "1"
    environment["TEST_RUNNER_VOICE_REPORT_ID"] = run_id
    started = time.time()
    with (output / "xcodebuild.log").open("w", encoding="utf-8") as log:
        completed = subprocess.run(
            command, cwd=ROOT, env=environment, stdout=log, stderr=subprocess.STDOUT, check=False
        )
    if completed.returncode != 0:
        state_path.write_text(
            json.dumps({"status": "failed", "runId": run_id, "xcodebuildExitCode": completed.returncode}, indent=2)
            + "\n",
            encoding="utf-8",
        )
        raise RuntimeError(f"Parakeet iPhone test failed; see {output / 'xcodebuild.log'}")

    report_path = output / "results.json"
    copy_device_report(device_id, f"voice-parakeet-ios-{run_id}.json", report_path)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("runId") != run_id or report.get("fixtureAudioManifestSha256") != fixture["audioManifestSha256"]:
        raise ValueError("Parakeet test used stale audio fixtures")
    if report.get("fixtureAudioMode") != mode or report.get("fixtureAudioVariant") != variant:
        raise ValueError("Parakeet test used another audio pack")
    if report.get("modelLabel") != "parakeet-tdt-0.6b-v3-coreml":
        raise ValueError("Parakeet test used another model")
    if len(report["results"]) != len(fixture["cases"]):
        raise ValueError("Parakeet test returned fewer cases than prepared")
    exported = (
        export_whisperkit_report(report_path, output / "asr-report.json", recognizer_prefix="FluidAudio Core ML")
        if limit is None and locale is None
        else report
    )
    state_path.write_text(
        json.dumps({"status": "complete", "runId": run_id, "elapsedSeconds": time.time() - started}, indent=2) + "\n",
        encoding="utf-8",
    )
    return exported


def main() -> None:
    parser = argparse.ArgumentParser(description="Run Parakeet Core ML on synthetic WAV files on a physical iPhone")
    parser.add_argument("--mode", choices=("guided-format", "reordered-format", "freeform-development"), required=True)
    parser.add_argument("--variant", choices=("clean", "noisy"), required=True)
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--locale", choices=("en", "ru"))
    parser.add_argument("--limit", type=int)
    parser.add_argument("--model-dir", type=Path, default=DEFAULT_MODEL_DIR)
    args = parser.parse_args()
    report = run_parakeet_ios(
        mode=args.mode,
        variant=args.variant,
        device_id=args.device_id,
        locale=args.locale,
        limit=args.limit,
        model_dir=args.model_dir,
    )
    for locale in ("en", "ru"):
        rows = [row for row in report["results"] if row["locale"] == locale]
        completed = [row for row in rows if row["status"] == "ok"]
        mean_wer = (
            sum(row["correctedWER"] for row in completed) / len(completed)
            if completed and "correctedWER" in completed[0]
            else None
        )
        print(f"{locale}: {len(completed)}/{len(rows)} WAV, mean WER {mean_wer}")


if __name__ == "__main__":
    main()
