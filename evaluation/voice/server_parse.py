from __future__ import annotations

import argparse
import asyncio
import json
import os
import time
from pathlib import Path
from typing import Any

import httpx

from evaluation.voice.generate import file_sha256
from evaluation.voice.score_candidate import FIELDS, score_fields

NUMERIC_FIELDS = {"patientHeightCM", "patientWeightKG"}


def load_cases(
    corpus_path: Path,
    asr_report_path: Path | None,
    audio_manifest_path: Path | None = None,
) -> list[dict[str, Any]]:
    if (asr_report_path is None) == (audio_manifest_path is None):
        raise ValueError("Specify exactly one ASR report or audio manifest")
    corpus = {
        case["id"]: case for line in corpus_path.read_text(encoding="utf-8").splitlines() if (case := json.loads(line))
    }
    if audio_manifest_path is not None:
        manifest = json.loads(audio_manifest_path.read_text(encoding="utf-8"))
        cases: list[dict[str, Any]] = []
        seen: set[str] = set()
        for entry in manifest["entries"]:
            case_id = entry["caseId"]
            if case_id in seen or case_id not in corpus:
                raise ValueError(f"Duplicate or unknown audio case: {case_id}")
            seen.add(case_id)
            case = corpus[case_id]
            if entry["locale"] != case["locale"] or entry["examinationTypeId"] != case["examinationTypeId"]:
                raise ValueError(f"Audio case metadata differs from corpus: {case_id}")
            cases.append(
                {
                    **case,
                    "inputText": entry["ttsText"] if entry["status"] == "ok" else None,
                    "inputStatus": entry["status"],
                }
            )
        return cases

    assert asr_report_path is not None

    report = json.loads(asr_report_path.read_text(encoding="utf-8"))
    cases: list[dict[str, Any]] = []
    seen: set[str] = set()
    for result in report["results"]:
        case_id = result["caseId"]
        if case_id in seen or case_id not in corpus:
            raise ValueError(f"Duplicate or unknown ASR case: {case_id}")
        seen.add(case_id)
        case = corpus[case_id]
        if result["locale"] != case["locale"]:
            raise ValueError(f"ASR locale differs from corpus: {case_id}")
        text = result.get("correctedText")
        status = result.get("status")
        cases.append(
            {
                **case,
                "inputText": text if status == "ok" and isinstance(text, str) and text.strip() else None,
                "inputStatus": status,
            }
        )
    return cases


def score_response(expected: dict[str, Any], response: dict[str, Any], locale: str) -> dict[str, Any]:
    actual: dict[str, Any] = {}
    for proposal in response["proposals"]:
        field_id = proposal["fieldId"]
        if field_id not in FIELDS or field_id in actual:
            raise ValueError(f"Unknown or duplicate response field: {field_id}")
        value: Any = proposal["value"]
        if field_id in NUMERIC_FIELDS:
            value = float(value)
        actual[field_id] = value
    parsed = {
        "fields": actual,
        "warnings": {},
        "rejectedFieldIds": response["rejectedFieldIds"],
    }
    return score_fields(expected, parsed, locale=locale, normalize_description=True)


def summarize(rows: list[dict[str, Any]]) -> dict[str, Any]:
    groups: dict[str, Any] = {}
    for locale in ("en", "ru"):
        for scenario in sorted({row["scenario"] for row in rows}):
            subset = [row for row in rows if row["locale"] == locale and row["scenario"] == scenario]
            if not subset:
                continue
            scored = [row for row in subset if row["status"] == "ok"]
            groups[f"{locale}/{scenario}"] = {
                "cases": len(subset),
                "parsed": len(scored),
                "exactForms": sum(row["score"]["equivalentExactCase"] for row in scored),
                "correctPresentFields": sum(
                    sum(row["score"]["equivalentMatches"][field] for field in row["expectedFieldIds"]) for row in scored
                ),
                "expectedPresentFields": sum(len(row["expectedFieldIds"]) for row in subset),
                "falseFilledFields": sum(len(row["score"]["falseFilledFields"]) for row in scored),
                "wrongProposedFields": sum(len(row["score"]["equivalentUnnoticedWrongFields"]) for row in scored),
            }
    return groups


async def run(
    *,
    corpus_path: Path,
    asr_report_path: Path | None,
    audio_manifest_path: Path | None,
    output_path: Path,
    base_url: str,
    token_file: Path,
    limit: int | None = None,
    max_attempts: int = 3,
) -> dict[str, Any]:
    if max_attempts < 1:
        raise ValueError("max_attempts must be positive")
    cases = load_cases(corpus_path, asr_report_path, audio_manifest_path)
    if limit is not None:
        cases = cases[:limit]
    corpus_hash = file_sha256(corpus_path)
    asr_hash = file_sha256(asr_report_path) if asr_report_path else None
    manifest_hash = file_sha256(audio_manifest_path) if audio_manifest_path else None
    report: dict[str, Any] = {
        "schemaVersion": 1,
        "corpusSha256": corpus_hash,
        "asrReportSha256": asr_hash,
        "audioManifestSha256": manifest_hash,
        "source": "iphoneASR" if asr_report_path else "audioScript",
        "results": [],
    }
    if output_path.exists():
        previous = json.loads(output_path.read_text(encoding="utf-8"))
        if any(
            previous.get(key) != report[key]
            for key in ("schemaVersion", "corpusSha256", "asrReportSha256", "audioManifestSha256")
        ):
            raise ValueError("Existing output belongs to another corpus or ASR report")
        report["results"] = previous["results"]
    completed = {row["id"] for row in report["results"]}
    if len(completed) != len(report["results"]):
        raise ValueError("Existing output contains duplicate case IDs")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    async with httpx.AsyncClient(timeout=135) as client:
        for case in cases:
            if case["id"] in completed:
                continue
            row: dict[str, Any] = {
                "id": case["id"],
                "locale": case["locale"],
                "scenario": case["scenario"],
                "expectedFieldIds": list(case["expectedFields"]),
            }
            if case["inputText"] is None:
                row["status"] = "noTranscript"
            else:
                started = time.monotonic()
                row["attempts"] = []
                for attempt in range(max_attempts):
                    token = token_file.read_text(encoding="utf-8").strip()
                    if not token:
                        raise ValueError("App Check token file is empty")
                    attempt_result: dict[str, Any] = {"number": attempt + 1}
                    try:
                        response = await client.post(
                            f"{base_url.rstrip('/')}/v1/ultrasound/parse_dictation",
                            headers={"X-Firebase-AppCheck": token, "Accept-Language": case["locale"]},
                            json={
                                "usExaminationTypeId": case["examinationTypeId"],
                                "transcript": case["inputText"],
                            },
                        )
                        row["httpStatus"] = response.status_code
                        attempt_result["httpStatus"] = response.status_code
                        if response.status_code == 401:
                            raise RuntimeError("App Check token expired or was rejected; refresh it and resume the run")
                        if response.status_code == 200:
                            result = response.json()
                            score = score_response(case["expectedFields"], result, case["locale"])
                            row["response"] = result
                            row["score"] = score
                            row["status"] = "ok"
                        else:
                            row["status"] = "httpError"
                    except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
                        row["status"] = "invalidResponse"
                        attempt_result["errorType"] = type(error).__name__
                    attempt_result["status"] = row["status"]
                    row["attempts"].append(attempt_result)
                    if row["status"] == "ok":
                        break
                    if attempt + 1 < max_attempts:
                        await asyncio.sleep(2.1 * (attempt + 1))
                row["elapsedSeconds"] = round(time.monotonic() - started, 3)
            report["results"].append(row)
            report["byLocaleScenario"] = summarize(report["results"])
            temporary = output_path.with_suffix(output_path.suffix + ".tmp")
            temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            os.replace(temporary, output_path)
            print(f"{len(report['results'])}/{len(cases)} {case['id']}: {row['status']}", flush=True)
            # The protected endpoint is limited to 30 requests per minute.
            await asyncio.sleep(2.1)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Replay a synthetic voice corpus through the server parser")
    parser.add_argument("--corpus", required=True, type=Path)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--asr-report", type=Path)
    source.add_argument("--audio-manifest", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--token-file", required=True, type=Path)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--max-attempts", type=int, default=3)
    args = parser.parse_args()
    asyncio.run(
        run(
            corpus_path=args.corpus,
            asr_report_path=args.asr_report,
            audio_manifest_path=args.audio_manifest,
            output_path=args.output,
            base_url=args.base_url,
            token_file=args.token_file,
            limit=args.limit,
            max_attempts=args.max_attempts,
        )
    )


if __name__ == "__main__":
    main()
