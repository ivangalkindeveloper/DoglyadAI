"""Summarize the completed rollout without treating schema validity as clinical quality."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    validations = json.loads((ROOT / "validation.json").read_text())
    summary = json.loads((ROOT / "summary.json").read_text())
    counters = json.loads((ROOT / "counters.json").read_text())
    assert len(validations) == 120 and len(counters) == 30
    result = {}
    for profile in ["baseline", "ngram8"]:
        rows = [r for r in validations if r["profile"] == profile]
        telemetry = [
            json.loads(line)
            for line in (ROOT / profile / "telemetry.jsonl").read_text().splitlines()
        ]
        metric_rows = [r for r in counters if r["profile"] == profile]
        result[profile] = {
            "requests_including_warmup": len(rows),
            "measured_requests": sum(r["wave"] != "warmup" for r in rows),
            "all_natural_stop": all(r["natural_stop"] for r in rows),
            "all_schema_valid": all(r["schema_valid"] for r in rows),
            "all_vision_correct": all(r.get("vision_match", True) for r in rows),
            "maximum_sentence_copies": max(
                r.get("maximum_sentence_copies", 0) for r in rows
            ),
            "main_failures": [r for r in rows if r.get("validation_error")],
            "over_120_seconds": [r for r in rows if r["over_120_seconds"]],
            "minimum_available_gib": min(
                r["memory_kib"]["MemAvailable"] for r in telemetry
            )
            / 1024**2,
            "maximum_temperature_c": max(
                int(r["gpu"].split(",")[0]) for r in telemetry
            ),
            "oom_kill_delta": telemetry[-1]["vmstat"]["oom_kill"]
            - telemetry[0]["vmstat"]["oom_kill"],
            "exact_request_accounting": all(
                r["deltas"]["vllm:request_success_total"] == 4 for r in metric_rows
            ),
            "preemptions": sum(
                r["deltas"].get("vllm:num_preemptions_total", 0) for r in metric_rows
            ),
            "draft_tokens": sum(
                r["deltas"].get("vllm:spec_decode_num_draft_tokens_total", 0)
                for r in metric_rows
            ),
            "accepted_tokens": sum(
                r["deltas"].get("vllm:spec_decode_num_accepted_tokens_total", 0)
                for r in metric_rows
            ),
        }
    baseline_failures = {
        (r["model"], r["case"], r["validation_error"])
        for r in result["baseline"]["main_failures"]
    }
    result["new_validation_failures"] = [
        r
        for r in result["ngram8"]["main_failures"]
        if (r["model"], r["case"], r["validation_error"]) not in baseline_failures
    ]
    result["all_prompt_ids_identical"] = all(
        r["same_prompt_ids"] for r in validations if r["profile"] == "ngram8"
    )
    result["identical_outputs"] = sum(
        r["same_output"] for r in validations if r["profile"] == "ngram8"
    )
    (ROOT / "acceptance.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )
    lines = [
        "| Модель | Без N-gram, с | N-gram 8, с | Ускорение | TTFT без / N-gram, с | Токенов без / N-gram |",
        "|---|---:|---:|---:|---:|---|",
    ]
    for model in ["4b", "15-4b", "27b"]:
        a = next(
            r for r in summary if r["profile"] == "baseline" and r["model"] == model
        )
        b = next(r for r in summary if r["profile"] == "ngram8" and r["model"] == model)
        lines.append(
            f"| {model} | {a['median_seconds']:.2f} | {b['median_seconds']:.2f} | {a['median_seconds'] / b['median_seconds']:.2f}× | {a['median_ttft']:.2f} / {b['median_ttft']:.2f} | {a['completion_tokens']} / {b['completion_tokens']} |"
        )
    lines += [
        "",
        "Медианы восьми запросов на модель: две серии 4/4/4. Прогрев исключён.",
        "",
        "| Серия | Без N-gram, с | N-gram 8, с |",
        "|---|---:|---:|",
    ]
    waves = {
        profile: {
            w["wave"]: w
            for w in [
                json.loads(line)
                for line in (ROOT / profile / "results.jsonl").read_text().splitlines()
            ]
        }
        for profile in ["baseline", "ngram8"]
    }
    for wave in ["report-1", "report-2", "mixed-1", "mixed-2"]:
        lines.append(
            f"| {wave} | {waves['baseline'][wave]['seconds']:.2f} | {waves['ngram8'][wave]['seconds']:.2f} |"
        )
    (ROOT / "RESULTS.md").write_text("\n".join(lines) + "\n")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
