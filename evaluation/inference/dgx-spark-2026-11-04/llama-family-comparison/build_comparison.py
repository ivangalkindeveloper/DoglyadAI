"""Combine completed, comparable family trials without hiding failed answers."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> None:
    previous = json.loads((ROOT.parent / "engine-survey/summary.json").read_text())
    current = json.loads((ROOT / "summary.json").read_text())
    pairs = [
        (
            "MedGemma 4B",
            previous["vllm-4b-final"],
            previous["llama-4b-context16k"],
            "previous",
        ),
        ("MedGemma 1.5 4B", current["vllm-15-4b"], current["llama-15-4b"], "current"),
        ("MedGemma 27B", current["vllm-27b"], current["llama-27b"], "current"),
    ]
    table = [
        "| Модель | vLLM, один запрос, токенов/с | llama.cpp, один запрос, токенов/с | vLLM, четыре запроса, суммарно токенов/с | llama.cpp, четыре запроса, суммарно токенов/с |",
        "|---|---:|---:|---:|---:|",
    ]
    comparison = []
    durations = [
        "| Модель | vLLM, один клиент, с | llama.cpp, один клиент, с | vLLM, четыре клиента, с на ответ | llama.cpp, четыре клиента, с на ответ |",
        "|---|---:|---:|---:|---:|",
    ]
    quality = [
        "| Модель | Движок | JSON Schema | Текстовые main-валидаторы | Цветовые изображения |",
        "|---|---|---:|---:|---:|",
    ]
    for title, vllm, llama, origin in pairs:
        values = []
        details = {}
        for engine, row in (("vllm", vllm), ("llama.cpp", llama)):
            assert not row["trial_failed"], (
                title,
                engine,
            )
            assert all(
                row["performance"][c]["complete_five_waves"] for c in ("1", "4")
            ), (title, engine)
            details[engine] = row
            quality.append(
                f"| {title} | {engine} | {row['schema_valid']}/9 | {row['main_valid']}/7 | {row['vision_correct']}/2 |"
            )
        for count, metric in (
            ("1", "decode_tokens_per_second"),
            ("4", "aggregate_tokens_per_second"),
        ):
            values.extend(row["performance"][count][metric] for row in (vllm, llama))
        table.append(
            "| " + title + " | " + " | ".join(f"{v:.2f}" for v in values) + " |"
        )
        times = [
            row["performance"][count]["latency_seconds"]
            for count in ("1", "4")
            for row in (vllm, llama)
        ]
        durations.append(
            "| " + title + " | " + " | ".join(f"{v:.2f}" for v in times) + " |"
        )
        comparison.append(
            {
                "model": title,
                "origin": origin,
                "llama_single_speed_change_percent": (values[1] / values[0] - 1) * 100,
                "llama_four_clients_speed_change_percent": (values[3] / values[2] - 1)
                * 100,
                "results": details,
            }
        )
    (ROOT / "comparison.json").write_text(json.dumps(comparison, indent=2) + "\n")
    (ROOT / "TABLE.md").write_text("\n".join(table) + "\n")
    (ROOT / "DURATION.md").write_text("\n".join(durations) + "\n")
    (ROOT / "QUALITY.md").write_text("\n".join(quality) + "\n")
    print("\n".join(table))


if __name__ == "__main__":
    main()
