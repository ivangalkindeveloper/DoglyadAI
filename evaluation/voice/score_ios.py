from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

from evaluation.voice.asr import word_error_rate
from evaluation.voice.audio_reference import report_word_references
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.spoken_wer import spoken_normalized_wer

SUPPORTED_FIELDS = (
    "patientName",
    "patientGender",
    "patientDateOfBirth",
    "patientHeightCM",
    "patientWeightKG",
    "patientComplaints",
    "examinationDescription",
)


TEXT_FIELDS = {"patientName", "patientComplaints", "examinationDescription"}


def _normalized_text(value: str, *, fold_yo: bool = False) -> str:
    # Ignore typography, case, and sentence boundaries, while retaining every
    # word and digit. A decimal separator inside a number stays significant.
    value = value.casefold()
    if fold_yo:
        # Russian ASR commonly omits the dots in ё; this does not change a
        # dictated clinical finding, but names retain their literal spelling.
        value = value.replace("ё", "е")
    value = re.sub(r"(?<=\d)[,.](?=\d)", "<decimal>", value)
    return " ".join(
        "".join(character if character.isalnum() or character in "<>" else " " for character in value).split()
    )


def _equal(field: str, expected: Any, actual: Any) -> bool:
    if isinstance(expected, (int, float)) and not isinstance(expected, bool):
        return isinstance(actual, (int, float)) and not isinstance(actual, bool) and float(expected) == float(actual)
    if field in TEXT_FIELDS and isinstance(expected, str) and isinstance(actual, str):
        fold_yo = field in {"patientComplaints", "examinationDescription"}
        return _normalized_text(expected, fold_yo=fold_yo) == _normalized_text(actual, fold_yo=fold_yo)
    return expected == actual


def _score_fields(expected: dict[str, Any], actual: dict[str, Any]) -> dict[str, Any]:
    matches: dict[str, bool] = {}
    for field in SUPPORTED_FIELDS:
        matches[field] = _equal(field, expected.get(field), actual.get(field))
    return {
        "matches": matches,
        "exactCase": all(matches.values()),
        "falseFilledFields": [
            field for field in SUPPORTED_FIELDS if field not in expected and actual.get(field) is not None
        ],
    }


def score_ios_report(report_path: Path, output_dir: Path) -> dict[str, Any]:
    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report["fixtureRegressionSha256"] != file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl"):
        raise ValueError("iOS report was produced from a different regression corpus")
    cases = {
        case["id"]: case
        for case in (
            json.loads(line) for line in (TEXT_OUTPUT_DIR / "regression.jsonl").read_text(encoding="utf-8").splitlines()
        )
    }
    word_references = report_word_references(report)
    rows = report["results"]
    if len({row["id"] for row in rows}) != len(rows):
        raise ValueError("Duplicate iOS case results")

    scored = []
    for row in rows:
        case = cases[row["id"]]
        item = {"id": row["id"], "locale": row["locale"], "examinationTypeId": row["examinationTypeId"]}
        asr = row["asr"]
        item["asrStatus"] = asr["status"]
        if asr["status"] == "ok":
            reference = word_references.get(case["id"], case["spokenText"])
            if report.get("fixtureAudioMode") == "extended-v2":
                item["rawLiteralWER"] = word_error_rate(reference, asr["rawText"])
                item["correctedLiteralWER"] = word_error_rate(reference, asr["correctedText"])
                item["rawWER"] = spoken_normalized_wer(reference, asr["rawText"], case["locale"])
                item["correctedWER"] = spoken_normalized_wer(reference, asr["correctedText"], case["locale"])
            else:
                item["rawWER"] = word_error_rate(reference, asr["rawText"])
                item["correctedWER"] = word_error_rate(reference, asr["correctedText"])
        for source, key in (("goldTextParse", "goldText"), ("recognizedTextParse", "recognizedText")):
            parse = row[source]
            item[f"{key}Status"] = parse["status"]
            if parse["status"] == "ok":
                item[key] = _score_fields(case["expectedFields"], parse["fields"])
        scored.append(item)

    by_locale: dict[str, Any] = {}
    for locale in ("en", "ru"):
        subset = [item for item in scored if item["locale"] == locale]
        asr_ok = [item for item in subset if item["asrStatus"] == "ok"]
        gold_ok = [item for item in subset if item["goldTextStatus"] == "ok"]
        recognized_ok = [item for item in subset if item["recognizedTextStatus"] == "ok"]
        by_locale[locale] = {
            "cases": len(subset),
            "asrStatuses": dict(Counter(item["asrStatus"] for item in subset)),
            "goldTextParseStatuses": dict(Counter(item["goldTextStatus"] for item in subset)),
            "recognizedTextParseStatuses": dict(Counter(item["recognizedTextStatus"] for item in subset)),
            "meanRawWER": sum(item["rawWER"] for item in asr_ok) / len(asr_ok) if asr_ok else None,
            "meanCorrectedWER": sum(item["correctedWER"] for item in asr_ok) / len(asr_ok) if asr_ok else None,
            "meanCorrectedLiteralWER": sum(item.get("correctedLiteralWER", item["correctedWER"]) for item in asr_ok)
            / len(asr_ok)
            if asr_ok
            else None,
            "goldTextExactCases": sum(item["goldText"]["exactCase"] for item in gold_ok),
            "recognizedTextExactCases": sum(item["recognizedText"]["exactCase"] for item in recognized_ok),
            "goldTextScoredCases": len(gold_ok),
            "recognizedTextScoredCases": len(recognized_ok),
        }

    summary = {
        "schemaVersion": 1,
        "platform": report["platform"],
        "systemVersion": report["systemVersion"],
        "deviceModel": report["deviceModel"],
        "regressionSha256": report["fixtureRegressionSha256"],
        "audioManifestSha256": report["fixtureAudioManifestSha256"],
        "audioMode": report.get("fixtureAudioMode"),
        "audioVariant": report.get("fixtureAudioVariant"),
        "promptSha256": report["fixturePromptSha256"],
        "contextualStringsSha256": report["fixtureContextualStringsSha256"],
        "applicationSha256": report["fixtureApplicationSha256"],
        "sourceFilesSha256": report["fixtureSourceFilesSha256"],
        "requestedCases": len(rows),
        "examinationNumber": "unsupported_by_current_response_model",
        "byLocale": by_locale,
        "scoredCases": scored,
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def fraction(numerator: int, denominator: int) -> str:
        return f"{numerator}/{denominator}" if denominator else "н/д"

    lines = [
        "# iOS baseline: синтетическая диктовка",
        "",
        f"Устройство: {summary['deviceModel']}, iOS {summary['systemVersion']}. Случаев: {len(rows)}.",
        "В текущем ответе модели нет номера исследования; поле отмечено как неподдерживаемое.",
        "",
        "| Локаль | ASR завершён | Разбор исходного текста | Разбор после ASR | Полностью верные формы |",
        "|---|---:|---:|---:|---:|",
    ]
    for locale, metrics in by_locale.items():
        if not metrics["cases"]:
            continue
        lines.append(
            f"| {locale} | {fraction(metrics['asrStatuses'].get('ok', 0), metrics['cases'])} | "
            f"{fraction(metrics['goldTextScoredCases'], metrics['cases'])} | "
            f"{fraction(metrics['recognizedTextScoredCases'], metrics['cases'])} | "
            f"{fraction(metrics['recognizedTextExactCases'], metrics['recognizedTextScoredCases'])} |"
        )
    lines.extend(
        [
            "",
            "«н/д» означает, что качество не измерено. Причины отказа по случаям находятся в `results.json`.",
            "Файловый прогон не проверяет физический микрофон и применение результата в UI формы.",
            "",
        ]
    )
    (output_dir / "summary.md").write_text("\n".join(lines), encoding="utf-8")
    return summary
