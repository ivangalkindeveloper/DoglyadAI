"""Validate retained answers and compare SLA, latency and measured capacity."""

import hashlib
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.with_name("dgx-spark-2026-11-05-ngram-rollout")))
from evaluate import (  # noqa: E402
    ConfigurationLoader,
    LanguageCode,
    MockNeuralModelService,
    REPOSITORY,
    ReportGenerationService,
    USExaminationRequest,
    USVoiceFormGeneration,
    VoiceFormValidator,
    copies,
    counters,
    validator_for,
)


def main():
    source_hashes = json.loads(
        (
            ROOT.with_name("dgx-spark-2026-11-05") / "validation-source-hashes.json"
        ).read_text()
    )
    assert all(
        hashlib.sha256((REPOSITORY / p).read_bytes()).hexdigest() == h
        for p, h in source_hashes.items()
    )
    config = ConfigurationLoader(REPOSITORY / "backend/main/config/development").load()
    reports = ReportGenerationService(config, MockNeuralModelService())
    voice = VoiceFormValidator(config.voice_source_localization(LanguageCode.RU))
    cases = {
        m: {c["id"]: c for c in json.loads((ROOT / f"cases-{m}.json").read_text())}
        for m in ["4b", "15-4b", "27b"]
    }
    summary, validation, host_rows, count_rows = [], [], [], []
    references = {}
    for profile in ["baseline", "seq8", "seq8-kv12", "seq4-kv12", "selected"]:
        directory = ROOT / profile / "measurements"
        if not (directory / "results.jsonl").exists():
            continue
        waves = [
            json.loads(line)
            for line in (directory / "results.jsonl").read_text().splitlines()
        ]
        for wave in waves:
            for name, after in wave["metrics_after"].items():
                before = counters(wave["metrics_before"][name]["metrics"])
                count_rows.append(
                    {
                        "profile": profile,
                        "wave": wave["wave"],
                        "container": name,
                        "deltas": {
                            k: v - before.get(k, 0)
                            for k, v in counters(after["metrics"]).items()
                        },
                    }
                )
            for model in cases:
                rows = [r for r in wave["requests"] if r["model"] == model]
                if not rows:
                    continue
                summary.append(
                    {
                        "profile": profile,
                        "wave": wave["wave"],
                        "kind": wave["kind"],
                        "model": model,
                        "requests": len(rows),
                        "median_seconds": statistics.median(r["seconds"] for r in rows),
                        "maximum_seconds": max(r["seconds"] for r in rows),
                        "median_ttft": statistics.median(
                            r["ttft"] for r in rows if r["ttft"] is not None
                        ),
                        "wave_seconds": wave["seconds"],
                        "over120": sum(r["seconds"] > 120 for r in rows),
                        "completion_tokens": sorted(
                            set(r["usage"].get("completion_tokens", 0) for r in rows)
                        ),
                        "prompt_tokens": sorted(
                            set(r["usage"].get("prompt_tokens", 0) for r in rows)
                        ),
                    }
                )
                for r in rows:
                    key = (wave["wave"], model, r["client"])
                    if profile == "baseline":
                        references[key] = r
                    ref = references.get(key)
                    v = {
                        "profile": profile,
                        "wave": wave["wave"],
                        "model": model,
                        "case": r["case"],
                        "client": r["client"],
                        "transport_complete": r["done"] and not r.get("error"),
                        "finish": r["finish"],
                        "seconds": r["seconds"],
                        "prompt_ids_match_baseline": bool(
                            ref
                            and r.get("prompt_token_ids")
                            and r["prompt_token_ids"] == ref.get("prompt_token_ids")
                        ),
                    }
                    if wave["kind"] != "pressure":
                        case = cases[model][r["case"]]
                        v.update(
                            schema_valid=False,
                            main_valid=None if case["kind"] == "vision" else False,
                        )
                        try:
                            value = json.loads(r["text"])
                            validator_for(case["schema"])(case["schema"]).validate(
                                value
                            )
                            v.update(
                                schema_valid=True, maximum_sentence_copies=copies(value)
                            )
                            if case["kind"] == "vision":
                                v["vision_match"] = value == case["expected"]
                            elif case["kind"] == "dictation":
                                voice.validate(
                                    USVoiceFormGeneration.model_validate(value),
                                    case["transcript"],
                                )
                                v["main_valid"] = True
                            else:
                                reports.complete(
                                    r["text"],
                                    USExaminationRequest.model_validate(case["body"]),
                                    model_id=case["model"],
                                    language_code=LanguageCode(
                                        case.get("language", "ru")
                                    ),
                                )
                                v["main_valid"] = True
                        except Exception as error:
                            v["validation_error"] = getattr(
                                error, "code", type(error).__name__
                            )
                    validation.append(v)
        samples = [
            json.loads(line)
            for line in (directory / "telemetry.jsonl").read_text().splitlines()
        ]
        host_rows.append(
            {
                "profile": profile,
                "samples": len(samples),
                "minimum_available_gib": min(
                    r["memory_kib"]["MemAvailable"] for r in samples
                )
                / 1024**2,
                "maximum_gpu_temperature_c": max(
                    int(r["gpu"].split(",")[0]) for r in samples
                ),
                "oom_kill_delta": samples[-1]["vmstat"]["oom_kill"]
                - samples[0]["vmstat"]["oom_kill"],
                "swap_read_pages": samples[-1]["vmstat"]["pswpin"]
                - samples[0]["vmstat"]["pswpin"],
                "swap_write_pages": samples[-1]["vmstat"]["pswpout"]
                - samples[0]["vmstat"]["pswpout"],
            }
        )
        startup_path = ROOT / profile / "startup.jsonl"
        if startup_path.exists():
            startup = [
                json.loads(line) for line in startup_path.read_text().splitlines()
            ]
            if startup:
                host_rows[-1]["startup"] = {
                    "minimum_available_gib": min(
                        r["memory_kib"]["MemAvailable"] for r in startup
                    )
                    / 1024**2,
                    "swap_read_pages": startup[-1]["vmstat"]["pswpin"]
                    - startup[0]["vmstat"]["pswpin"],
                    "swap_write_pages": startup[-1]["vmstat"]["pswpout"]
                    - startup[0]["vmstat"]["pswpout"],
                }
        host_rows[-1]["maximum_swap_used_gib"] = (
            max(
                r["memory_kib"]["SwapTotal"] - r["memory_kib"]["SwapFree"]
                for r in samples
            )
            / 1024**2
        )
    for name, value in [
        ("summary.json", summary),
        ("validation.json", validation),
        ("host-summary.json", host_rows),
        ("counters.json", count_rows),
    ]:
        (ROOT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    lines = [
        "| Вариант | Серия | Модель | Ответ, медиана / максимум, с | Первый токен, с | >120 с |",
        "|---|---|---|---:|---:|---:|",
    ]
    for r in summary:
        if r["wave"] != "warmup":
            lines.append(
                f"| {r['profile']} | {r['wave']} | {r['model']} | {r['median_seconds']:.2f} / {r['maximum_seconds']:.2f} | {r['median_ttft']:.2f} | {r['over120']}/{r['requests']} |"
            )
    (ROOT / "RESULTS.md").write_text("\n".join(lines) + "\n")
    smoke_path = ROOT / "service-smoke.json"
    if smoke_path.exists():
        smoke_validation = []
        for row in json.loads(smoke_path.read_text())["requests"]:
            case = cases[row["model"]]["report-greedy-0"]
            check = {
                "model": row["model"],
                "client": row["client"],
                "method": row["method"],
            }
            try:
                reports.complete(
                    row["text"],
                    USExaminationRequest.model_validate(case["body"]),
                    model_id=case["model"],
                    language_code=LanguageCode(case.get("language", "ru")),
                )
                check["main_valid"] = True
            except Exception as error:
                check.update(
                    main_valid=False, error=getattr(error, "code", type(error).__name__)
                )
            smoke_validation.append(check)
        (ROOT / "service-smoke-validation.json").write_text(
            json.dumps(smoke_validation, ensure_ascii=False, indent=2) + "\n"
        )
    print(
        json.dumps(
            {
                "groups": len(summary),
                "requests": len(validation),
                "host": host_rows,
                "validation_failures": [
                    {
                        k: r[k]
                        for k in [
                            "profile",
                            "wave",
                            "model",
                            "case",
                            "validation_error",
                        ]
                    }
                    for r in validation
                    if r.get("validation_error")
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
