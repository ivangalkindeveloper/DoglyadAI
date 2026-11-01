from __future__ import annotations

from evaluation.voice.common import ROOT

import argparse
import json
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any

from evaluation.voice.datasets.clinical_corpus import content_sha256, validate_corpus
from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.scoring.score_asr_matrix import _extraction_score, _summarize_extraction
from evaluation.voice.scoring.score_candidate import FIELDS
from evaluation.voice.scoring.spoken_wer import SCORER_VERSION
from evaluation.voice.datasets.validate_gold import validate_expected_fields


def prepare_parser_jobs(
    manifest_path: Path,
    output: Path,
    *,
    asr_paths: list[Path] | None = None,
    recognizer: str | None = None,
    corrected_paths: list[Path] | None = None,
) -> dict[str, Any]:
    """Export the same gold/raw/corrected text to any parser without gold answers."""
    if output.exists():
        raise FileExistsError(output)
    corpus = json.loads(manifest_path.read_text(encoding="utf-8"))
    if corpus.get("schemaVersion") == 2:
        validate_corpus(corpus)
        if (
            len(
                {
                    (case["sourceKind"], case.get("recordingMode", "unspecified"), case["split"])
                    for case in corpus["cases"]
                }
            )
            != 1
        ):
            raise ValueError("Score each source kind, recording mode and split separately")
    cases = {case["id"]: case for case in corpus["cases"]}
    if not cases or len(cases) != len(corpus["cases"]):
        raise ValueError("Empty corpus or duplicate case IDs")
    for case in cases.values():
        validate_expected_fields(case["expectedFields"])
        if not isinstance(case.get("referenceText"), str) or case.get("locale") not in ("ru", "en"):
            raise ValueError("A verbatim reference and known locale are required")
    if asr_paths and not recognizer:
        raise ValueError("Select one ASR recognizer per paired parser experiment")
    if corrected_paths and not asr_paths:
        raise ValueError("Corrected inputs require their frozen ASR sources")
    asr: dict[str, Any] = {}
    asr_hashes: dict[str, str] = {}
    for path in asr_paths or []:
        source_hash = file_sha256(path)
        with path.open(encoding="utf-8") as source:
            for line in source:
                row = json.loads(line)
                if row.get("recognizer", row.get("model")) != recognizer:
                    continue
                key = row["id"]
                if key not in cases or key in asr:
                    raise ValueError("Unknown or duplicate ASR input")
                if row.get("audioSha256") != cases[key].get("audioSha256") or row["locale"] != cases[key]["locale"]:
                    raise ValueError("ASR input differs from frozen corpus")
                if row.get("status") not in ("ok", "failed"):
                    raise ValueError("Unknown ASR status")
                asr[key] = row
                asr_hashes[key] = source_hash
    corrected: dict[str, str] = {}
    for path in corrected_paths or []:
        with path.open(encoding="utf-8") as source:
            for line in source:
                row = json.loads(line)
                if row.get("recognizer") != recognizer:
                    continue
                key = row.get("matrixCaseId", row["id"])
                if key not in asr or key in corrected or asr[key]["status"] != "ok":
                    raise ValueError("Unknown, duplicate or failed corrected input")
                if (
                    row.get("asrResultSha256") != asr_hashes[key]
                    or row.get("rawText") != asr[key].get("rawText")
                    or row.get("audioSha256") != cases[key].get("audioSha256")
                    or row.get("locale") != cases[key]["locale"]
                    or not isinstance(row.get("text"), str)
                ):
                    raise ValueError("Correction differs from frozen ASR source")
                corrected[key] = row["text"]
    jobs = []
    for case in cases.values():
        stages = [("goldText", case["referenceText"], "ready")]
        if asr_paths:
            row = asr.get(case["id"], {})
            for stage, key in (("rawASR", "rawText"), ("correctedASR", "correctedText")):
                text = row.get(key) if row.get("status") == "ok" else None
                if stage == "correctedASR" and corrected_paths:
                    text = corrected.get(case["id"])
                # Do not silently replace a missing correction by raw text.
                status = (
                    "ready"
                    if isinstance(text, str)
                    else "upstreamASRFailure"
                    if row.get("status") == "failed"
                    else "missing"
                )
                stages.append((stage, text, status))
        for stage, text, status in stages:
            job = {
                "id": f"{case['id']}/{stage}",
                "caseId": case["id"],
                "inputStage": stage,
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "text": text,
                "inputStatus": status,
            }
            job["inputSha256"] = content_sha256(job)
            jobs.append(job)
    metadata = {
        "schemaVersion": 1,
        "manifestPath": str(manifest_path.resolve()),
        "manifestSha256": file_sha256(manifest_path),
        "recognizer": recognizer,
        "asrSourceHashes": {str(path): file_sha256(path) for path in asr_paths or []},
        "correctedSourceHashes": {str(path): file_sha256(path) for path in corrected_paths or []},
        "correctedInputSource": "extraction.text" if corrected_paths else "asr.correctedText",
        "jobs": len(jobs),
        "note": "Only ready jobs go to the parser. Missing/failed upstream paths remain in the score. Exported jobs contain no expected fields, annotations or model outputs. Gold text may be unreviewed; consult the corpus.",
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".parser-jobs-", dir=output.parent) as temporary:
        staging = Path(temporary) / "jobs"
        staging.mkdir()
        (staging / "jobs.jsonl").write_text(
            "".join(json.dumps(job, ensure_ascii=False) + "\n" for job in jobs), encoding="utf-8"
        )
        metadata["jobsSha256"] = file_sha256(staging / "jobs.jsonl")
        (staging / "benchmark.json").write_text(
            json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        staging.rename(output)
    return metadata


def score_parser_jobs(bundle: Path, result_path: Path, output: Path, *, parser_id: str) -> dict[str, Any]:
    if not parser_id.strip():
        raise ValueError("A nonblank parser ID is required")
    if output.exists():
        raise FileExistsError(output)
    metadata = json.loads((bundle / "benchmark.json").read_text(encoding="utf-8"))
    manifest_path = Path(metadata["manifestPath"])
    # Frozen pre-reorganization bundles retain their original manifest path.
    # Resolve only this known move; the original content hash is still required.
    if not manifest_path.exists() and manifest_path.parent == ROOT / "evaluation/voice/fixtures":
        manifest_path = ROOT / "evaluation/voice/datasets/fixtures" / manifest_path.name
    if (
        file_sha256(manifest_path) != metadata["manifestSha256"]
        or file_sha256(bundle / "jobs.jsonl") != metadata["jobsSha256"]
    ):
        raise ValueError("Parser replay corpus or jobs changed")
    originals = {case["id"]: case for case in json.loads(manifest_path.read_text(encoding="utf-8"))["cases"]}
    jobs = {job["id"]: job for job in map(json.loads, (bundle / "jobs.jsonl").read_text(encoding="utf-8").splitlines())}
    measured: dict[str, Any] = {}
    with result_path.open(encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            key = row["id"]
            if (
                key not in jobs
                or key in measured
                or row.get("inputSha256") != jobs[key]["inputSha256"]
                or row.get("parserId") != parser_id
            ):
                raise ValueError("Unknown, duplicate or mismatched parser result")
            if jobs[key]["inputStatus"] != "ready" or row.get("status") not in ("ok", "failed", "unavailable"):
                raise ValueError("Parser result has no ready input or has an unknown status")
            measured[key] = {"methods": {parser_id: row}}
    groups = {}
    scored = []
    strata: dict[tuple[str, str, str, str], list[dict[str, Any]]] = defaultdict(list)
    for job in jobs.values():
        case = originals[job["caseId"]]
        strata[
            job["locale"], job["inputStage"], case.get("mode", "unspecified"), case.get("variant", "unspecified")
        ].append(job)
    for (locale, stage, mode, variant), selected in sorted(strata.items()):
        # Keep terminology, dictation styles and acoustic repeats separate.
        cases = [{**originals[job["caseId"]], "id": job["id"]} for job in selected]
        metrics = _summarize_extraction(cases, measured, parser_id)
        metrics["upstreamNotReady"] = sum(job["inputStatus"] != "ready" for job in selected)
        metrics["missingParserResults"] = sum(
            job["inputStatus"] == "ready" and job["id"] not in measured for job in selected
        )
        metrics["byField"] = {field: {"expected": 0, "textEquivalent": 0, "falseFilled": 0} for field in FIELDS}
        for job, case in zip(selected, cases, strict=True):
            row = measured.get(job["id"], {}).get("methods", {}).get(parser_id, {})
            score = _extraction_score(case, row)
            for field in FIELDS:
                counts = metrics["byField"][field]
                counts["expected"] += field in case["expectedFields"]
                counts["textEquivalent"] += (
                    field in case["expectedFields"] and row.get("status") == "ok" and score["equivalentMatches"][field]
                )
                counts["falseFilled"] += field in score["falseFilledFields"]
            scored.append(
                {
                    "id": job["id"],
                    "inputStage": stage,
                    "status": row.get("status", job["inputStatus"] if job["inputStatus"] != "ready" else "missing"),
                    "score": score,
                }
            )
        groups["/".join((locale, stage, mode, variant))] = metrics
    summary = {
        "schemaVersion": 1,
        "scorerVersion": SCORER_VERSION,
        "scorerSourceHashes": {
            str(path.relative_to(ROOT / "evaluation/voice")): file_sha256(path)
            for path in sorted((ROOT / "evaluation/voice").rglob("*.py"))
            if not {"tests", "results"}.intersection(path.relative_to(ROOT / "evaluation/voice").parts)
        },
        "parserId": parser_id,
        "jobsSha256": metadata["jobsSha256"],
        "manifestSha256": metadata["manifestSha256"],
        "resultsSha256": file_sha256(result_path),
        "isComplete": all(
            job["inputStatus"] == "upstreamASRFailure" or (job["inputStatus"] == "ready" and job["id"] in measured)
            for job in jobs.values()
        ),
        "groups": groups,
        "cases": scored,
    }
    with output.open("x", encoding="utf-8") as destination:
        destination.write(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Paired parsing on gold, raw ASR and corrected ASR inputs")
    commands = parser.add_subparsers(dest="command", required=True)
    prepare = commands.add_parser("prepare")
    prepare.add_argument("manifest", type=Path)
    prepare.add_argument("--output", type=Path, required=True)
    prepare.add_argument("--asr", nargs="+", type=Path)
    prepare.add_argument("--corrected-inputs", nargs="+", type=Path)
    prepare.add_argument("--recognizer")
    score = commands.add_parser("score")
    score.add_argument("bundle", type=Path)
    score.add_argument("results", type=Path)
    score.add_argument("--parser-id", required=True)
    score.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "prepare":
        result = prepare_parser_jobs(
            args.manifest,
            args.output,
            asr_paths=args.asr,
            recognizer=args.recognizer,
            corrected_paths=args.corrected_inputs,
        )
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        result = score_parser_jobs(args.bundle, args.results, args.output, parser_id=args.parser_id)
        print(
            json.dumps({"isComplete": result["isComplete"], "groups": result["groups"]}, ensure_ascii=False, indent=2)
        )


if __name__ == "__main__":
    main()
