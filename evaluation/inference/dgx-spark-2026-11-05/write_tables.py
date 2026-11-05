"""Render measured summaries into compact, independently linked study tables."""

from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import re
import statistics

ROOT = Path(__file__).resolve().parent


def number(value: object) -> str:
    return f"{value:.3f}" if isinstance(value, (float, int)) else "—"


def fraction(key: str, source: list[dict]) -> str:
    return f"{sum(bool(v.get(key)) for v in source)}/{len(source)}"


def table(
    study: str, columns: list[str], rows: list[list], *, filename: str = "TABLE.md"
) -> None:
    text = (
        "| " + " | ".join(columns) + " |\n|" + "|".join("---" for _ in columns) + "|\n"
    )
    text += "".join(
        "| " + " | ".join(str(cell) for cell in row) + " |\n" for row in rows
    )
    (ROOT / study / filename).write_text(text)


def load(study: str) -> list[dict]:
    path = ROOT / study / "summary.json"
    return json.loads(path.read_text()) if path.exists() else []


def main() -> None:
    study = "01-batching"
    table(
        study,
        [
            "Модель",
            "Профиль",
            "Клиентов",
            "TTFT, с",
            "Ответ, с",
            "Вся волна, с",
            "Суммарно токенов/с",
            "Полная серия",
        ],
        [
            [
                r["model"],
                r["profile"],
                r["concurrency"],
                number(r["ttft_seconds"]),
                number(r["latency_seconds"]),
                number(r["wave_seconds"]),
                number(r["wave_tokens_per_second"]),
                r["complete"],
            ]
            for r in load(study)
        ],
    )
    study = "02-prefill-budget"
    unavailable_rows = []
    if (ROOT / "runs/27b-prefill8192/failure.json").exists():
        unavailable_rows.append(
            [
                "27b",
                8192,
                "—",
                "—",
                "—",
                "—",
                "—",
                "Не запустился: требуется 8,76 GiB KV вместо 8",
            ]
        )
    table(
        study,
        [
            "Модель",
            "Бюджет токенов за шаг",
            "TTFT, с",
            "Ответ, с",
            "Медиана интервала фрагментов, с",
            "Максимальный интервал, с",
            "Суммарно токенов/с",
            "Полная серия",
        ],
        [
            [
                r["model"],
                2048
                if r["profile"] == "baseline"
                else r["profile"].removeprefix("prefill"),
                number(r["ttft_seconds"]),
                number(r["latency_seconds"]),
                number(r["median_delta_gap_seconds"]),
                number(r["maximum_delta_gap_seconds"]),
                number(r["wave_tokens_per_second"]),
                r["complete"],
            ]
            for r in load(study)
        ]
        + unavailable_rows,
    )
    study = "03-prefix-cache"
    groups = defaultdict(list)
    for r in load(study):
        if r["group"] in {"application-cold", "application-warm"}:
            continue  # Formatting defect in the marker; use the corrected repetition.
        if r["group"].startswith("system-"):
            if r["measured_requests"]:
                groups[(r["model"], "-".join(r["group"].split("-")[:2]))].append(r)
        elif r["group"].startswith("application-corrected-"):
            if r["measured_requests"]:
                groups[(r["model"], "-".join(r["group"].split("-")[:3]))].append(r)
        else:
            groups[(r["model"], r["group"])].append(r)
    table(
        study,
        [
            "Модель",
            "Сценарий",
            "TTFT, с",
            "Ответ на 16 токенов, с",
            "Измеренных запросов",
            "Полная серия",
        ],
        [
            [
                model,
                group,
                number(statistics.median(r["ttft_seconds"] for r in rows)),
                number(statistics.median(r["latency_seconds"] for r in rows)),
                sum(r["measured_requests"] for r in rows),
                all(r["complete"] for r in rows),
            ]
            for (model, group), rows in groups.items()
        ],
    )
    study = "04-kv-cache"
    table(
        study,
        [
            "Модель",
            "Профиль",
            "Слотов",
            "KV-кеш, GiB",
            "Выходных токенов на запрос",
            "TTFT, с",
            "Вся волна, с",
            "Пересчётов из-за нехватки кеша, с прогревом",
            "Полная серия",
        ],
        [
            [
                r["model"],
                r["profile"],
                4 if r["profile"] == "baseline" else 8,
                (12 if r["model"] == "27b" else 6)
                if r["profile"] in {"kv-plus", "pressure-plus"}
                else (8 if r["model"] == "27b" else 4),
                r["fixed_tokens"],
                number(r["ttft_seconds"]),
                number(r["wave_seconds"]),
                r["counter_deltas_including_warmup"].get(
                    "vllm:num_preemptions_total", "—"
                ),
                r["complete"],
            ]
            for r in load(study)
        ],
    )
    usage = []
    pattern = re.compile(
        r"Running: (\d+) reqs, Waiting: (\d+) reqs, GPU KV cache usage: ([\d.]+)%"
    )
    for row in load(study):
        if not row["profile"].startswith("pressure-"):
            continue
        path = ROOT / "runs" / f"{row['model']}-{row['profile']}" / "container.log"
        samples = [
            {"running": int(m[1]), "waiting": int(m[2]), "usage_percent": float(m[3])}
            for line in path.read_text().splitlines()
            if (m := pattern.search(line))
        ]
        usage.append(
            {
                "model": row["model"],
                "profile": row["profile"],
                "source": str(path.relative_to(ROOT)),
                "log_samples": len(samples),
                "maximum_observed_running": max(
                    (s["running"] for s in samples), default=None
                ),
                "maximum_observed_usage_percent": max(
                    (s["usage_percent"] for s in samples), default=None
                ),
                "preemptions_including_warmup": row[
                    "counter_deltas_including_warmup"
                ].get("vllm:num_preemptions_total"),
                "sampling_note": "Engine log samples approximately every 10 seconds, including warmup; peaks between samples can be missed.",
            }
        )
    (ROOT / study / "cache-utilization.json").write_text(
        json.dumps(usage, ensure_ascii=False, indent=2) + "\n"
    )
    table(
        study,
        [
            "Модель",
            "Профиль",
            "Отсчётов журнала",
            "Максимум активных запросов в отсчётах",
            "Максимум KV-кеша в отсчётах, %",
            "Пересчётов, с прогревом",
        ],
        [
            [
                r["model"],
                r["profile"],
                r["log_samples"],
                r["maximum_observed_running"],
                r["maximum_observed_usage_percent"],
                r["preemptions_including_warmup"],
            ]
            for r in usage
        ],
        filename="CACHE_USAGE.md",
    )
    study = "05-speculative-decoding"
    groups = defaultdict(list)
    for r in load(study):
        groups[(r["model"], r["profile"])].append(r)
    output = []
    first_token_rows = []
    for (model, profile), rows in groups.items():
        indexed = {r["group"]: r for r in rows}
        first_token_rows.append(
            [
                model,
                profile,
                number(indexed.get("report-greedy-0", {}).get("ttft_seconds")),
                number(indexed.get("dictation-greedy-0", {}).get("ttft_seconds")),
            ]
        )
        checks = [v for r in rows for v in r["validation"]]
        textual = [v for v in checks if v["main_valid"] is not None]
        vision = [v for v in checks if "vision_expected_match" in v]
        output.append(
            [
                model,
                profile,
                number(indexed.get("report-greedy-0", {}).get("latency_seconds")),
                number(indexed.get("dictation-greedy-0", {}).get("latency_seconds")),
                fraction("natural_stop", checks),
                fraction("schema_valid", checks),
                fraction("main_valid", textual),
                fraction("vision_expected_match", vision),
                sum(v.get("maximum_sentence_copies", 0) > 1 for v in checks),
                sum(r["requests_over_120_seconds"] for r in rows),
            ]
        )
    table(
        study,
        [
            "Модель",
            "Профиль",
            "Протокол greedy, с",
            "Диктовка greedy, с",
            "Естественное завершение",
            "JSON Schema",
            "Валидаторы main",
            "Цветовые изображения",
            "Ответов с повторами",
            "Запросов движка дольше 120 с",
        ],
        output,
    )
    table(
        study,
        [
            "Модель",
            "Профиль",
            "Протокол: первый фрагмент SSE, с",
            "Диктовка: первый фрагмент SSE, с",
        ],
        first_token_rows,
        filename="FIRST_TOKEN.md",
    )
    study = "06-shared-gpu-scheduling"
    if load(study):
        table(
            study,
            [
                "Политика",
                "4B: первый фрагмент от прихода задачи, с",
                "1.5 4B: первый фрагмент от прихода задачи, с",
                "27B: первый фрагмент от прихода задачи, с",
            ],
            [
                [
                    r["mode"],
                    *[
                        number(r["models"][key]["ttft_from_arrival"])
                        for key in ["4b", "15-4b", "27b"]
                    ],
                ]
                for r in load(study)
            ],
            filename="FIRST_TOKEN.md",
        )
        table(
            study,
            [
                "Политика",
                "Вся группа 12 запросов, с",
                "Суммарно токенов/с",
                "4B: ответ с очередью, с",
                "1.5 4B: ответ с очередью, с",
                "27B: ответ с очередью, с",
            ],
            [
                [
                    r["mode"],
                    number(r["wave_seconds"]),
                    number(r["aggregate_tps"]),
                    *[
                        number(r["models"][k]["latency_from_arrival"])
                        for k in ["4b", "15-4b", "27b"]
                    ],
                ]
                for r in load(study)
            ],
        )


if __name__ == "__main__":
    main()
