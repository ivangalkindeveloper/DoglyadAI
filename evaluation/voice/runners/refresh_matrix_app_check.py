from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import time
import uuid
from pathlib import Path

from evaluation.voice.common import ROOT
from evaluation.voice.runners.run_ios import copy_device_report


def _is_token_fresh(path: Path) -> bool:
    # This only schedules renewal. The real backends still verify the signature,
    # application identity and expiry of every token independently.
    try:
        encoded = path.read_text(encoding="utf-8").strip().split(".")[1]
        payload = json.loads(base64.urlsafe_b64decode(encoded + "=" * (-len(encoded) % 4)))
        return float(payload["exp"]) > time.time() + 900
    except (OSError, ValueError, IndexError, KeyError, TypeError):
        return False


def refresh_matrix_app_check(*, device_id: str, token_file: Path, log_directory: Path) -> None:
    if token_file.resolve().is_relative_to(ROOT):
        raise ValueError("App Check token must remain outside the repository")
    log_directory.mkdir(parents=True, exist_ok=True)
    temporary = token_file.with_suffix(".tmp")
    try:
        copy_device_report(device_id, "voice-matrix-app-check-token.txt", temporary)
        if _is_token_fresh(temporary):
            temporary.chmod(0o600)
            temporary.replace(token_file)
            print("Fresh physical-iPhone App Attest token synchronized", flush=True)
            return
    except RuntimeError:
        pass
    environment = os.environ.copy()
    environment["TEST_RUNNER_VOICE_MATRIX_EXPORT_TOKEN"] = "1"
    command = [
        "xcodebuild",
        "-quiet",
        "test",
        "-project",
        "ios/Doglyad.xcodeproj",
        "-scheme",
        "Doglyad-Debug-Development",
        "-configuration",
        "Release-Development",
        "-destination",
        f"platform=iOS,id={device_id}",
        "-parallel-testing-enabled",
        "NO",
        "-test-timeouts-enabled",
        "NO",
        "-only-testing:DoglyadTests/VoiceMatrixAppCheckTests/testExportTokenForLocalBenchmark",
        "ENABLE_TESTABILITY=YES",
    ]
    log = log_directory / f"app-check-{uuid.uuid4().hex}.log"
    with log.open("w", encoding="utf-8") as destination:
        completed = subprocess.run(
            command, cwd=ROOT, env=environment, stdout=destination, stderr=subprocess.STDOUT, check=False
        )
    if completed.returncode:
        raise RuntimeError(f"Real App Attest token refresh failed; see {log}")
    copy_device_report(device_id, "voice-matrix-app-check-token.txt", temporary)
    if not temporary.read_text(encoding="utf-8").strip():
        raise ValueError("The exported App Check token is empty")
    temporary.chmod(0o600)
    temporary.replace(token_file)
    print("Real App Attest token refreshed", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Export a genuine physical-iPhone App Attest token without logging it")
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--log-directory", type=Path, required=True)
    args = parser.parse_args()
    refresh_matrix_app_check(device_id=args.device_id, token_file=args.token_file, log_directory=args.log_directory)


if __name__ == "__main__":
    main()
