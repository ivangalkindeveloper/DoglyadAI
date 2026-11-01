from __future__ import annotations

from evaluation.voice.common import ROOT

import argparse
import csv
import json
import math
import statistics
import tempfile
from collections import defaultdict
from functools import lru_cache
from pathlib import Path
from typing import Any

from evaluation.voice.runners.asr import words
from evaluation.voice.datasets.clinical_corpus import content_sha256, review_payload, validate_corpus
from evaluation.voice.analysis.comparison import character_error_rate
from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.scoring.normalize_asr_text import normalize_asr_text
from evaluation.voice.scoring.score_candidate import score_fields
from evaluation.voice.scoring.score_review_actions import score_review_actions
from evaluation.voice.scoring.spoken_wer import SCORER_VERSION
from evaluation.voice.scoring.word_error_counts import word_error_counts
from evaluation.voice.datasets.validate_gold import validate_expected_fields

RECOGNIZERS = ("whisperKit", "sfSpeechRecognizer", "speechAnalyzer", "gigaam", "medasr", "nemotron", "canary")
METHODS = (
    "exactLabels",
    "explicitRules",
    "naturalLanguage",
    "foundationModels",
    "productionFoundation",
    "medgemma",
    "productionMedgemma",
    "medgemma15",
    "productionMedgemma15",
)


@lru_cache(maxsize=65536)
def _cer(reference: str, actual: str) -> float:
    try:
        from rapidfuzz.distance import Levenshtein
    except ImportError:
        return character_error_rate(reference, actual)
    expected = " ".join(words(reference))
    received = " ".join(words(actual))
    return Levenshtein.distance(expected, received) / len(expected) if expected else float(bool(received))


def _jsonl(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as source:
        return [json.loads(line) for line in source if line.strip()]


def _median(values: list[float]) -> float | None:
    return statistics.median(values) if values else None


def _asr_score(case: dict[str, Any], row: dict[str, Any] | None) -> dict[str, Any]:
    is_completed = bool(row and row.get("status") == "ok")
    transcript = row.get("rawText", "") if is_completed else ""
    reference, locale = case["referenceText"], case["locale"]
    corrected = row.get("correctedText", transcript) if is_completed else ""
    return {
        "id": case["id"],
        "status": row.get("status", "missing") if row else "missing",
        "raw": word_error_counts(tuple(words(reference)), tuple(words(transcript))),
        "normalized": word_error_counts(normalize_asr_text(reference, locale), normalize_asr_text(transcript, locale)),
        "correctedNormalized": word_error_counts(
            normalize_asr_text(reference, locale), normalize_asr_text(corrected, locale)
        ),
        "parserInputNormalized": word_error_counts(
            normalize_asr_text(reference, locale), normalize_asr_text(row["parserInputText"], locale)
        )
        if is_completed and "parserInputText" in row
        else None,
        "cer": _cer(reference, transcript),
        "seconds": row.get("seconds") if is_completed else None,
        "duration": case["durationSeconds"],
        "terms": len(case.get("terms", [])),
        "retainedTerms": sum(
            (" " + " ".join(words(term)) + " ") in (" " + " ".join(words(transcript)) + " ")
            for term in case.get("terms", [])
        ),
    }


def _summarize_asr(cases: list[dict[str, Any]], rows: dict[str, dict[str, Any]]) -> dict[str, Any]:
    scores = [_asr_score(case, rows.get(case["id"])) for case in cases]
    completed = [row for row in scores if row["status"] == "ok"]
    missing = sum(row["status"] == "missing" for row in scores)
    result = {
        "cases": len(cases),
        "completed": len(completed),
        "missing": missing,
        "failed": len(cases) - len(completed) - missing,
        "meanWER": statistics.mean(row["raw"]["wer"] for row in scores if row["raw"]["wer"] is not None)
        if any(row["raw"]["referenceWords"] for row in scores)
        else None,
        "meanNormalizedWER": statistics.mean(
            row["normalized"]["wer"] for row in scores if row["normalized"]["wer"] is not None
        )
        if any(row["normalized"]["referenceWords"] for row in scores)
        else None,
        "meanCER": statistics.mean(row["cer"] for row in scores) if scores else None,
        "medianSeconds": _median([row["seconds"] for row in completed if row["seconds"] is not None]),
        "medianRealTimeFactor": _median(
            [
                row["seconds"] / row["duration"]
                for row in completed
                if row["seconds"] is not None and row["duration"] > 0
            ]
        ),
        "terms": sum(row["terms"] for row in scores),
        "retainedTerms": sum(row["retainedTerms"] for row in scores),
        "emptyReferenceCases": sum(not row["raw"]["referenceWords"] for row in scores),
        "hallucinatedWordsOnEmptyReference": sum(
            row["raw"]["insertions"] for row in scores if not row["raw"]["referenceWords"]
        ),
    }
    for key, prefix in (("raw", "raw"), ("normalized", "normalized"), ("correctedNormalized", "correctedNormalized")):
        totals = {
            name: sum(row[key][name] for row in scores)
            for name in ("referenceWords", "substitutions", "deletions", "insertions", "errors")
        }
        for name, value in totals.items():
            result[prefix + name[0].upper() + name[1:]] = value
        result[prefix + "MicroWER"] = totals["errors"] / totals["referenceWords"] if totals["referenceWords"] else None
    result["correctionImprovedCases"] = sum(
        row["correctedNormalized"]["errors"] < row["normalized"]["errors"] for row in completed
    )
    result["correctionWorsenedCases"] = sum(
        row["correctedNormalized"]["errors"] > row["normalized"]["errors"] for row in completed
    )
    parser_inputs = [row for row in completed if row["parserInputNormalized"] is not None]
    result["parserInputMeasuredCases"] = len(parser_inputs)
    result["parserInputImprovedCases"] = sum(
        row["parserInputNormalized"]["errors"] < row["normalized"]["errors"] for row in parser_inputs
    )
    result["parserInputWorsenedCases"] = sum(
        row["parserInputNormalized"]["errors"] > row["normalized"]["errors"] for row in parser_inputs
    )
    return result


@lru_cache(maxsize=32768)
def _cached_fields(expected: str, proposal: str, locale: str, annotation: str) -> dict[str, Any]:
    return score_fields(
        json.loads(expected),
        json.loads(proposal),
        locale=locale,
        normalize_description=True,
        clinical_gold=json.loads(annotation),
    )


def _extraction_score(case: dict[str, Any], result: dict[str, Any]) -> dict[str, Any]:
    is_completed = result.get("status") == "ok"
    parse = {
        key: result.get(key, default) if is_completed else default
        for key, default in (
            ("fields", {}),
            ("warnings", {}),
            ("accuracies", {}),
            ("automaticFieldIds", []),
        )
    }
    score = _cached_fields(
        json.dumps(case["expectedFields"], sort_keys=True),
        json.dumps(parse, sort_keys=True),
        case["locale"],
        json.dumps(case.get("clinicalGold", {}), sort_keys=True),
    )
    return {
        **score,
        "reviewActions": score_review_actions(case.get("expectedActions", {}), result, score["equivalentMatches"]),
        "confirmationPatchErrors": _patch_errors(result, "formAfterConfirmation", list(parse["fields"])),
        "automaticPatchErrors": _patch_errors(result, "formAfterAutomatic", parse["automaticFieldIds"])
        if result.get("isAutomaticPolicySupported") is True
        else None,
    }


def _patch_errors(result: dict[str, Any], snapshot: str, fields: list[str]) -> list[str] | None:
    if result.get("status") != "ok" or snapshot not in result:
        return None
    errors = []
    for field in fields:
        proposed = result["fields"].get(field)
        applied = result[snapshot].get(field)
        if field in ("patientHeightCM", "patientWeightKG") and isinstance(applied, str):
            try:
                applied = float(applied)
            except ValueError:
                pass
        if applied != proposed:
            errors.append(field)
    return errors


def _summarize_extraction(
    cases: list[dict[str, Any]], rows: dict[str, dict[str, Any]], method: str, *, asr_rows: dict[str, Any] | None = None
) -> dict[str, Any]:
    scores: list[dict[str, Any]] = []
    completed = 0
    unavailable = 0
    results = []
    for case in cases:
        result = rows.get(case["id"], {}).get("methods", {}).get(method, {})
        results.append(result)
        if result.get("status") == "unavailable":
            unavailable += 1
        if result.get("status") == "ok":
            completed += 1
        scores.append(_extraction_score(case, result))
    expected_fields = sum(len(row["expectedFields"]) for row in cases)
    correct = sum(
        sum(score["matches"][field] for field in case["expectedFields"])
        for case, score in zip(cases, scores, strict=True)
    )
    equivalent = sum(
        sum(score["equivalentMatches"][field] for field in case["expectedFields"])
        for case, score in zip(cases, scores, strict=True)
    )
    supported = [
        score
        for score, row in zip(scores, results, strict=True)
        if row.get("status") == "ok" and row.get("isAutomaticPolicySupported") is True
    ]
    clinical = [value for score in scores for value in score["clinicalContent"].values()]
    upstream_failed = sum(
        not row and (asr_rows or {}).get(case["id"], {}).get("status") == "failed"
        for case, row in zip(cases, results, strict=True)
    )
    return {
        "cases": len(cases),
        "completed": completed,
        "unavailable": unavailable,
        "failed": sum(row.get("status") == "failed" for row in results),
        "missing": sum(not row for row in results) - upstream_failed,
        "upstreamASRFailed": upstream_failed,
        "expectedFields": expected_fields,
        "correctFields": correct,
        "equivalentCorrectFields": equivalent,
        "exactForms": sum(
            score["exactCase"] and row.get("status") == "ok" for score, row in zip(scores, results, strict=True)
        ),
        "equivalentExactForms": sum(
            score["equivalentExactCase"] and row.get("status") == "ok"
            for score, row in zip(scores, results, strict=True)
        ),
        "falseFields": sum(len(score["falseFilledFields"]) for score in scores),
        "wrongFullFields": sum(len(score["wrongFullFields"]) for score in scores),
        "equivalentWrongFullFields": sum(len(score["equivalentWrongFullFields"]) for score in scores),
        "automaticPolicyMeasuredCases": len(supported),
        "automaticPolicyUnsupportedCases": sum(row.get("isAutomaticPolicySupported") is False for row in results),
        "automaticFields": sum(len(score["automaticFields"]) for score in supported) if supported else None,
        "wrongAutomaticFields": sum(len(score["wrongAutomaticFields"]) for score in supported) if supported else None,
        "equivalentWrongAutomaticFields": sum(len(score["equivalentWrongAutomaticFields"]) for score in supported)
        if supported
        else None,
        "falseAutomaticFields": sum(len(score["falseAutomaticFields"]) for score in supported) if supported else None,
        "reviewFields": sum(len(row.get("reviewFieldIds", [])) for row in results if row.get("status") == "ok"),
        "reviewPolicyMeasuredCases": sum(row.get("status") == "ok" and "reviewFieldIds" in row for row in results),
        "expectedReviewActions": sum(score["reviewActions"]["expected"] for score in scores),
        "measuredReviewActions": sum(
            score["reviewActions"]["expected"] for score in scores if score["reviewActions"]["status"] == "measured"
        ),
        "matchedReviewActions": sum(score["reviewActions"]["matched"] or 0 for score in scores)
        if any(score["reviewActions"]["status"] == "measured" for score in scores)
        else None,
        "reliableFieldsSentToReview": sum(
            len(score["reviewActions"].get("reliableFieldsSentToReview", [])) for score in scores
        )
        if any(score["reviewActions"]["status"] == "measured" for score in scores)
        else None,
        "clinicalTextFields": len(clinical),
        "clinicalAssessedFields": sum(value["isClinicallyEquivalent"] is not None for value in clinical),
        "clinicalEquivalentFields": sum(value["isClinicallyEquivalent"] is True for value in clinical)
        if any(value["isClinicallyEquivalent"] is not None for value in clinical)
        else None,
        "clinicalUnassessedFields": sum(value["isClinicallyEquivalent"] is None for value in clinical),
        "generationReusedCases": sum(row.get("isGenerationReused") is True for row in results),
        "confirmationPatchMeasuredCases": sum(score["confirmationPatchErrors"] is not None for score in scores),
        "confirmationPatchErrorFields": sum(len(score["confirmationPatchErrors"] or []) for score in scores)
        if any(score["confirmationPatchErrors"] is not None for score in scores)
        else None,
        "automaticPatchMeasuredCases": sum(score["automaticPatchErrors"] is not None for score in scores),
        "automaticPatchErrorFields": sum(len(score["automaticPatchErrors"] or []) for score in scores)
        if any(score["automaticPatchErrors"] is not None for score in scores)
        else None,
    }


def score_asr_matrix(
    *,
    manifest_path: Path,
    asr_paths: list[Path],
    extraction_paths: list[Path],
    output: Path,
    methods: tuple[str, ...] = METHODS,
) -> dict[str, Any]:
    if output.exists():
        raise FileExistsError(f"Refusing to overwrite evaluation evidence: {output}")
    if not methods or len(set(methods)) != len(methods) or not set(methods).issubset(METHODS):
        raise ValueError("Select distinct known extraction methods")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest.get("cases"), list) or not manifest["cases"]:
        raise ValueError("A nonempty corpus is required")
    for case in manifest["cases"]:
        if (
            not isinstance(case.get("id"), str)
            or not case["id"].strip()
            or case.get("locale") not in ("ru", "en")
            or not isinstance(case.get("referenceText"), str)
        ):
            raise ValueError("Invalid matrix case identity, language or reference")
        duration = case.get("durationSeconds")
        if (
            isinstance(duration, bool)
            or not isinstance(duration, (int, float))
            or not math.isfinite(duration)
            or duration <= 0
        ):
            raise ValueError("Audio duration must be a positive finite number")
        validate_expected_fields(case.get("expectedFields"))
    originals = {row["id"]: row for row in manifest["cases"]}
    if len(originals) != len(manifest["cases"]):
        raise ValueError("Duplicate manifest case ID")
    corpus_evidence = {
        "status": "legacyUnreviewed",
        "isClinicalEvidenceReady": False,
        "isPopulationRepresentativenessEstablished": False,
    }
    if manifest.get("schemaVersion") == 2:
        corpus_evidence = validate_corpus(manifest)
        if any(not case.get("audioPath") for case in manifest["cases"]):
            raise ValueError("ASR matrix requires audio; a text-only review pilot is not an ASR experiment")
        if (
            len({case["sourceKind"] for case in manifest["cases"]}) != 1
            or len({case["split"] for case in manifest["cases"]}) != 1
            or len({case.get("recordingMode", "unspecified") for case in manifest["cases"]}) != 1
        ):
            raise ValueError(
                "Score each source kind, recording mode and split separately; do not pool different cohorts"
            )
    source_hashes = {str(path): file_sha256(path) for path in asr_paths + extraction_paths}
    asr_sources: dict[tuple[str, str], str] = {}
    asr: dict[str, dict[str, Any]] = defaultdict(dict)
    for path in asr_paths:
        for row in _jsonl(path):
            recognizer = row.get("recognizer", row.get("model"))
            key = row["id"]
            if recognizer not in RECOGNIZERS or key not in originals:
                raise ValueError(f"Unknown ASR result: {recognizer}/{key}")
            if key in asr[recognizer]:
                raise ValueError(f"Duplicate ASR result: {recognizer}/{key}")
            if row["audioSha256"] != originals[key]["audioSha256"] or row["locale"] != originals[key]["locale"]:
                raise ValueError("ASR result differs from frozen audio")
            if row.get("status") not in ("ok", "failed"):
                raise ValueError("Unexpected ASR status")
            if row["status"] == "ok" and not isinstance(row.get("rawText"), str):
                raise ValueError("Successful ASR must contain rawText, including an empty string on silence")
            asr[recognizer][key] = row
            asr_sources[recognizer, key] = source_hashes[str(path)]
    extraction: dict[str, dict[str, Any]] = defaultdict(dict)
    for path in extraction_paths:
        for row in _jsonl(path):
            recognizer = row["recognizer"]
            key = row["matrixCaseId"]
            if key not in originals or recognizer not in RECOGNIZERS:
                raise ValueError("Unknown extraction input")
            original = originals[key]
            recognition = asr[recognizer].get(key)
            if not recognition or recognition["status"] != "ok":
                raise ValueError("Extraction has no successful ASR source")
            if any(row.get(field) != original.get(field) for field in ("audioSha256", "locale", "expectedFields")):
                raise ValueError("Extraction metadata differs from frozen corpus")
            if (
                row.get("asrResultSha256") != asr_sources[recognizer, key]
                or row.get("rawText") != recognition["rawText"]
            ):
                raise ValueError("Extraction differs from its frozen ASR source")
            if not isinstance(row.get("text"), str):
                raise ValueError("Extraction input text is missing")
            if any(value.get("status") not in ("ok", "failed", "unavailable") for value in row["methods"].values()):
                raise ValueError("Unexpected extraction status")
            previous = extraction[recognizer].get(key, {})
            if previous and previous["text"] != row["text"]:
                raise ValueError("Compared extraction methods received different text")
            overlap = set(previous.get("methods", {})) & set(row["methods"])
            if overlap:
                raise ValueError(f"Duplicate extraction methods: {overlap}")
            extraction[recognizer][key] = {
                **previous,
                **row,
                "methods": {**previous.get("methods", {}), **row["methods"]},
            }
            # Derived audit-only value. This includes the historical server-ASR
            # lexicon pass that occurred at extraction input, not in ASR output.
            asr[recognizer][key]["parserInputText"] = row["text"]
    asr_groups: dict[str, Any] = {}
    extraction_groups: dict[str, Any] = {}
    for recognizer in RECOGNIZERS:
        for locale in ("ru", "en"):
            for dataset in ("dictation", "natural", "clinical", "terminology"):
                for variant in ("clean", "noisy", "both"):
                    cases = [
                        row
                        for row in manifest["cases"]
                        if row["locale"] == locale
                        and (
                            (dataset == "terminology" and row["mode"] == "terminology")
                            or (dataset == "natural" and row["mode"].startswith("natural-"))
                            or (
                                dataset == "dictation"
                                and row["mode"] in ("guided-format", "reordered-format", "freeform-development")
                            )
                            or (dataset == "clinical" and row["mode"] != "terminology")
                        )
                        and (variant == "both" or row["variant"] == variant)
                    ]
                    key = f"{recognizer}/{locale}/{dataset}/{variant}"
                    asr_groups[key] = _summarize_asr(cases, asr[recognizer])
                    for method in methods:
                        extraction_groups[key + "/" + method] = _summarize_extraction(
                            cases, extraction[recognizer], method, asr_rows=asr[recognizer]
                        )
    result = {
        "schemaVersion": 2,
        "scorerVersion": SCORER_VERSION,
        "manifestSha256": file_sha256(manifest_path),
        "sourceHashes": source_hashes,
        "scorerSourceHashes": {
            path.name: file_sha256(path)
            for path in (
                ROOT / "evaluation/voice" / name
                for name in (
                    "scoring/score_asr_matrix.py",
                    "scoring/score_candidate.py",
                    "scoring/score_ios.py",
                    "scoring/score_clinical_content.py",
                    "scoring/score_review_actions.py",
                    "scoring/normalize_evaluation_text.py",
                    "scoring/normalize_asr_text.py",
                    "scoring/word_error_counts.py",
                    "scoring/spoken_wer.py",
                    "runners/asr.py",
                    "analysis/comparison.py",
                    "datasets/clinical_corpus.py",
                    "datasets/validate_gold.py",
                )
            )
        },
        "methods": list(methods),
        "corpusEvidence": corpus_evidence,
        "note": "Failures/missing count as empty output. Exact/equivalent are textual metrics, not clinical correctness. Clinical equivalence requires independently adjudicated annotations; unknown is never correct. No bag-of-words critical-retention metric. Terminology is a separate diagnostic. Missing automatic policy is null. Legacy TTS reference is intended speech, not a human-verified audible transcript. Timing across hardware/build/cache conditions is not comparable.",
        "confidenceIntervals": {
            "status": "requiresExplicitClustersAndPairedAnalysis",
            "tool": "evaluation.voice.analysis.compare_grouped",
        },
        "asr": asr_groups,
        "extraction": extraction_groups,
    }
    result["isASRComplete"] = all(set(asr[name]) == set(originals) for name in RECOGNIZERS)
    missing_paths = []
    for name in RECOGNIZERS:
        for case_id, recognition in asr[name].items():
            if recognition["status"] != "ok":
                continue
            measured = extraction[name].get(case_id, {}).get("methods", {})
            for method in methods:
                allowed = {"ok", "failed"}
                if originals[case_id]["locale"] == "ru" and method in ("foundationModels", "productionFoundation"):
                    allowed.add("unavailable")
                if measured.get(method, {}).get("status") not in allowed:
                    missing_paths.append(f"{name}/{case_id}/{method}")
    result["isExtractionComplete"] = result["isASRComplete"] and not missing_paths
    result["unmeasuredExtractionPaths"] = missing_paths
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".voice-score-", dir=output.parent) as temporary:
        staging = Path(temporary) / "score"
        staging.mkdir()
        (staging / "summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        for name, groups in (("asr", asr_groups), ("extraction", extraction_groups)):
            with (staging / f"{name}.csv").open("w", encoding="utf-8", newline="") as destination:
                keys = list(next(iter(groups.values())))
                writer = csv.DictWriter(destination, fieldnames=["group", *keys])
                writer.writeheader()
                for group, data in groups.items():
                    writer.writerow({"group": group, **data})
        with (staging / "case-scores.jsonl").open("w", encoding="utf-8") as destination:
            for recognizer in RECOGNIZERS:
                for case in manifest["cases"]:
                    base = {
                        "id": case["id"],
                        "recognizer": recognizer,
                        "locale": case["locale"],
                        "mode": case["mode"],
                        "variant": case["variant"],
                        "expectedFieldIds": list(case["expectedFields"]),
                        "clusterId": case.get("clusterId"),
                        "sourceKind": case.get("sourceKind", "legacyUnreviewed"),
                        "recordingMode": case.get("recordingMode", "unspecified"),
                        "split": case.get("split", "legacyUnreviewed"),
                        "audioSha256": case["audioSha256"],
                        "goldSha256": content_sha256(review_payload(case)),
                    }
                    recognition = asr[recognizer].get(case["id"])
                    destination.write(
                        json.dumps({**base, "stage": "asr", **_asr_score(case, recognition)}, ensure_ascii=False) + "\n"
                    )
                    entry = extraction[recognizer].get(case["id"], {})
                    for method in methods:
                        measured = entry.get("methods", {}).get(method, {})
                        item = {
                            **base,
                            "stage": "extraction",
                            "method": method,
                            "status": measured.get(
                                "status",
                                "upstreamASRFailure"
                                if recognition and recognition["status"] == "failed"
                                else "missing",
                            ),
                            "isAutomaticPolicySupported": measured.get("isAutomaticPolicySupported"),
                            "reviewFieldIds": measured.get("reviewFieldIds"),
                            "isGenerationReused": measured.get("isGenerationReused"),
                            "score": _extraction_score(case, measured),
                        }
                        destination.write(json.dumps(item, ensure_ascii=False) + "\n")
        staging.rename(output)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Score all ASR/extraction combinations without dropping failures")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--asr", type=Path, nargs="+", required=True)
    parser.add_argument("--extraction", type=Path, nargs="*", default=[])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--require-complete", action="store_true")
    parser.add_argument("--methods", choices=METHODS, nargs="+")
    args = parser.parse_args()
    result = score_asr_matrix(
        manifest_path=args.manifest,
        asr_paths=args.asr,
        extraction_paths=args.extraction,
        output=args.output,
        methods=tuple(args.methods) if args.methods else METHODS,
    )
    if args.require_complete and not result["isExtractionComplete"]:
        raise SystemExit("The final comparison still contains unmeasured ASR/extraction paths")
    print(args.output / "summary.json")


if __name__ == "__main__":
    main()
