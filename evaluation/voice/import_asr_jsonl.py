from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256


def import_asr_jsonl(
    *,
    jobs_path: Path,
    results_path: Path,
    output_path: Path,
    recognizer: str,
    variant: str,
    locale: str | None = None,
) -> dict[str, Any]:
    if variant not in {"clean", "noisy"}:
        raise ValueError(f"Unsupported audio variant: {variant}")
    if locale not in {None, "en", "ru"}:
        raise ValueError(f"Unsupported locale: {locale}")

    jobs = json.loads(jobs_path.read_text(encoding="utf-8"))
    expected: dict[str, dict[str, Any]] = {}
    for job in jobs:
        if job["id"] in expected:
            raise ValueError(f"Duplicate ASR job: {job['id']}")
        expected[job["id"]] = job

    results: dict[str, dict[str, Any]] = {}
    for line in results_path.read_text(encoding="utf-8").splitlines():
        result = json.loads(line)
        job_id = result["id"]
        if job_id not in expected:
            raise ValueError(f"Unexpected ASR result: {job_id}")
        if job_id in results:
            raise ValueError(f"Duplicate ASR result: {job_id}")
        results[job_id] = result

    jobs_for_variant = [
        job for job in jobs if job["id"].endswith(f"/{variant}") and (locale is None or job["locale"] == locale)
    ]
    if not jobs_for_variant:
        raise ValueError(f"No jobs for {variant}")
    missing = [job["id"] for job in jobs_for_variant if job["id"] not in results]
    if missing:
        raise ValueError(f"Missing {len(missing)} ASR results; first: {missing[0]}")

    rows = []
    for job in jobs_for_variant:
        result = results[job["id"]]
        if result["status"] != "ok" or not result.get("text"):
            raise ValueError(f"ASR did not complete: {job['id']}: {result.get('reason')}")
        case_id, job_variant = job["id"].rsplit("/", 1)
        rows.append(
            {
                "caseId": case_id,
                "locale": job["locale"],
                "variant": job_variant,
                "status": "ok",
                "rawText": result["text"],
                "correctedText": result["text"],
                "seconds": result["elapsedSeconds"],
            }
        )

    manifest_path = AUDIO_OUTPUT_DIR / "extended" / "manifest.json"
    report = {
        "schemaVersion": 1,
        "platform": "macOS",
        "recognizer": recognizer,
        "audioMode": "extended",
        "audioVariant": variant,
        "audioManifestSha256": file_sha256(manifest_path),
        "jobsSha256": file_sha256(jobs_path),
        "resultsSha256": file_sha256(results_path),
        "results": rows,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert an external ASR JSONL batch to iOS replay format")
    parser.add_argument("jobs_path", type=Path)
    parser.add_argument("results_path", type=Path)
    parser.add_argument("output_path", type=Path)
    parser.add_argument("--recognizer", required=True)
    parser.add_argument("--variant", choices=("clean", "noisy"), required=True)
    parser.add_argument("--locale", choices=("en", "ru"))
    args = parser.parse_args()
    report = import_asr_jsonl(
        jobs_path=args.jobs_path,
        results_path=args.results_path,
        output_path=args.output_path,
        recognizer=args.recognizer,
        variant=args.variant,
        locale=args.locale,
    )
    print(f"Imported {len(report['results'])} {args.variant} ASR results")


if __name__ == "__main__":
    main()
