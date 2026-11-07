"""Separate cache timing, complete report validity, and fixed-token scheduling."""

from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parent
REPOSITORY = ROOT.parents[2]
sys.path.insert(0, str(REPOSITORY / "backend/main"))

from app.core.configuration.configuration_loader import ConfigurationLoader  # noqa: E402
from app.core.localization.language_code import LanguageCode  # noqa: E402
from app.model.ultrasound.us_examination_request import USExaminationRequest  # noqa: E402
from app.service.neural_model.mock_neural_model_service import MockNeuralModelService  # noqa: E402
from app.service.report.report_generation_service import ReportGenerationService  # noqa: E402
from jsonschema.validators import validator_for  # noqa: E402


def read(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines()]


def median(values: list) -> float | None:
    usable = [value for value in values if value is not None]
    return statistics.median(usable) if usable else None


def counters(raw: str) -> dict:
    result = defaultdict(float)
    for line in raw.splitlines():
        if line.startswith("vllm:"):
            name = line.split("{", 1)[0].split()[0]
            if name in {
                "vllm:request_success_total",
                "vllm:num_preemptions_total",
                "vllm:prefix_cache_hits_total",
            }:
                result[name] += float(line.split()[-1])
    return dict(result)


def main() -> None:
    output = {}
    fixed = ROOT / "prefix-fixed.jsonl"
    if fixed.exists():
        groups = defaultdict(list)
        rows = read(fixed)
        for row in rows:
            if row["event"] != "request":
                continue
            assert (
                row["is_fixed_token_probe"]
                and row["done"]
                and row["usage"]["completion_tokens"] == 16
            )
            model, scenario, variant, _ = row["case_id"].split(":")
            groups[(model, scenario, variant, row["phase"])].append(row)
        summary = []
        for key, values in sorted(groups.items()):
            summary.append(
                {
                    "model": key[0],
                    "scenario": key[1],
                    "variant": key[2],
                    "phase": key[3],
                    "requests": len(values),
                    "median_ttft": median([row["ttft"] for row in values]),
                    "range_ttft": [
                        min(row["ttft"] for row in values),
                        max(row["ttft"] for row in values),
                    ],
                    "cached_tokens": sorted(
                        {
                            row["metrics_after"].get("vllm:prefix_cache_hits_total", 0)
                            - row["metrics_before"].get(
                                "vllm:prefix_cache_hits_total", 0
                            )
                            for row in values
                        }
                    ),
                    "prompt_tokens": sorted(
                        {row["usage"]["prompt_tokens"] for row in values}
                    ),
                }
            )
        output["prefix_fixed"] = {
            "complete": rows[-1]["event"] == "complete",
            "requests": sum(len(g) for g in groups.values()),
            "summary": summary,
        }
    service = ReportGenerationService(
        ConfigurationLoader(REPOSITORY / "backend/main/config/development").load(),
        MockNeuralModelService(),
    )
    cases = {case["id"]: case for case in json.loads((ROOT / "cases.json").read_text())}
    prefill, references, validations, metric_checks = [], {}, [], []
    for budget in (2048, 4096):
        path = ROOT / "prefill-live" / f"budget{budget}" / "results.jsonl"
        if not path.exists():
            continue
        for wave in read(path):
            for container, data in wave["metrics_after"].items():
                before = counters(wave["metrics_before"][container]["metrics"])
                after = counters(data["metrics"])
                delta = {
                    key: value - before.get(key, 0) for key, value in after.items()
                }
                metric_checks.append(
                    {
                        "budget": budget,
                        "wave": wave["wave"],
                        "container": container,
                        "expected_completions": wave["concurrency_per_model"],
                        "actual_completions": delta.get(
                            "vllm:request_success_total", 0
                        ),
                        "preemptions": delta.get("vllm:num_preemptions_total", 0),
                    }
                )
            for model in ("4b", "15-4b", "27b"):
                rows = [row for row in wave["requests"] if row["model"] == model]
                prefill.append(
                    {
                        "budget": budget,
                        "wave": wave["wave"],
                        "model": model,
                        "requests": len(rows),
                        "wave_seconds": wave["seconds"],
                        "median_seconds": median([row["seconds"] for row in rows]),
                        "median_ttft": median([row["ttft"] for row in rows]),
                        "max_delta_gap": max(
                            row["maximum_delta_gap"] or 0 for row in rows
                        ),
                        "output_tokens": [
                            row["usage"].get("completion_tokens") for row in rows
                        ],
                        "over120": sum(row["seconds"] > 120 for row in rows),
                    }
                )
                for row in rows:
                    key = (wave["wave"], model, row["client"])
                    if budget == 2048:
                        references[key] = row
                    reference = references.get(key)
                    item = {
                        "budget": budget,
                        "wave": wave["wave"],
                        "model": model,
                        "client": row["client"],
                        "transport_complete": row["done"] and not row.get("error"),
                        "natural_stop": row["finish"] == "stop",
                        "same_input_tokens_as_2048": (
                            reference is not None
                            and row.get("prompt_token_ids") is not None
                            and row.get("prompt_token_ids")
                            == reference.get("prompt_token_ids")
                        )
                        if budget != 2048
                        else None,
                    }
                    if wave["kind"] == "technical":
                        item["planned_128_tokens"] = (
                            row["usage"].get("completion_tokens") == 128
                        )
                    else:
                        case = cases[row["case_id"]]
                        item.update(schema_valid=False, main_valid=False)
                        try:
                            schema = case["payload"]["response_format"]["json_schema"][
                                "schema"
                            ]
                            validator_for(schema)(schema).validate(
                                json.loads(row["text"])
                            )
                            item["schema_valid"] = True
                            service.complete(
                                row["text"],
                                USExaminationRequest.model_validate(case["body"]),
                                model_id=case["payload"]["model"],
                                language_code=LanguageCode(case["language"]),
                            )
                            item["main_valid"] = True
                        except Exception as error:
                            item["validation_error"] = str(
                                getattr(error, "code", type(error).__name__)
                            )
                    validations.append(item)
    if prefill:
        measured_budgets = sorted({row["budget"] for row in prefill})
        output["prefill_live"] = {
            "measured_budgets": measured_budgets,
            "both_budgets_measured": measured_budgets == [2048, 4096],
            "controller_status": json.loads(
                (ROOT / "prefill-live/status.json").read_text()
            ),
            "summary": prefill,
            "validations": validations,
            "metric_checks": metric_checks,
        }
    path = ROOT / "live-summary.json"
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({"output": str(path), "sections": list(output)}))


if __name__ == "__main__":
    main()
