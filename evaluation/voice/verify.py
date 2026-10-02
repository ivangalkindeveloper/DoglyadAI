from __future__ import annotations

import argparse
import json
import subprocess
import time
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.generate import file_sha256
from evaluation.voice.prepare_ios import SOURCE_FILES

OUTPUT_DIR = ROOT / "build/voice-eval"


def run_checks(*, skip_ios: bool = False, physical_device_id: str | None = None) -> dict[str, Any]:
    python = ROOT / ".venv311/bin/python"
    ruff = ROOT / ".venv311/bin/ruff"
    checks: list[tuple[str, list[str], Path]] = [
        ("voiceRuff", [str(ruff), "check", "evaluation/voice"], ROOT),
        ("voiceFormat", [str(ruff), "format", "--check", "evaluation/voice"], ROOT),
        ("voiceTests", [str(python), "-m", "pytest", "evaluation/voice/tests", "-q"], ROOT),
    ]
    for service in ("main", "inference"):
        directory = ROOT / "backend" / service
        checks.extend(
            [
                (f"{service}Ruff", [str(ruff), "check", "app", "tests"], directory),
                (f"{service}Format", [str(ruff), "format", "--check", "app", "tests"], directory),
                (f"{service}Mypy", [str(python), "-m", "mypy", "app"], directory),
                (f"{service}Tests", [str(python), "-m", "pytest", "tests", "-q"], directory),
            ]
        )
    if not skip_ios:
        checks.append(
            (
                "iosTests",
                [
                    "xcodebuild",
                    "-quiet",
                    "test",
                    "-project",
                    "ios/Doglyad.xcodeproj",
                    "-scheme",
                    "Doglyad-Debug-Development",
                    "-destination",
                    f"platform=iOS,id={physical_device_id}"
                    if physical_device_id
                    else "platform=iOS Simulator,name=iPhone 17",
                    "-parallel-testing-enabled",
                    "NO",
                    "-only-testing:DoglyadTests",
                ],
                ROOT,
            )
        )
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    results = []
    for name, command, cwd in checks:
        started = time.monotonic()
        log_path = OUTPUT_DIR / f"verify-{name}.log"
        with log_path.open("w", encoding="utf-8") as output:
            try:
                completed = subprocess.run(
                    command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT, timeout=1800, check=False
                )
                status = "passed" if completed.returncode == 0 else "failed"
                code = completed.returncode
            except (OSError, subprocess.TimeoutExpired) as error:
                output.write(f"{type(error).__name__}: {error}\n")
                status = "failed"
                code = None
        results.append(
            {
                "name": name,
                "status": status,
                "exitCode": code,
                "elapsedSeconds": round(time.monotonic() - started, 2),
                "log": str(log_path.relative_to(ROOT)),
            }
        )
        print(f"{name}: {status}", flush=True)
    report = {
        "schemaVersion": 1,
        "allPassed": not skip_ios and all(row["status"] == "passed" for row in results),
        "iosSkipped": skip_ios,
        "iosDeviceId": physical_device_id,
        "sourceSha256": {str(path.relative_to(ROOT)): file_sha256(path) for path in SOURCE_FILES},
        "checks": results,
    }
    (OUTPUT_DIR / "verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Run all voice release code checks")
    parser.add_argument("--skip-ios", action="store_true")
    parser.add_argument("--physical-device-id")
    args = parser.parse_args()
    result = run_checks(skip_ios=args.skip_ios, physical_device_id=args.physical_device_id)
    if not result["allPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
