"""Validate synthetic engine trials and summarize warm streaming performance."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
import re
import statistics
import sys

from jsonschema.validators import validator_for

DIRECTORY = Path(__file__).resolve().parent
ROOT = DIRECTORY.parents[3]
sys.path.insert(0, str(ROOT / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration  # noqa: E402
from app.service.dictation.voice_form_validator import VoiceFormValidator  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402


def measurement_screen(value: dict, source: str) -> dict:
    """Flag literal omissions/new numbers; this does not validate medical meaning."""
    description = value.get("description") or ""
    normalized = re.sub(r"\s+", "", description.lower()).replace(",", ".")
    normalized = normalized.replace("x", "×").replace("х", "×")
    expected = ("52×18×16мм", "50×17×15мм", "7.4мл", "6.3мл", "13.7мл", "4мм")

    def numbers(text: str) -> set[str]:
        return {x.replace(",", ".") for x in re.findall(r"\d+(?:[.,]\d+)?", text)}

    return {
        "missing_literal_measurements": [x for x in expected if x not in normalized],
        "description_numbers_absent_from_source": sorted(
            numbers(description) - numbers(source)
        ),
        "scope": "Literal screen only; no side, unit conversion, or clinical validation.",
    }


def main() -> None:
    cases = {
        c["id"]: c for c in json.loads((DIRECTORY / "extended-cases.json").read_text())
    }
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    reports = ReportGenerationService(configuration, MockNeuralModelService())
    voice = VoiceFormValidator(configuration.voice_source_localization(LanguageCode.RU))
    summary = {}
    all_validated = {}
    for path in sorted(DIRECTORY.glob("*/results.jsonl")):
        if (path.parent / "failure.json").exists():
            continue
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        validated = []
        for row in rows:
            if (
                row.get("phase") not in ("quality", "quality_parallel", "performance")
                or "id" not in row
            ):
                continue
            case = cases[row["id"]]
            result = {
                k: row.get(k)
                for k in (
                    "id",
                    "kind",
                    "phase",
                    "finish",
                    "seconds",
                    "first_delta_seconds",
                    "usage",
                    "error",
                    "concurrency",
                    "repetition",
                )
            }
            result.update(schema_valid=False, main_valid=False)
            sentence_copies = Counter(
                " ".join(s.split())
                for s in re.split(r"(?<=[.!?])\s+", row["text"])
                if len(s) >= 40
            )
            result["maximum_raw_sentence_copies"] = max(
                sentence_copies.values(), default=0
            )
            try:
                value = json.loads(row["text"])
                if case["kind"] in {"historical", "report", "conflict"}:
                    result["description_remarks_characters"] = len(
                        value.get("descriptionRemarks") or ""
                    )
                    result["measurement_screen"] = measurement_screen(
                        value, case["body"]["examinationData"]["examinationDescription"]
                    )
                validator_for(case["schema"])(case["schema"]).validate(value)
                result["schema_valid"] = True
                if case["kind"] == "vision":
                    result["vision_expected_match"] = value == case["expected"]
                    result["main_valid"] = None
                elif case["kind"] == "dictation":
                    result["validated_value"] = voice.validate(
                        USVoiceFormGeneration.model_validate(value), case["transcript"]
                    ).model_dump(mode="json")
                    result["main_valid"] = True
                else:
                    reports.complete(
                        row["text"],
                        USExaminationRequest.model_validate(case["body"]),
                        model_id=case["model"],
                        language_code=LanguageCode.RU,
                    )
                    result["main_valid"] = True
            except Exception as error:
                result["validation_error"] = getattr(
                    error, "code", type(error).__name__
                )
            validated.append(result)
        (path.parent / "validation.json").write_text(
            json.dumps(validated, ensure_ascii=False, indent=2) + "\n"
        )
        quality = [r for r in validated if r["phase"] == "quality"]
        groups = {}
        for kind in sorted({r["kind"] for r in quality}):
            group = [r for r in quality if r["kind"] == kind]
            groups[kind] = {
                "count": len(group),
                "finish": dict(Counter(r["finish"] for r in group)),
                "schema_valid": sum(r["schema_valid"] for r in group),
                "main_valid": sum(bool(r["main_valid"]) for r in group),
                "vision_expected_match": sum(
                    r.get("vision_expected_match", False) for r in group
                ),
            }
        perf = {}
        for concurrency in sorted(
            {r["concurrency"] for r in validated if r["phase"] == "performance"}
        ):
            group = [
                r
                for r in rows
                if r.get("phase") == "performance"
                and r.get("concurrency") == concurrency
                and "id" in r
            ]
            checked = [
                r
                for r in validated
                if r["phase"] == "performance" and r["concurrency"] == concurrency
            ]
            waves = [
                r
                for r in rows
                if r.get("event") == "wave"
                and r.get("phase") == "performance"
                and r["concurrency"] == concurrency
            ]

            def median(key: str) -> float:
                return statistics.median(
                    r[key] for r in group if r.get(key) is not None
                )

            perf[str(concurrency)] = {
                "requests": len(group),
                "ttft_median_seconds": median("first_delta_seconds"),
                "latency_median_seconds": median("seconds"),
                "decode_median_tokens_per_second_approx": median(
                    "decode_tokens_per_second_approx"
                ),
                "completion_tokens_median": statistics.median(
                    r["usage"]["completion_tokens"] for r in group
                ),
                "aggregate_tokens_per_second": sum(
                    r["completion_tokens"] for r in waves
                )
                / sum(r["seconds"] for r in waves)
                if waves
                else None,
                "schema_valid": sum(r["schema_valid"] for r in checked),
                "main_valid": sum(bool(r["main_valid"]) for r in checked),
                "finish": dict(Counter(r["finish"] for r in group)),
            }
        controls = [
            r for r in quality if r["kind"] != "vision" and "penalty105" not in r["id"]
        ]
        summary[path.parent.name] = {
            "controls": {
                "count": len(controls),
                "finish": dict(Counter(r["finish"] for r in controls)),
                "loop_to_limit": sum(
                    r["finish"] == "length" and r["maximum_raw_sentence_copies"] >= 3
                    for r in controls
                ),
                "schema_valid": sum(r["schema_valid"] for r in controls),
                "main_valid": sum(bool(r["main_valid"]) for r in controls),
            },
            "penalty105_checks": [r for r in quality if "penalty105" in r["id"]],
            "parallel_quality": [
                r for r in validated if r["phase"] == "quality_parallel"
            ],
            "quality": groups,
            "performance": perf,
        }
        all_validated[path.parent.name] = {
            r["id"]: r for r in rows if r.get("phase") == "quality"
        }
    comparisons = []
    reference = all_validated.get("vllm-maxseq-1", {})
    for name, values in all_validated.items():
        if name == "vllm-maxseq-1":
            continue
        for identifier in sorted(reference.keys() & values.keys()):
            left, right = reference[identifier], values[identifier]
            comparisons.append(
                {
                    "trial": name,
                    "id": identifier,
                    "text_equal": left["text"] == right["text"],
                    "prompt_token_ids_equal": left.get("prompt_token_ids")
                    == right.get("prompt_token_ids")
                    if left.get("prompt_token_ids") is not None
                    and right.get("prompt_token_ids") is not None
                    else None,
                    "output_token_ids_equal": left.get("output_token_ids")
                    == right.get("output_token_ids")
                    if left.get("output_token_ids") and right.get("output_token_ids")
                    else None,
                }
            )
    (DIRECTORY / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n"
    )
    (DIRECTORY / "paired-comparison.json").write_text(
        json.dumps(comparisons, indent=2) + "\n"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
