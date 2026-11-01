"""Produce derived summaries while preserving all raw observations."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--directory", default=str(Path(__file__).with_name("artifacts"))
    )
    args = parser.parse_args()
    directory = Path(args.directory)
    summary = {"stages": {}, "telemetry": {}, "checks": {}}
    csv_rows = []
    for stage in ["baseline", "candidate"]:
        path = directory / (stage + ".json")
        if not path.exists():
            continue
        data = json.loads(path.read_text())
        samples = [r for b in data["batches"] for r in b["samples"]]
        summary["stages"][stage] = {
            "is_complete": "finished_at" in data,
            "is_all_successful": all(r["is_success"] for r in samples),
            "expected_requests": 12 if stage == "baseline" else 184,
            "requests": len(samples),
            "successful": sum(r["is_success"] for r in samples),
            "errors": [
                {k: r.get(k) for k in ["model", "case", "index", "error_type", "error"]}
                for r in samples
                if not r["is_success"]
            ],
            "structured_successful": sum(
                r.get("is_schema_valid", False) and r.get("is_case_match", False)
                for r in samples
            ),
            "summaries": data["summaries"],
        }
        csv_rows.extend({"stage": stage, **row} for row in data["summaries"])
        if stage == "candidate":
            summary["checks"]["mixed_full_http_overlap_seconds"] = [
                {
                    "label": b["label"],
                    "case": b["case"],
                    "wave": b["wave"],
                    "is_measured": b["is_measured"],
                    "seconds": max(
                        0,
                        min(r["finished_monotonic"] for r in b["samples"])
                        - max(r["started_monotonic"] for r in b["samples"]),
                    ),
                }
                for b in data["batches"]
                if b["label"].startswith("mixed-")
            ]
            summary["checks"]["preemptions_after_candidate"] = data["batches"][-1][
                "metrics_after"
            ]
    path = directory / "telemetry.jsonl"
    if path.exists():
        rows = [
            json.loads(line) for line in path.read_text().splitlines() if line.strip()
        ]
        if rows:
            summary["telemetry"]["samples"] = len(rows)
            summary["telemetry"]["first_time"] = rows[0]["time"]
            summary["telemetry"]["last_time"] = rows[-1]["time"]
            summary["telemetry"]["min_available_ram_gib"] = (
                min(r["memory"]["MemAvailable"] for r in rows) / 1024**3
            )
            summary["telemetry"]["max_swap_used_gib"] = (
                max(r["memory"]["SwapTotal"] - r["memory"]["SwapFree"] for r in rows)
                / 1024**3
            )
            summary["telemetry"]["max_gpu_temperature_c"] = max(
                float(r["gpu"].split(",")[0]) for r in rows
            )
            summary["telemetry"]["phases"] = {
                phase: {
                    "min_available_ram_gib": min(
                        r["memory"]["MemAvailable"] for r in rows if r["phase"] == phase
                    )
                    / 1024**3,
                    "swap_used_first_last_gib": [
                        (r["memory"]["SwapTotal"] - r["memory"]["SwapFree"]) / 1024**3
                        for r in [
                            next(r for r in rows if r["phase"] == phase),
                            next(r for r in reversed(rows) if r["phase"] == phase),
                        ]
                    ],
                }
                for phase in sorted({r["phase"] for r in rows})
            }
            summary["telemetry"]["max_running_requests"] = max(
                sum(v.get("num_requests_running", 0) for v in r["engines"].values())
                for r in rows
            )
            summary["telemetry"]["is_4_4_4_observed"] = any(
                all(
                    r["engines"].get(key, {}).get("num_requests_running", 0) == count
                    for key, count in [("4b", 4), ("15-4b", 4), ("27b", 4)]
                )
                for r in rows
            )
            summary["telemetry"]["max_kv_cache_fraction"] = {
                key: max(
                    r["engines"]
                    .get(key, {})
                    .get(
                        "kv_cache_usage_perc",
                        r["engines"].get(key, {}).get("gpu_cache_usage_perc", 0),
                    )
                    for r in rows
                )
                for key in ["4b", "15-4b", "27b"]
            }
    path = directory / "resources.jsonl"
    if path.exists():
        resources = [
            json.loads(line) for line in path.read_text().splitlines() if line.strip()
        ]
        hardware = json.loads((directory / "hardware.json").read_text())
        page_size = hardware["page_size_bytes"]
        summary["resource_phases"] = {}
        for phase in sorted({r["phase"] for r in resources}):
            rows = [r for r in resources if r["phase"] == phase]
            summary["resource_phases"][phase] = {
                "samples": len(rows),
                "first_time": rows[0]["time"],
                "last_time": rows[-1]["time"],
                "min_available_ram_gib": min(r["memory"]["MemAvailable"] for r in rows)
                / 1024**3,
                "max_swap_used_gib": max(
                    r["memory"]["SwapTotal"] - r["memory"]["SwapFree"] for r in rows
                )
                / 1024**3,
                "swap_in_gib": (
                    rows[-1]["vmstat"]["pswpin"] - rows[0]["vmstat"]["pswpin"]
                )
                * page_size
                / 1024**3,
                "swap_out_gib": (
                    rows[-1]["vmstat"]["pswpout"] - rows[0]["vmstat"]["pswpout"]
                )
                * page_size
                / 1024**3,
            }
    path = directory / "service.json"
    if path.exists():
        service = json.loads(path.read_text())
        samples = [r for b in service["waves"] for r in b["samples"]]
        summary["service"] = {
            "requests": len(samples),
            "successful": sum(r["is_success"] for r in samples),
            "waves": service["waves"],
        }
    path = directory / "conditions.json"
    if path.exists():
        conditions = json.loads(path.read_text())
        summary["checks"]["is_restored"] = conditions["is_restored"]
        summary["checks"]["kernel_events"] = conditions.get("kernel_events")
        summary["checks"]["orchestrator_error"] = conditions.get("error")
        summary["engines"] = conditions["engines"]
        summary["memory_before_after"] = {
            phase: {
                "available_ram_gib": conditions[phase]["memory"]["MemAvailable"]
                / 1024**3,
                "swap_used_gib": (
                    conditions[phase]["memory"]["SwapTotal"]
                    - conditions[phase]["memory"]["SwapFree"]
                )
                / 1024**3,
            }
            for phase in ["before", "after"]
            if phase in conditions
        }
    path = directory / "restoration.json"
    if path.exists():
        verification = json.loads(path.read_text())
        summary["checks"]["runtime_verification"] = {
            key: verification[key]
            for key in [
                "is_runtime_restored",
                "is_configuration_unchanged",
                "is_boot_unchanged",
                "is_backend_unrestarted",
                "is_kernel_log_clean",
                "is_no_gpu_xid",
                "is_no_linux_oom_kill",
                "unauthenticated_status",
            ]
        }
    (directory / "summary.json").write_text(json.dumps(summary, indent=2))
    if csv_rows:
        with (directory / "summary.csv").open("w") as stream:
            fields = list(dict.fromkeys(k for row in csv_rows for k in row))
            writer = csv.DictWriter(stream, fieldnames=fields)
            writer.writeheader()
            writer.writerows(csv_rows)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
