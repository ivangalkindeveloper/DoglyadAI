"""Validate every full answer, including warmup, using application validators."""

import hashlib
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parent
OLD = ROOT.with_name("dgx-spark-2026-11-05")
sys.path.insert(0, str(OLD))
from analyze import (  # noqa: E402
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
    hashes = json.loads((OLD / "validation-source-hashes.json").read_text())
    assert all(
        hashlib.sha256((REPOSITORY / p).read_bytes()).hexdigest() == h
        for p, h in hashes.items()
    )
    config = ConfigurationLoader(REPOSITORY / "backend/main/config/development").load()
    reports = ReportGenerationService(config, MockNeuralModelService())
    voice = VoiceFormValidator(config.voice_source_localization(LanguageCode.RU))
    cases = {
        k: {c["id"]: c for c in json.loads((ROOT / f"cases-{k}.json").read_text())}
        for k in ["4b", "15-4b", "27b"]
    }
    validations, summary, references, metrics = [], [], {}, []
    for profile in ["baseline", "ngram8"]:
        path = ROOT / profile / "results.jsonl"
        if not path.exists():
            continue
        waves = [json.loads(line) for line in path.read_text().splitlines()]
        for wave in waves:
            for name, after in wave["metrics_after"].items():
                before = counters(wave["metrics_before"][name]["metrics"])
                delta = {
                    key: value - before.get(key, 0)
                    for key, value in counters(after["metrics"]).items()
                }
                metrics.append(
                    {
                        "profile": profile,
                        "wave": wave["wave"],
                        "container": name,
                        "deltas": delta,
                    }
                )
            for row in wave["requests"]:
                case = cases[row["model"]][row["case"]]
                key = (wave["wave"], row["model"], row["client"])
                if profile == "baseline":
                    references[key] = row
                reference = references.get(key)
                v = {
                    "profile": profile,
                    "wave": wave["wave"],
                    "model": row["model"],
                    "case": row["case"],
                    "client": row["client"],
                    "seconds": row["seconds"],
                    "over_120_seconds": row["seconds"] > 120,
                    "natural_stop": row["done"]
                    and row["finish"] == "stop"
                    and not row.get("error"),
                    "schema_valid": False,
                    "main_valid": None if case["kind"] == "vision" else False,
                    "same_prompt_ids": row.get("prompt_token_ids") is not None
                    and reference is not None
                    and row.get("prompt_token_ids")
                    == reference.get("prompt_token_ids"),
                    "same_output": reference is not None
                    and row["text"] == reference["text"],
                }
                try:
                    value = json.loads(row["text"])
                    cls = validator_for(case["schema"])
                    cls.check_schema(case["schema"])
                    cls(case["schema"]).validate(value)
                    v["schema_valid"] = True
                    v["maximum_sentence_copies"] = copies(value)
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
                            row["text"],
                            USExaminationRequest.model_validate(case["body"]),
                            model_id=case["model"],
                            language_code=LanguageCode(case.get("language", "ru")),
                        )
                        v["main_valid"] = True
                except Exception as error:
                    v["validation_error"] = getattr(error, "code", type(error).__name__)
                validations.append(v)
        for model in cases:
            rows = [
                r
                for w in waves
                if w["wave"].startswith("report-")
                for r in w["requests"]
                if r["model"] == model
            ]
            if not rows:
                continue
            summary.append(
                {
                    "profile": profile,
                    "model": model,
                    "requests": len(rows),
                    "median_seconds": statistics.median(r["seconds"] for r in rows),
                    "median_ttft": statistics.median(r["ttft"] for r in rows),
                    "median_output_tps": statistics.median(
                        r["output_tps"] for r in rows
                    ),
                    "median_decode_tps": statistics.median(
                        r["decode_tps"] for r in rows if r["decode_tps"] is not None
                    ),
                    "maximum_seconds": max(r["seconds"] for r in rows),
                    "completion_tokens": sorted(
                        set(r["usage"].get("completion_tokens") for r in rows)
                    ),
                    "over_120_seconds": sum(r["seconds"] > 120 for r in rows),
                }
            )
    (ROOT / "validation.json").write_text(
        json.dumps(validations, ensure_ascii=False, indent=2) + "\n"
    )
    (ROOT / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    (ROOT / "counters.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(
        json.dumps(
            {
                "summary": summary,
                "failures": [
                    v
                    for v in validations
                    if v.get("validation_error") or not v["natural_stop"]
                ],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
