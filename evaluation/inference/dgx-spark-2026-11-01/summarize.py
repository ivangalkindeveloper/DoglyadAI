"""Summarize saved observations without rerunning inference."""
from __future__ import annotations

import argparse
import csv
import json
import statistics
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", default=str(Path(__file__).with_name("artifacts")))
    args = parser.parse_args()
    directory = Path(args.directory)
    output = {"variants": {}, "checks": {}}
    rows = []
    for variant in ["eager-1", "compiled-1", "eager-8", "compiled-8"]:
        path = directory/f"{variant}.json"
        if not path.exists():
            output["variants"][variant] = {"is_complete": False, "error": "No result file"}
            continue
        result = json.loads(path.read_text())
        samples = [r for b in result["batches"] for r in b["samples"]]
        structured = [r for r in samples if r["case"] not in ("short", "long")]
        summaries = []
        for recorded in result["summaries"]:
            summary = {k: v for k, v in recorded.items() if not k.startswith("decode_tokens_per_second")}
            measured = [r for b in result["batches"]
                        if b["is_measured"] and b["case"] == summary["case"] and b["concurrency"] == summary["concurrency"]
                        for r in b["samples"] if r["is_success"]]
            # The last visible text chunk can precede the final special tokens.
            # Use the full stream completion, never the last nonempty content.
            rates = sorted((r["output_tokens"]-1)/(r["total_seconds"]-r["ttft_seconds"]) for r in measured)
            summary["stream_decode_tokens_per_second_p50"] = statistics.median(rates)
            summaries.append(summary)
        output["variants"][variant] = {
            "is_complete": "finished_at" in result,
            "total_requests_including_warmup": len(samples),
            "successful_requests": sum(r["is_success"] for r in samples),
            "structured_requests": len(structured),
            "valid_structured_requests": sum(r.get("is_schema_valid", False) and r.get("is_case_match", False) for r in structured),
            "fixed_prompt_tokens": {case: sorted({r["input_tokens"] for r in samples if r["case"] == case and "input_tokens" in r}) for case in ("short", "long")},
            "summaries": summaries,
        }
        for summary in summaries:
            rows.append({"variant": variant, **summary})
        telemetry_path = directory/f"{variant}.telemetry.jsonl"
        if telemetry_path.exists():
            telemetry = [json.loads(line) for line in telemetry_path.read_text().splitlines()]
            if telemetry:
                output["variants"][variant]["min_available_ram_gib_during_benchmark"] = min(t["memory"]["MemAvailable"] for t in telemetry)/1024**3
                output["variants"][variant]["max_swap_used_gib_during_benchmark"] = max(t["memory"]["SwapTotal"]-t["memory"]["SwapFree"] for t in telemetry)/1024**3
        service_path = directory/f"{variant}.service.json"
        if service_path.exists():
            probes = json.loads(service_path.read_text())["batches"]
            output["variants"][variant]["service_probes"] = [
                {"capacity": b["service_capacity"], "clients": b["clients"], "wall_seconds": b["wall_seconds"],
                 "success": sum(r["is_success"] for r in b["samples"]),
                 "errors": [r["error_type"] for r in b["samples"] if not r["is_success"]]}
                for b in probes
            ]
        metrics = directory/f"{variant}.metrics-after.txt"
        if metrics.exists():
            output["variants"][variant]["preemptions_total"] = sum(float(line.rsplit(" ", 1)[1]) for line in metrics.read_text().splitlines() if line.startswith("vllm:num_preemptions_total{"))
    conditions = json.loads((directory/"conditions.json").read_text())
    if "after" in conditions:
        output["checks"]["is_restored"] = conditions["is_restored"]
        output["checks"]["is_boot_unchanged"] = conditions["before"]["boot_id"] == conditions["after"]["boot_id"]
        output["checks"]["are_other_containers_unrestarted"] = all(
            b["started_at"] == a["started_at"] and b["restart_count"] == a["restart_count"]
            for b, a in zip(conditions["before"]["containers"][1:], conditions["after"]["containers"][1:])
        )
        output["checks"]["kernel_check"] = conditions["kernel_check"]
    output["startup"] = [{k: v[k] for k in ["variant", "startup_seconds", "memory_ready", "error", "benchmark_exit", "service_probe_exit"] if k in v}
                         for v in conditions["variants"]]
    (directory/"summary.json").write_text(json.dumps(output, indent=2))
    if rows:
        with (directory/"summary.csv").open("w") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
