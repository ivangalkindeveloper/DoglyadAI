from __future__ import annotations

import argparse
import json
import subprocess
import time
from pathlib import Path

from evaluation.voice.common import ROOT


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Queue the current natural-dictation suites after the primary ASR matrix"
    )
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--kind", choices=("ios", "server"), required=True)
    parser.add_argument("--device-id")
    parser.add_argument("--publish-app-check-token", dest="is_publish_app_check_token", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    primary_count = len(json.loads((root / "corpus-all.json").read_text(encoding="utf-8"))["cases"])
    names = (
        ("speechAnalyzer", "sfSpeechRecognizer", "whisperKit")
        if args.kind == "ios"
        else ("medasr", "nemotron", "gigaam", "canary")
    )
    print(f"Waiting for primary {args.kind} runs before the natural-speech supplement", flush=True)
    while True:
        paths = (
            [root / "asr" / name / "results.jsonl" for name in names]
            if args.kind == "ios"
            else [root / "asr" / f"{name}.jsonl" for name in names]
        )
        if all(path.exists() and sum(1 for _ in path.open(encoding="utf-8")) == primary_count for path in paths):
            break
        time.sleep(10)
    if args.kind == "ios":
        if not args.device_id:
            raise ValueError("A physical iPhone is required")
        command = [
            "python3",
            "-m",
            "evaluation.voice.runners.run_local_asr_matrix",
            "--manifest",
            str(root / "corpus-natural.json"),
            "--output",
            str(root / "asr/natural"),
            "--device-id",
            args.device_id,
        ]
        if args.is_publish_app_check_token:
            command.append("--publish-app-check-token")
        with (root / "natural-ios.log").open("w", encoding="utf-8") as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
        print("Natural-speech supplement: all three iPhone ASR completed", flush=True)
    else:
        for name in names:
            settings = json.loads((root / "asr" / f"{name}.settings.json").read_text(encoding="utf-8"))
            python = root / ("gigaam-venv/bin/python" if name == "gigaam" else "venv/bin/python")
            command = [
                str(python),
                "-m",
                "evaluation.voice.runners.server_asr_benchmark",
                "--manifest",
                str(root / "corpus-natural.json"),
                "--output",
                str(root / "asr/natural" / f"{name}.jsonl"),
                "--model",
                name,
                "--cache",
                str(root / "model-cache"),
                "--revision",
                settings["revision"],
                "--device",
                settings["device"],
            ]
            print(f"Natural-speech supplement: starting {name}", flush=True)
            log_directory = root / "asr/natural"
            log_directory.mkdir(parents=True, exist_ok=True)
            with (log_directory / f"{name}.log").open("w", encoding="utf-8") as log:
                subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)
            print(f"Natural-speech supplement: {name} completed", flush=True)


if __name__ == "__main__":
    main()
