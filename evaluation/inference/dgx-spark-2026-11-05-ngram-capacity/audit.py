"""Audit completed phases and retain counts independent of the prose report."""

import collections
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    validation = json.loads((ROOT / "validation.json").read_text())
    counters = json.loads((ROOT / "counters.json").read_text())
    result = {}
    for profile in dict.fromkeys(r["profile"] for r in validation):
        directory = ROOT / profile
        status = json.loads((directory / "status.json").read_text())
        rows = [r for r in validation if r["profile"] == profile]
        ordinary = [r for r in rows if "schema_valid" in r]
        pressure = [r for r in rows if "schema_valid" not in r]
        metrics = [r for r in counters if r["profile"] == profile]
        kernel = json.loads((directory / "kernel.json").read_text())
        before = json.loads((directory / "before.json").read_text())
        after = json.loads((directory / "after.json").read_text())
        samples = [
            json.loads(line)
            for line in (directory / "measurements/telemetry.jsonl")
            .read_text()
            .splitlines()
        ]
        peaks = collections.defaultdict(float)
        for sample in samples:
            for model, lines in sample["engines"].items():
                if isinstance(lines, list):
                    for line in lines:
                        metric = line.split("{", 1)[0]
                        key = f"{sample['wave']}:{model}:{metric}"
                        peaks[key] = max(peaks[key], float(line.split()[-1]))
        checks = {
            "complete": status["status"] == "complete",
            "expected_requests": len(rows) == 123,
            "all_transport_complete": all(r["transport_complete"] for r in rows),
            "all_prompt_ids_match": all(r["prompt_ids_match_baseline"] for r in rows),
            "all_ordinary_json_valid": all(r["schema_valid"] for r in ordinary),
            "all_ordinary_natural_stop": all(r["finish"] == "stop" for r in ordinary),
            "no_image_changes": all(
                before[n]["image"] == after[n]["image"] for n in before
            ),
            "backend_unchanged": before["doglyad-dgx-backend_inference-1"]
            == after["doglyad-dgx-backend_inference-1"],
            "no_kernel_errors": kernel["returncode"] == 1
            and kernel["stdout"].strip() == "-- No entries --"
            and not kernel["stderr"],
        }
        result[profile] = {
            "checks": checks,
            "ordinary": len(ordinary),
            "pressure": len(pressure),
            "main_rejected": sum(r.get("main_valid") is False for r in ordinary),
            "main_evaluated": sum(r.get("main_valid") is not None for r in ordinary),
            "vision_passed": sum(r.get("vision_match") is True for r in ordinary),
            "vision_evaluated": sum("vision_match" in r for r in ordinary),
            "maximum_sentence_copies": max(
                r.get("maximum_sentence_copies", 0) for r in ordinary
            ),
            "ordinary_over120": sum(r["seconds"] > 120 for r in ordinary),
            "pressure_over120": sum(r["seconds"] > 120 for r in pressure),
            "success_counter_delta": sum(
                r["deltas"].get("vllm:request_success_total", 0) for r in metrics
            ),
            "preemptions": sum(
                r["deltas"].get("vllm:num_preemptions_total", 0) for r in metrics
            ),
            "observed_peaks": dict(peaks),
        }
    (ROOT / "audit.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )
    print(
        json.dumps(
            {
                p: {k: v for k, v in r.items() if k != "observed_peaks"}
                for p, r in result.items()
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
