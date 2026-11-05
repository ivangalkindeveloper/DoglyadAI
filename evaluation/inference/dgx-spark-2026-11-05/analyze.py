"""Validate retained evidence and summarize each study without hiding failures."""

from __future__ import annotations

from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import statistics
import sys

from jsonschema.validators import validator_for

ROOT = Path(__file__).resolve().parent
REPOSITORY = ROOT.parents[2]
sys.path.insert(0, str(REPOSITORY / "backend/main"))
from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration  # noqa: E402
from app.service.dictation.voice_form_validator import VoiceFormValidator  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402


def save(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def median(values: list) -> float | None:
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


def strings(value: object) -> list[str]:
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        return [s for v in value.values() for s in strings(v)]
    if isinstance(value, list):
        return [s for v in value for s in strings(v)]
    return []


def copies(value: object) -> int:
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
            for field in strings(value)
        ),
        default=0,
    )


def counters(raw: str) -> dict:
    result = defaultdict(float)
    for line in raw.splitlines():
        if line.startswith("vllm:"):
            name = line.split("{", 1)[0].split()[0]
            if name.endswith("_total") and any(
                key in name
                for key in [
                    "preempt",
                    "prefix",
                    "spec_decode",
                    "request_success",
                    "prompt_tokens",
                    "generation_tokens",
                ]
            ):
                result[name] += float(line.split()[-1])
    return dict(result)


def main() -> None:
    expected_hashes = json.loads((ROOT / "validation-source-hashes.json").read_text())
    changed_sources = [
        path
        for path, expected in expected_hashes.items()
        if hashlib.sha256((REPOSITORY / path).read_bytes()).hexdigest() != expected
    ]
    if changed_sources:
        raise RuntimeError(
            f"Validation source changed; use the recorded source revision: {changed_sources}"
        )
    configuration = ConfigurationLoader(
        REPOSITORY / "backend/main/config/development"
    ).load()
    reports = ReportGenerationService(configuration, MockNeuralModelService())
    voice = VoiceFormValidator(configuration.voice_source_localization(LanguageCode.RU))
    all_summary = {}
    baseline = {}
    for source in sorted(
        (ROOT / "05-speculative-decoding").glob("*/baseline/results.jsonl")
    ):
        for line in source.read_text().splitlines():
            r = json.loads(line)
            if r["event"] == "request" and r["wave"] >= 0:
                baseline.setdefault((r["model_key"], r["group"]), r)
    for study in sorted(ROOT.glob("0[1-5]-*")):
        summary = []
        for source in sorted(study.glob("*/*/results.jsonl")):
            model, profile = source.parent.parent.name, source.parent.name
            cases = {
                c["id"]: c
                for c in json.loads((ROOT / f"cases-{model}.json").read_text())
            }
            rows = [json.loads(line) for line in source.read_text().splitlines()]
            grouped = defaultdict(list)
            for row in rows:
                grouped[row["group"]].append(row)
            for group, records in grouped.items():
                inputs = next(
                    (r["settings"] for r in records if r["event"] == "input"), {}
                )
                requests = [
                    r for r in records if r["event"] == "request" and r["wave"] >= 0
                ]
                waves = [r for r in records if r["event"] == "wave" and r["wave"] >= 0]
                expected_waves = inputs.get("repetitions", 3)
                expected_requests = expected_waves * inputs.get("concurrency", 1)
                entry = {
                    "model": model,
                    "profile": profile,
                    "group": group,
                    "measured_requests": len(requests),
                    "expected_requests": expected_requests,
                    "complete": len(requests) == expected_requests
                    and len(waves) == expected_waves
                    and all(r["valid"] for r in waves),
                    "concurrency": inputs.get("concurrency", 1),
                    "fixed_tokens": inputs.get("fixed_tokens"),
                    "requests_over_120_seconds": sum(
                        r["seconds"] > 120 for r in requests
                    ),
                    "ttft_seconds": median([r["ttft"] for r in requests]),
                    "latency_seconds": median([r["seconds"] for r in requests]),
                    "wave_seconds": median([r["seconds"] for r in waves]),
                    "wave_tokens_per_second": median(
                        [r["tokens"] / r["seconds"] for r in waves]
                    ),
                    "prompt_tokens": sorted(
                        {r["usage"].get("prompt_tokens", 0) for r in requests}
                    ),
                    "completion_tokens": [
                        r["usage"].get("completion_tokens", 0) for r in requests
                    ],
                    "median_delta_gap_seconds": median(
                        [r.get("median_delta_gap") for r in requests]
                    ),
                    "maximum_delta_gap_seconds": max(
                        (
                            r["maximum_delta_gap"]
                            for r in requests
                            if r.get("maximum_delta_gap") is not None
                        ),
                        default=None,
                    ),
                    "latency_range_seconds": [
                        min((r["seconds"] for r in requests), default=None),
                        max((r["seconds"] for r in requests), default=None),
                    ],
                }
                metric_rows = {
                    r["event"]: counters(r["metrics"])
                    for r in records
                    if r["event"].startswith("metrics_")
                }
                before, after = (
                    metric_rows.get("metrics_before", {}),
                    metric_rows.get("metrics_after", {}),
                )
                entry["counter_deltas_including_warmup"] = {
                    name: value - before.get(name, 0) for name, value in after.items()
                }
                validation = []
                if study.name.startswith("05"):
                    case = cases[group]
                    for row in requests:
                        reference = baseline.get((model, group))
                        verdict = {
                            "wave": row["wave"],
                            "schema_valid": False,
                            "main_valid": None if case["kind"] == "vision" else False,
                            "finish": row["finish"],
                            "natural_stop": row["done"] and row["finish"] == "stop",
                            "error": row.get("error"),
                            "prompt_ids_match_baseline": bool(
                                reference
                                and row.get("prompt_token_ids") is not None
                                and row.get("prompt_token_ids")
                                == reference.get("prompt_token_ids")
                            ),
                            "text_matches_baseline": bool(
                                reference and row["text"] == reference["text"]
                            ),
                        }
                        if case["kind"] == "vision":
                            verdict["vision_expected_match"] = False
                        try:
                            value = json.loads(row["text"])
                            cls = validator_for(case["schema"])
                            cls.check_schema(case["schema"])
                            cls(case["schema"]).validate(value)
                            verdict["schema_valid"] = True
                            verdict["maximum_sentence_copies"] = copies(value)
                            if case["kind"] == "vision":
                                verdict["vision_expected_match"] = (
                                    value == case["expected"]
                                )
                            elif case["kind"] == "dictation":
                                voice.validate(
                                    USVoiceFormGeneration.model_validate(value),
                                    case["transcript"],
                                )
                                verdict["main_valid"] = True
                            else:
                                verdict["main_valid"] = False
                                reports.complete(
                                    row["text"],
                                    USExaminationRequest.model_validate(case["body"]),
                                    model_id=case["model"],
                                    language_code=LanguageCode(
                                        case.get("language", "ru")
                                    ),
                                )
                                verdict["main_valid"] = True
                        except Exception as error:
                            verdict["validation_error"] = getattr(
                                error, "code", type(error).__name__
                            )
                        validation.append(verdict)
                    entry["validation"] = validation
                summary.append(entry)
        save(study / "summary.json", summary)
        all_summary[study.name] = summary
    plans = json.loads((ROOT / "plan.json").read_text())
    if (ROOT / "prefix-plan.json").exists():
        plans += json.loads((ROOT / "prefix-plan.json").read_text())
    if (ROOT / "cache-pressure-plan.json").exists():
        plans += json.loads((ROOT / "cache-pressure-plan.json").read_text())
    expected = {
        (g["study"], p["model_key"], p["profile"], g["id"])
        for p in plans
        for g in p["groups"]
    }
    observed = {
        (study, r["model"], r["profile"], r["group"]): r["complete"]
        for study, rows in all_summary.items()
        for r in rows
    }
    accounting = []
    for plan in plans:
        events = []
        for group in plan["groups"]:
            source = (
                ROOT
                / group["study"]
                / plan["model_key"]
                / plan["profile"]
                / "results.jsonl"
            )
            if source.exists():
                events += [
                    row
                    for line in source.read_text().splitlines()
                    if (row := json.loads(line))["group"] == group["id"]
                ]
        metric_events = [row for row in events if row["event"].startswith("metrics_")]
        requests = [row for row in events if row["event"] == "request"]
        if not metric_events:
            continue
        count_before = counters(metric_events[0]["metrics"]).get(
            "vllm:request_success_total", 0
        )
        count_after = counters(metric_events[-1]["metrics"]).get(
            "vllm:request_success_total", 0
        )
        accounting.append(
            {
                "model": plan["model_key"],
                "profile": plan["profile"],
                "observed_requests_including_warmup": len(requests),
                "engine_success_counter_delta": count_after - count_before,
                "ends_after_last_group": metric_events[-1]["event"] == "metrics_after"
                and metric_events[-1]["group"] == plan["groups"][-1]["id"],
                "counter_matches_observed": count_after - count_before == len(requests),
                "client_errors": sum(bool(r.get("error")) for r in requests),
            }
        )
    save(ROOT / "request-accounting.json", accounting)
    save(
        ROOT / "completeness.json",
        {
            "expected_groups": len(expected),
            "observed_groups": len(observed),
            "missing_groups": sorted(expected - observed.keys()),
            "incomplete_groups": sorted(
                key for key, valid in observed.items() if not valid
            ),
            "startup_or_probe_failures": [
                str(p.relative_to(ROOT)) for p in ROOT.glob("runs/*/failure.json")
            ],
        },
    )
    print(
        json.dumps(
            {
                "expected_groups": len(expected),
                "observed_groups": len(observed),
                "complete_groups": sum(observed.values()),
            }
        )
    )


if __name__ == "__main__":
    main()
