"""Compare latency, output lengths and acceptance counters without conflating them."""

from __future__ import annotations

import json
from pathlib import Path
import statistics

ROOT = Path(__file__).resolve().parent / "05-speculative-decoding"


def main() -> None:
    rows = json.loads((ROOT / "summary.json").read_text())
    failures = [
        {"model": r["model"], "profile": r["profile"], "case": r["group"], **v}
        for r in rows
        for v in r["validation"]
        if v.get("validation_error")
    ]
    (ROOT / "validation-failures.json").write_text(
        json.dumps(failures, ensure_ascii=False, indent=2) + "\n"
    )
    baseline = {(r["model"], r["group"]): r for r in rows if r["profile"] == "baseline"}
    results = []
    for row in rows:
        if row["profile"] == "baseline" or not row["measured_requests"]:
            continue
        reference = baseline.get((row["model"], row["group"]))
        if not reference:
            continue
        metrics = row["counter_deltas_including_warmup"]
        drafts = metrics.get("vllm:spec_decode_num_drafts_total", 0)
        proposed = metrics.get("vllm:spec_decode_num_draft_tokens_total", 0)
        accepted = metrics.get("vllm:spec_decode_num_accepted_tokens_total", 0)
        results.append(
            {
                "model": row["model"],
                "profile": row["profile"],
                "case": row["group"],
                "measured_requests": row["measured_requests"],
                "baseline_seconds": reference["latency_seconds"],
                "speculative_seconds": row["latency_seconds"],
                "latency_speedup_ratio": reference["latency_seconds"]
                / row["latency_seconds"],
                "baseline_median_output_tokens": statistics.median(
                    reference["completion_tokens"]
                ),
                "speculative_median_output_tokens": statistics.median(
                    row["completion_tokens"]
                ),
                "identical_prompt_ids": sum(
                    v["prompt_ids_match_baseline"] for v in row["validation"]
                ),
                "identical_text_to_first_baseline": sum(
                    v["text_matches_baseline"] for v in row["validation"]
                ),
                "counters_include_warmup": True,
                "draft_steps": drafts,
                "proposed_tokens": proposed,
                "accepted_tokens": accepted,
                "draft_token_acceptance_fraction": accepted / proposed
                if proposed
                else None,
                "accepted_tokens_per_draft_step": accepted / drafts if drafts else None,
            }
        )
    (ROOT / "comparison.json").write_text(json.dumps(results, indent=2) + "\n")
    columns = [
        "Модель",
        "Профиль",
        "Сценарий",
        "Исходно, с",
        "N-gram, с",
        "Ускорение полного ответа",
        "Токенов исходно / N-gram",
        "Совпавших текстов",
        "Принятых draft-токенов",
    ]
    lines = [
        "| " + " | ".join(columns) + " |",
        "|" + "|".join("---" for _ in columns) + "|",
    ]
    for r in results:
        acceptance = r["draft_token_acceptance_fraction"]
        values = [
            r["model"],
            r["profile"],
            r["case"],
            f"{r['baseline_seconds']:.3f}",
            f"{r['speculative_seconds']:.3f}",
            f"{r['latency_speedup_ratio']:.2f}×",
            f"{r['baseline_median_output_tokens']} / {r['speculative_median_output_tokens']}",
            f"{r['identical_text_to_first_baseline']}/{r['measured_requests']}",
            f"{acceptance:.1%}" if acceptance is not None else "—",
        ]
        lines.append("| " + " | ".join(str(v) for v in values) + " |")
    (ROOT / "COMPARISON.md").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
