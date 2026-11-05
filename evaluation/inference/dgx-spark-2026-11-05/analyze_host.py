"""Separate model-startup memory activity from measured inference windows."""

from __future__ import annotations

from datetime import datetime
import json
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parent


def load(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def summarize(rows: list[dict], page_bytes: int) -> dict:
    errors = sum("gpu" not in row for row in rows)
    rows = [row for row in rows if "gpu" in row]
    if not rows:
        return {"samples": 0, "error_samples": errors}
    gpu = [row["gpu"].split(", ") for row in rows]
    return {
        "samples": len(rows),
        "error_samples": errors,
        "maximum_sample_gap_seconds": max(
            (b["unix"] - a["unix"] for a, b in zip(rows, rows[1:])), default=0
        ),
        "first_unix": rows[0]["unix"],
        "last_unix": rows[-1]["unix"],
        "temperature_c_max": max(float(x[0]) for x in gpu),
        "temperature_c_median": statistics.median(float(x[0]) for x in gpu),
        "power_w_max": max(float(x[1].split()[0]) for x in gpu),
        "sm_clock_mhz_min": min(float(x[2].split()[0]) for x in gpu),
        "sm_clock_mhz_max": max(float(x[2].split()[0]) for x in gpu),
        "thermal_slowdown_samples": sum(
            any(x[i] == "Active" for i in [5, 6]) for x in gpu
        ),
        "power_cap_samples": sum(x[7] == "Active" for x in gpu),
        "unknown_limit_flag_samples": sum(
            any(x[i] not in {"Active", "Not Active"} for i in [5, 6, 7]) for x in gpu
        ),
        "minimum_available_gib": min(row["memory_kib"]["MemAvailable"] for row in rows)
        / 1024**2,
        "swap_read_mib": (rows[-1]["vmstat"]["pswpin"] - rows[0]["vmstat"]["pswpin"])
        * page_bytes
        / 1024**2,
        "swap_written_mib": (
            rows[-1]["vmstat"]["pswpout"] - rows[0]["vmstat"]["pswpout"]
        )
        * page_bytes
        / 1024**2,
        "oom_kills": rows[-1]["vmstat"]["oom_kill"] - rows[0]["vmstat"]["oom_kill"],
    }


def main() -> None:
    directory = ROOT / "07-host-health"
    page_bytes = int((directory / "page-size.txt").read_text())
    samples = load(directory / "telemetry.jsonl")
    pressure_path = directory / "telemetry-cache-pressure.jsonl"
    pressure = load(pressure_path) if pressure_path.exists() else []
    samples += pressure
    mixed_path = directory / "telemetry-mixed.jsonl"
    mixed = load(mixed_path) if mixed_path.exists() else []
    samples += mixed
    samples.sort(key=lambda row: row["unix"])
    controller = []
    for name in ["controller.log", "mixed-controller.log"]:
        for line in (ROOT / name).read_text().splitlines():
            if line.startswith("{"):
                controller.append(json.loads(line))
    by_trial = {}
    for trial in sorted({row.get("trial") for row in samples if row.get("trial")}):
        all_rows = [r for r in samples if r.get("trial") == trial]
        waves = [
            r
            for r in controller
            if r.get("event") == "wave"
            and f"{r['model']}-{r['profile']}" == trial
            and r["wave"] >= 0
        ]
        measured = []
        wave_stats = []
        for wave in waves:
            selected = [
                r
                for r in all_rows
                if wave["unix"] - wave["seconds"] <= r["unix"] <= wave["unix"]
            ]
            measured += selected
            wave_stats.append(
                {
                    "group": wave["group"],
                    "wave": wave["wave"],
                    **summarize(selected, page_bytes),
                }
            )
        # Disjoint windows: do not count the gaps between waves as inference I/O.
        inference = summarize(measured, page_bytes)
        inference["swap_read_mib"] = sum(w.get("swap_read_mib", 0) for w in wave_stats)
        inference["swap_written_mib"] = sum(
            w.get("swap_written_mib", 0) for w in wave_stats
        )
        inference["sampling_limit"] = (
            "5-second samples; short waves can have fewer than two samples, so zero observed I/O is not proof of no swapping"
        )
        by_trial[trial] = {
            "including_startup": summarize(all_rows, page_bytes),
            "inside_measured_waves": inference,
            "waves": wave_stats,
        }
    result = {
        "page_bytes": page_bytes,
        "whole_run": summarize(samples, page_bytes),
        "trials": by_trial,
    }
    if pressure:
        result["cache_pressure"] = summarize(pressure, page_bytes)
    if mixed:
        result["mixed"] = summarize(mixed, page_bytes)
    kernel_path = directory / "kernel-error-query.json"
    if kernel_path.exists():
        kernel = json.loads(kernel_path.read_text())
        entries = []
        for line in kernel["stdout"].splitlines():
            timestamp = datetime.fromisoformat(line.split()[0]).timestamp()
            phase = (
                "before_measurements"
                if timestamp < samples[0]["unix"]
                else "during_measurements"
                if timestamp <= samples[-1]["unix"]
                else "after_measurements"
            )
            entries.append({"unix": timestamp, "phase": phase, "line": line})
        result["kernel_query"] = {
            "returncode": kernel["returncode"],
            "stderr": kernel["stderr"],
            "matching_lines_before_measurements": sum(
                e["phase"] == "before_measurements" for e in entries
            ),
            "matching_lines_during_measurements": sum(
                e["phase"] == "during_measurements" for e in entries
            ),
            "matching_lines_after_measurements": sum(
                e["phase"] == "after_measurements" for e in entries
            ),
        }
        (directory / "kernel-timeline.json").write_text(
            json.dumps(entries, ensure_ascii=False, indent=2) + "\n"
        )
    (directory / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result["whole_run"]))


if __name__ == "__main__":
    main()
