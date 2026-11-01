from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import httpx

from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.runners.refresh_matrix_app_check import refresh_matrix_app_check
from evaluation.voice.runners.run_voice_matrix_ios import run_voice_matrix_ios
from evaluation.voice.scoring.score_asr_matrix import RECOGNIZERS


def completed_asr_sources(root: Path) -> list[Path] | None:
    sources: list[Path] = []
    for manifest_name, directory in (("corpus-all.json", root / "asr"), ("corpus-natural.json", root / "asr/natural")):
        expected = {row["id"] for row in json.loads((root / manifest_name).read_text())["cases"]}
        for name in RECOGNIZERS:
            path = directory / name / "results.jsonl" if name in RECOGNIZERS[:3] else directory / f"{name}.jsonl"
            if not path.exists():
                return None
            contents = path.read_text()
            lines = contents.splitlines()
            if not contents.endswith("\n") or len(lines) != len(expected):
                return None
            rows = [json.loads(line) for line in lines]
            if {row["id"] for row in rows} != expected:
                return None
            sources.append(path)
    return sources


def run_queued_extraction(*, root: Path, device_id: str, token_file: Path) -> None:
    print("Waiting for all seven primary and natural ASR runs before extraction", flush=True)
    while (sources := completed_asr_sources(root)) is None:
        time.sleep(10)
    manifest = root / "corpus-final.json"
    pilot = root / "extraction/rules-pilot"
    run_voice_matrix_ios(
        manifest_path=manifest,
        transcripts=sources,
        output=pilot,
        device_id=device_id,
        methods="rules",
        limit=8,
        is_publish_app_check_token=True,
    )
    rows = [json.loads(line) for line in (pilot / "results.jsonl").read_text().splitlines()]
    if len(rows) != 8 or any(
        row["methods"][method]["status"] != "ok"
        for row in rows
        for method in ("exactLabels", "explicitRules", "naturalLanguage")
    ):
        raise RuntimeError("The extraction/form pilot is incomplete; inspect its device report")
    refresh_matrix_app_check(device_id=device_id, token_file=token_file, log_directory=root / "auth-logs")
    with httpx.Client(base_url="http://127.0.0.1:18000", timeout=30, trust_env=False) as client:
        response = client.get(
            "/v1/application_config",
            headers={"X-Firebase-AppCheck": token_file.read_text().strip()},
        )
        response.raise_for_status()
    output = root / "extraction/rules"
    run_voice_matrix_ios(
        manifest_path=manifest,
        transcripts=sources,
        output=output,
        device_id=device_id,
        methods="rules",
        is_publish_app_check_token=True,
    )
    result: dict[str, Any] = {
        "isReady": True,
        "rulesResults": str(output / "results.jsonl"),
        "rulesResultsSha256": file_sha256(output / "results.jsonl"),
        "isLocalMainAppCheckVerified": True,
        "localMainUrl": "http://127.0.0.1:18000",
        "next": "Enable the MedGemma GPU VM, verify protected inference, and run server_matrix_parse",
    }
    (root / "ready-for-gpu.json").write_text(json.dumps(result, indent=2) + "\n")
    print("Extraction rules completed; corrected inputs and protected local main are ready for GPU", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Queue native extraction/form checks after the complete ASR matrix")
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--device-id", required=True)
    parser.add_argument("--token-file", type=Path, required=True)
    args = parser.parse_args()
    run_queued_extraction(root=args.root.resolve(), device_id=args.device_id, token_file=args.token_file)


if __name__ == "__main__":
    main()
