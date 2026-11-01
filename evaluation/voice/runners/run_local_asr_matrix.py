from __future__ import annotations

import argparse
from pathlib import Path

from evaluation.voice.runners.run_voice_matrix_ios import run_voice_matrix_ios


def main() -> None:
    parser = argparse.ArgumentParser(description="Run all current iPhone recognizers on the frozen audio matrix")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--publish-app-check-token", dest="is_publish_app_check_token", action="store_true")
    args = parser.parse_args()
    for engine in ("speechAnalyzer", "sfSpeechRecognizer", "whisperKit"):
        print(f"Starting {engine}", flush=True)
        run_voice_matrix_ios(
            manifest_path=args.manifest,
            output=args.output / engine,
            device_id=args.device_id,
            engine=engine,
            is_publish_app_check_token=args.is_publish_app_check_token,
        )


if __name__ == "__main__":
    main()
