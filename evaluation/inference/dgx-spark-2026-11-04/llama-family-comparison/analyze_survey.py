"""Validate completed synthetic trials and summarize comparable speed series."""

from __future__ import annotations

from collections import Counter
import hashlib
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


def _strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [s for v in value.values() for s in _strings(v)]
    if isinstance(value, list):
        return [s for v in value for s in _strings(v)]
    return []


def _copies(value: object) -> int:
    return max(
        (
            max(
                Counter(
                    " ".join(s.lower().split())
                    for s in re.findall(r"[^.!?]+[.!?]", field)
                    if len(s.strip()) >= 40
                ).values(),
                default=0,
            )
            for field in _strings(value)
        ),
        default=0,
    )


def _median(rows: list[dict], key: str) -> float | None:
    values = [row[key] for row in rows if row.get(key) is not None]
    return statistics.median(values) if values else None


def main() -> None:
    configuration = ConfigurationLoader(ROOT / "backend/main/config/development").load()
    reports = ReportGenerationService(configuration, MockNeuralModelService())
    voice = VoiceFormValidator(configuration.voice_source_localization(LanguageCode.RU))
    summary = {}
    for path in sorted(DIRECTORY.glob("*/results.jsonl")):
        plan = json.loads((path.parent / "plan.json").read_text())
        cases = {
            c["id"]: c for c in json.loads((DIRECTORY / plan["cases_file"]).read_text())
        }
        reference = {
            r["id"]: r
            for line in (DIRECTORY / f"vllm-{plan['model_key']}/results.jsonl")
            .read_text()
            .splitlines()
            if (r := json.loads(line)).get("phase") == "quality"
        }
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        validated = []
        for row in rows:
            if row.get("phase") != "quality":
                continue
            case = cases[row["id"]]
            result = {
                k: row.get(k)
                for k in ("id", "kind", "finish", "seconds", "error", "done", "usage")
            }
            result.update(
                schema_valid=False, main_valid=None, maximum_sentence_copies=None
            )
            if row["kind"] != "vision":
                actual = row.get(
                    "template_prompt_token_ids", row.get("prompt_token_ids")
                )
                result["prompt_tokens_match_vllm"] = (
                    actual == reference[row["id"]]["prompt_token_ids"]
                    if actual is not None
                    else None
                )
            try:
                value = json.loads(row["text"])
                result["maximum_sentence_copies"] = _copies(value)
                validator = validator_for(case["schema"])
                validator.check_schema(case["schema"])
                validator(case["schema"]).validate(value)
                result["schema_valid"] = True
                if case["kind"] == "vision":
                    result["vision_expected_match"] = value == case["expected"]
                elif case["kind"] == "dictation":
                    result["validated_value"] = voice.validate(
                        USVoiceFormGeneration.model_validate(value), case["transcript"]
                    ).model_dump(mode="json")
                    result["main_valid"] = True
                else:
                    result["main_valid"] = False
                    reports.complete(
                        row["text"],
                        USExaminationRequest.model_validate(case["body"]),
                        model_id=case["model"],
                        language_code=LanguageCode(case.get("language", "ru")),
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
        performance = {}
        for count in (1, 4):
            group = [
                r
                for r in rows
                if r.get("phase") == "speed" and r.get("concurrency") == count
            ]
            if not group:
                continue
            waves = [
                r
                for r in rows
                if r.get("event") == "wave"
                and r["concurrency"] == count
                and r["wave"] >= 0
            ]
            is_static = group[0].get("batching") == "static"
            valid = all(
                not r.get("error") and r["usage"].get("completion_tokens") == 256
                for r in group
            )
            complete = (
                len(group) == (5 if is_static else 5 * count)
                and valid
                and (is_static or (len(waves) == 5 and all(r["valid"] for r in waves)))
            )
            performance[str(count)] = {
                "mode": "static_batch" if is_static else "concurrent_http",
                "measured_rows": len(group),
                "all_fixed_256": valid,
                "complete_five_waves": complete,
                "ttft_seconds": _median(
                    group, "first_token_seconds" if is_static else "first_delta_seconds"
                ),
                "latency_seconds": _median(group, "seconds"),
                "decode_tokens_per_second": _median(group, "decode_tokens_per_second"),
                "aggregate_tokens_per_second": _median(group, "batch_tokens_per_second")
                if is_static
                else statistics.median(r["tokens"] / r["seconds"] for r in waves)
                if waves
                else None,
                "min_seconds": min(r["seconds"] for r in group),
                "max_seconds": max(r["seconds"] for r in group),
            }
        traffic = None
        if plan["engine"] == "vllm" and (path.parent / "activity.json").exists():
            activity = json.loads((path.parent / "activity.json").read_text())
            name = f"doglyad-dgx-vllm_medgemma_{'15_4b' if plan['model_index'] == 1 else '27b'}-1"
            totals = {
                stage: sum(
                    float(line.rsplit(" ", 1)[1])
                    for line in activity[stage][name]
                    if line.startswith("vllm:request_success_total")
                )
                for stage in ("before", "after")
            }
            expected = sum("phase" in row for row in rows)
            actual = totals["after"] - totals["before"]
            traffic = {
                "expected_requests": expected,
                "observed_requests": actual,
                "is_exclusive_test_traffic": actual == expected,
            }
        summary[path.parent.name] = {
            "model_id": plan["model_id"],
            "traffic": traffic,
            "restoration_recorded": (path.parent / "after.json").exists(),
            "trial_failed": (path.parent / "failure.json").exists(),
            "quality_count": len(validated),
            "self_completed": sum(
                r["finish"] == "stop" and not r.get("error") for r in validated
            ),
            "schema_valid": sum(r["schema_valid"] for r in validated),
            "main_valid": sum(r["main_valid"] is True for r in validated),
            "vision_correct": sum(
                r.get("vision_expected_match", False) for r in validated
            ),
            "within_field_duplicates": sum(
                (r["maximum_sentence_copies"] or 0) >= 2 for r in validated
            ),
            "prompt_mismatches": [
                r["id"] for r in validated if r.get("prompt_tokens_match_vllm") is False
            ],
            "prompt_id_checks": sum(
                r.get("prompt_tokens_match_vllm") is not None for r in validated
            ),
            "performance": performance,
        }
    sources = [
        "backend/main/app/prompt/prompt_factory.py",
        "backend/main/app/schema/us_examination_report_structured_output.py",
        "backend/main/app/service/report/report_validator.py",
        "backend/main/app/service/dictation/voice_form_validator.py",
    ]
    (DIRECTORY / "validation-source-hashes.json").write_text(
        json.dumps(
            {
                name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                for name in sources
            },
            indent=2,
        )
        + "\n"
    )
    (DIRECTORY / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
