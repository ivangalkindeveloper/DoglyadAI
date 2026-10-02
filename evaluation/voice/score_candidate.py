from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any

from evaluation.voice.asr import word_error_rate
from evaluation.voice.audio_reference import report_word_references
from evaluation.voice.comparison import character_error_rate
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.score_ios import _equal
from evaluation.voice.spoken_wer import spoken_normalized_wer

FIELDS = (
    "examinationNumber",
    "patientName",
    "patientGender",
    "patientDateOfBirth",
    "patientHeightCM",
    "patientWeightKG",
    "patientComplaints",
    "examinationDescription",
)
ENGINES = ("speechAnalyzer", "sfSpeechRecognizer")
TEST_PACKS = {
    "guided-format": ("guidedFormat", ("complete", "missing_demographics")),
    "reordered-format": ("reorderedFormat", ("complete", "partial")),
    "freeform-development": ("freeformSpeech", ("complete", "partial")),
}


def require_exact_gold_text(summary: dict[str, Any]) -> None:
    """Fail when an original transcript has a wrong or missing field."""
    if summary["inputSource"] != "originalText":
        return
    exact_key = (
        "equivalentExactCase"
        if summary.get("audioMode")
        in (
            "extended-v2",
            "voice-holdout",
            "phrase-holdout",
            "voice-blind-v3",
            "guided-format",
            "reordered-format",
            "freeform-development",
        )
        else "exactCase"
    )
    failed = [
        item["id"]
        for item in summary["scoredCases"]
        if item["goldTextStatus"] != "ok" or not item["goldText"][exact_key]
    ]
    if failed:
        sample = ", ".join(failed[:5])
        raise ValueError(f"Gold-text parsing failed for {len(failed)}/{summary['requestedCases']} cases: {sample}")


def score_fields(
    expected: dict[str, Any], parse: dict[str, Any], *, locale: str | None = None, normalize_description: bool = False
) -> dict[str, Any]:
    actual = parse["fields"]
    warnings = parse["warnings"]
    matches = {field: _equal(field, expected.get(field), actual.get(field)) for field in FIELDS}
    wrong = [field for field in FIELDS if not matches[field]]
    unnoticed = [field for field in wrong if field in actual and not warnings.get(field)]
    equivalent_description = matches["examinationDescription"]
    if normalize_description and not equivalent_description:
        expected_description = expected.get("examinationDescription")
        actual_description = actual.get("examinationDescription")
        if isinstance(expected_description, str) and isinstance(actual_description, str) and locale is not None:
            # Audio v2's original TTS text can spell a number out while the
            # expected form uses digits. The ASR usually makes the opposite
            # transformation. Keep both directions exact at the word level.
            equivalent_description = (
                spoken_normalized_wer(expected_description, actual_description, locale) == 0
                or spoken_normalized_wer(actual_description, expected_description, locale) == 0
            )
    equivalent_matches = {**matches, "examinationDescription": equivalent_description}
    equivalent_wrong = [field for field in FIELDS if not equivalent_matches[field]]
    equivalent_unnoticed = [field for field in equivalent_wrong if field in actual and not warnings.get(field)]
    return {
        "matches": matches,
        "equivalentMatches": equivalent_matches,
        "exactCase": not wrong,
        "equivalentExactCase": not equivalent_wrong,
        "proposedFields": [field for field in FIELDS if field in actual],
        "wrongFields": wrong,
        "unnoticedWrongFields": unnoticed,
        "equivalentWrongFields": equivalent_wrong,
        "equivalentUnnoticedWrongFields": equivalent_unnoticed,
        "falseFilledFields": [field for field in FIELDS if field not in expected and field in actual],
        "warnedFields": [field for field in FIELDS if warnings.get(field)],
        "rejectedFields": parse.get("rejectedFieldIds", []),
    }


def score_scenarios(scored: list[dict[str, Any]], scenarios: tuple[str, ...]) -> dict[str, Any]:
    groups: dict[str, Any] = {}
    for locale in ("en", "ru"):
        for scenario in scenarios:
            subset = [item for item in scored if item["locale"] == locale and item["scenario"] == scenario]
            if not subset:
                continue
            metrics: dict[str, Any] = {
                "cases": len(subset),
                "goldTextExactCases": sum(
                    item["goldTextStatus"] == "ok" and item["goldText"]["equivalentExactCase"] for item in subset
                ),
            }
            for engine in ENGINES:
                asr_ok = [item for item in subset if item[f"{engine}ASRStatus"] == "ok"]
                parse_ok = [item for item in subset if item[f"{engine}ParseStatus"] == "ok"]
                metrics[engine] = {
                    "asrAttempted": sum(item[f"{engine}ASRStatus"] != "skipped" for item in subset),
                    "asrCompleted": len(asr_ok),
                    "parseAttempted": sum(item[f"{engine}ParseStatus"] != "skipped" for item in subset),
                    "parseCompleted": len(parse_ok),
                    "exactCases": sum(item[engine]["equivalentExactCase"] for item in parse_ok),
                    "unnoticedWrongFields": sum(
                        len(item[engine]["equivalentUnnoticedWrongFields"]) for item in parse_ok
                    ),
                    "meanWER": sum(item[f"{engine}CorrectedWER"] for item in asr_ok) / len(asr_ok) if asr_ok else None,
                }
            groups[f"{locale}/{scenario}"] = metrics
    return groups


def score_candidate_report(report_path: Path, output_dir: Path) -> dict[str, Any]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    split = report.get("fixtureSplit", "regression")
    if split not in ("regression", "control", "adversarial", "voiceBlind", "freeformDevelopment"):
        raise ValueError("Unknown candidate corpus split")
    corpus_path = TEXT_OUTPUT_DIR / f"{split}.jsonl"
    expected_hash = {
        "regression": report.get("fixtureRegressionSha256"),
        "control": report.get("fixtureControlSha256"),
        "adversarial": report.get("fixtureAdversarialSha256"),
        "voiceBlind": report.get("fixtureVoiceBlindSha256"),
        "freeformDevelopment": report.get("fixtureFreeformDevelopmentSha256"),
    }[split]
    if expected_hash != file_sha256(corpus_path):
        raise ValueError("Candidate report uses a different corpus")
    cases = {
        case["id"]: case for line in corpus_path.read_text(encoding="utf-8").splitlines() if (case := json.loads(line))
    }
    word_references = report_word_references(report)
    rows = report["results"]
    if len({row["id"] for row in rows}) != len(rows):
        raise ValueError("Duplicate candidate results")
    scored = []
    for row in rows:
        case = cases[row["id"]]
        if row["locale"] != case["locale"] or row["examinationTypeId"] != case["examinationTypeId"]:
            raise ValueError("Candidate row metadata differs from corpus")
        item: dict[str, Any] = {
            "id": row["id"],
            "locale": case["locale"],
            "examinationTypeId": case["examinationTypeId"],
            "scenario": case["scenario"],
        }
        gold = row["goldTextParse"]
        item["goldTextStatus"] = gold["status"]
        if gold["status"] == "ok":
            item["goldText"] = score_fields(
                case["expectedFields"], gold, locale=case["locale"], normalize_description=bool(word_references)
            )
            item["goldParseSeconds"] = gold.get("elapsedSeconds")
        for engine in ENGINES:
            asr = row["asr"].get(f"{engine}/hints=true", {"status": "skipped", "reason": "Not run"})
            item[f"{engine}ASRStatus"] = asr["status"]
            item[f"{engine}ASRReason"] = asr.get("reason")
            if asr["status"] == "ok":
                reference = word_references.get(case["id"], case["spokenText"])
                if report.get("fixtureAudioMode") in (
                    "extended-v2",
                    "voice-holdout",
                    "phrase-holdout",
                    "voice-blind-v3",
                    "guided-format",
                    "reordered-format",
                    "freeform-development",
                ):
                    item[f"{engine}RawLiteralWER"] = word_error_rate(reference, asr["rawText"])
                    item[f"{engine}CorrectedLiteralWER"] = word_error_rate(reference, asr["correctedText"])
                    item[f"{engine}RawWER"] = spoken_normalized_wer(reference, asr["rawText"], case["locale"])
                    item[f"{engine}CorrectedWER"] = spoken_normalized_wer(
                        reference, asr["correctedText"], case["locale"]
                    )
                else:
                    item[f"{engine}RawWER"] = word_error_rate(reference, asr["rawText"])
                    item[f"{engine}CorrectedWER"] = word_error_rate(reference, asr["correctedText"])
                item[f"{engine}RawCER"] = character_error_rate(reference, asr["rawText"])
                item[f"{engine}CorrectedCER"] = character_error_rate(reference, asr["correctedText"])
                item[f"{engine}ASRSeconds"] = asr.get("elapsedSeconds")
            parse = row["recognizedTextParse"][engine]
            item[f"{engine}ParseStatus"] = parse["status"]
            if parse["status"] == "ok":
                item[engine] = score_fields(
                    case["expectedFields"], parse, locale=case["locale"], normalize_description=bool(word_references)
                )
                item[f"{engine}ParseSeconds"] = parse.get("elapsedSeconds")
        scored.append(item)

    by_locale: dict[str, Any] = {}
    for locale in ("en", "ru"):
        subset = [item for item in scored if item["locale"] == locale]
        locale_metrics: dict[str, Any] = {"cases": len(subset)}
        gold_ok = [item for item in subset if item["goldTextStatus"] == "ok"]
        locale_metrics["goldTextScoredCases"] = len(gold_ok)
        locale_metrics["goldTextExactCases"] = sum(item["goldText"]["exactCase"] for item in gold_ok)
        locale_metrics["goldTextEquivalentExactCases"] = sum(
            item["goldText"]["equivalentExactCase"] for item in gold_ok
        )
        locale_metrics["goldTextUnnoticedWrongFields"] = sum(
            len(item["goldText"]["unnoticedWrongFields"]) for item in gold_ok
        )
        locale_metrics["goldTextFields"] = {
            field: {
                "expected": sum(field in cases[item["id"]]["expectedFields"] for item in gold_ok),
                "proposed": sum(field in item["goldText"]["proposedFields"] for item in gold_ok),
                "correctProposed": sum(
                    field in item["goldText"]["proposedFields"] and item["goldText"]["matches"][field]
                    for item in gold_ok
                ),
                "unnoticedWrong": sum(field in item["goldText"]["unnoticedWrongFields"] for item in gold_ok),
            }
            for field in FIELDS
        }
        for engine in ENGINES:
            asr_ok = [item for item in subset if item[f"{engine}ASRStatus"] == "ok"]
            parse_ok = [item for item in subset if item[f"{engine}ParseStatus"] == "ok"]
            locale_metrics[engine] = {
                "asrStatuses": dict(Counter(item[f"{engine}ASRStatus"] for item in subset)),
                "parseStatuses": dict(Counter(item[f"{engine}ParseStatus"] for item in subset)),
                "scoredCases": len(parse_ok),
                "exactCases": sum(item[engine]["exactCase"] for item in parse_ok),
                "equivalentExactCases": sum(item[engine]["equivalentExactCase"] for item in parse_ok),
                "unnoticedWrongFields": sum(len(item[engine]["unnoticedWrongFields"]) for item in parse_ok),
                "equivalentUnnoticedWrongFields": sum(
                    len(item[engine]["equivalentUnnoticedWrongFields"]) for item in parse_ok
                ),
                "meanCorrectedWER": sum(item[f"{engine}CorrectedWER"] for item in asr_ok) / len(asr_ok)
                if asr_ok
                else None,
                "meanCorrectedLiteralWER": sum(
                    item.get(f"{engine}CorrectedLiteralWER", item[f"{engine}CorrectedWER"]) for item in asr_ok
                )
                / len(asr_ok)
                if asr_ok
                else None,
            }
        by_locale[locale] = locale_metrics
    test_pack = TEST_PACKS.get(report.get("fixtureAudioMode"))
    summary = {
        "schemaVersion": 1,
        "testPack": test_pack[0] if test_pack else None,
        "platform": report["platform"],
        "split": split,
        "systemVersion": report["systemVersion"],
        "deviceModel": report["deviceModel"],
        "regressionSha256": report["fixtureRegressionSha256"],
        "controlSha256": report.get("fixtureControlSha256"),
        "voiceBlindSha256": report.get("fixtureVoiceBlindSha256"),
        "freeformDevelopmentSha256": report.get("fixtureFreeformDevelopmentSha256"),
        "adversarialSha256": report.get("fixtureAdversarialSha256"),
        "audioManifestSha256": report["fixtureAudioManifestSha256"],
        "audioMode": report.get("fixtureAudioMode"),
        "audioVariant": report.get("fixtureAudioVariant"),
        "inputSource": report.get("fixtureInputSource", "originalText"),
        "forcedMLXDiagnostic": report.get("forcedMLXDiagnostic", False),
        "asrRecognizer": report.get("fixtureASRRecognizer"),
        "asrReportSha256": report.get("fixtureASRReportSha256"),
        "requestedCases": len(rows),
        "byLocale": by_locale,
        "byLocaleAndScenario": score_scenarios(scored, test_pack[1] if test_pack else ()),
        "scoredCases": scored,
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# iOS candidate: synthetic voice form",
        "",
        f"Test pack: {summary['testPack'] or 'legacy'}; audio: {summary['audioMode']}/{summary['audioVariant']}.",
        f"Device: {summary['deviceModel']}, iOS {summary['systemVersion']}.",
        f"Parser input: {summary['inputSource']} ({summary['asrRecognizer'] or 'original'}).",
        "",
        "| Locale | Input strict | Input equivalent | Analyzer strict | Analyzer equivalent | Classic strict | Classic equivalent |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for locale, metrics in by_locale.items():

        def ratio(count: int, total: int) -> str:
            return f"{count}/{total}" if total else "not measured"

        lines.append(
            f"| {locale} | {ratio(metrics['goldTextExactCases'], metrics['goldTextScoredCases'])} | "
            f"{ratio(metrics['goldTextEquivalentExactCases'], metrics['goldTextScoredCases'])} | "
            f"{ratio(metrics['speechAnalyzer']['exactCases'], metrics['speechAnalyzer']['scoredCases'])} | "
            f"{ratio(metrics['speechAnalyzer']['equivalentExactCases'], metrics['speechAnalyzer']['scoredCases'])} | "
            f"{ratio(metrics['sfSpeechRecognizer']['exactCases'], metrics['sfSpeechRecognizer']['scoredCases'])} | "
            f"{ratio(metrics['sfSpeechRecognizer']['equivalentExactCases'], metrics['sfSpeechRecognizer']['scoredCases'])} |"
        )
    if summary["byLocaleAndScenario"]:
        lines.extend(
            [
                "",
                "| Locale / scenario | Cases | Input exact | Analyzer ASR | Analyzer exact | Classic ASR | Classic exact |",
                "|---|---:|---:|---:|---:|---:|---:|",
            ]
        )
        for key, metrics in summary["byLocaleAndScenario"].items():
            total = metrics["cases"]

            def stage_ratio(engine: str, numerator: str, attempted: str) -> str:
                return f"{metrics[engine][numerator]}/{total}" if metrics[engine][attempted] else "not run"

            lines.append(
                f"| {key} | {total} | {metrics['goldTextExactCases']}/{total} | "
                f"{stage_ratio('speechAnalyzer', 'asrCompleted', 'asrAttempted')} | "
                f"{stage_ratio('speechAnalyzer', 'exactCases', 'parseAttempted')} | "
                f"{stage_ratio('sfSpeechRecognizer', 'asrCompleted', 'asrAttempted')} | "
                f"{stage_ratio('sfSpeechRecognizer', 'exactCases', 'parseAttempted')} |"
            )
    lines.extend(
        [
            "",
            "Unavailable ASR or parsing is excluded from accuracy denominators and listed per case in results.json.",
            "",
        ]
    )
    (output_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    return summary
