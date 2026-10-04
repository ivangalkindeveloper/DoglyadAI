from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
import uuid
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.export_whisperkit_ios import export_whisperkit_report
from evaluation.voice.prepare_ios import prepare_fixtures
from evaluation.voice.run_ios import copy_device_report

MODELS = {
    "turbo-626": ("VoiceWhisperKitModel", "large-v3-v20240930_626MB"),
    "large-v3-947": ("VoiceWhisperKitModelLargeV3", "large-v3_947MB"),
}


def run_whisperkit_ios(
    *, mode: str, variant: str, device_id: str, prewarm: bool, model: str = "turbo-626", prompt: str = "none"
) -> dict[str, Any]:
    if prompt not in ("none", "type-context"):
        raise ValueError(f"Unknown WhisperKit prompt mode: {prompt}")
    model_folder_name, model_label = MODELS[model]
    fixture = prepare_fixtures(mode=mode, variant=variant, measure_gold=False)
    output_name = f"ios-whisperkit-device-{mode}-{variant}"
    if model != "turbo-626":
        output_name += f"-{model}"
    if prompt != "none":
        output_name += f"-{prompt}"
    output = ROOT / "build/voice-eval" / output_name
    output.mkdir(parents=True, exist_ok=True)
    run_id = uuid.uuid4().hex
    state_path = output / "run-state.json"
    state_path.write_text(json.dumps({"status": "running", "runId": run_id}, indent=2) + "\n", encoding="utf-8")

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
        "-only-testing:DoglyadTests/VoiceWhisperKitTests/testBundledVoiceFiles",
    ]
    environment = os.environ.copy()
    environment["TEST_RUNNER_VOICE_WHISPERKIT_RUN"] = "1"
    environment["TEST_RUNNER_VOICE_REPORT_ID"] = run_id
    environment["TEST_RUNNER_VOICE_WHISPERKIT_PREWARM"] = "1" if prewarm else "0"
    environment["TEST_RUNNER_VOICE_WHISPERKIT_MODEL_FOLDER_NAME"] = model_folder_name
    environment["TEST_RUNNER_VOICE_WHISPERKIT_MODEL_LABEL"] = model_label
    environment["TEST_RUNNER_VOICE_WHISPERKIT_PROMPT_MODE"] = prompt
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
        raise RuntimeError(f"xcodebuild test failed; see {output / 'xcodebuild.log'}")

    report_path = output / "results.json"
    copy_device_report(device_id, f"voice-whisperkit-ios-{run_id}.json", report_path)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report.get("runId") != run_id or report.get("fixtureAudioManifestSha256") != fixture["audioManifestSha256"]:
        raise ValueError("WhisperKit test used stale audio fixtures")
    if report.get("fixtureAudioMode") != mode or report.get("fixtureAudioVariant") != variant:
        raise ValueError("WhisperKit test used another audio pack")
    if report.get("modelLabel") != model_label:
        raise ValueError("WhisperKit test used another model")
    if report.get("promptMode") != prompt:
        raise ValueError("WhisperKit test used another prompt mode")
    if len(report["results"]) != len(fixture["cases"]):
        raise ValueError("WhisperKit test returned fewer cases than prepared")
    exported = export_whisperkit_report(report_path, output / "asr-report.json")
    state_path.write_text(
        json.dumps({"status": "complete", "runId": run_id, "elapsedSeconds": time.time() - started}, indent=2) + "\n",
        encoding="utf-8",
    )
    return exported


def main() -> None:
    parser = argparse.ArgumentParser(description="Run WhisperKit on synthetic WAV files on a physical iPhone")
    parser.add_argument(
        "--mode", choices=("guided-format", "reordered-format", "freeform-development", "voice-blind-v3"), required=True
    )
    parser.add_argument("--variant", choices=("clean", "noisy"), required=True)
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--prewarm", action="store_true")
    parser.add_argument("--model", choices=tuple(MODELS), default="turbo-626")
    parser.add_argument("--prompt", choices=("none", "type-context"), default="none")
    args = parser.parse_args()
    report = run_whisperkit_ios(
        mode=args.mode,
        variant=args.variant,
        device_id=args.device_id,
        prewarm=args.prewarm,
        model=args.model,
        prompt=args.prompt,
    )
    for locale in ("en", "ru"):
        rows = [row for row in report["results"] if row["locale"] == locale]
        completed = [row for row in rows if row["status"] == "ok"]
        mean_wer = sum(row["correctedWER"] for row in completed) / len(completed) if completed else None
        print(f"{locale}: {len(completed)}/{len(rows)} WAV, mean WER {mean_wer}")


if __name__ == "__main__":
    main()
