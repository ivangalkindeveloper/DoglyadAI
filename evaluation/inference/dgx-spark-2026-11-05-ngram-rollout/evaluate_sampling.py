"""Compare validation outcomes for a fixed list of paired sampling seeds."""

import json
from pathlib import Path

from evaluate import (
    ConfigurationLoader,
    LanguageCode,
    MockNeuralModelService,
    REPOSITORY,
    ReportGenerationService,
    USExaminationRequest,
    copies,
    validator_for,
)

ROOT = Path(__file__).resolve().parent


def main():
    case = next(
        c
        for c in json.loads((ROOT / "cases-15-4b.json").read_text())
        if c["id"] == "conflict-sample-42"
    )
    reports = ReportGenerationService(
        ConfigurationLoader(REPOSITORY / "backend/main/config/development").load(),
        MockNeuralModelService(),
    )
    result = {}
    for profile in ["baseline", "ngram8"]:
        path = ROOT / "sampling-check" / profile / "results.jsonl"
        if not path.exists():
            continue
        rows = []
        for line in path.read_text().splitlines():
            for r in json.loads(line)["requests"]:
                v = {
                    "seed": r["seed"],
                    "schema_valid": False,
                    "main_valid": False,
                    "natural_stop": r["done"]
                    and r["finish"] == "stop"
                    and not r.get("error"),
                    "seconds": r["seconds"],
                    "output_sha256": r["output_sha256"],
                }
                try:
                    value = json.loads(r["text"])
                    validator_for(case["schema"])(case["schema"]).validate(value)
                    v["schema_valid"] = True
                    v["maximum_sentence_copies"] = copies(value)
                    reports.complete(
                        r["text"],
                        USExaminationRequest.model_validate(case["body"]),
                        model_id=case["model"],
                        language_code=LanguageCode.RU,
                    )
                    v["main_valid"] = True
                except Exception as error:
                    v["validation_error"] = getattr(error, "code", type(error).__name__)
                rows.append(v)
        result[profile] = {
            "requests": len(rows),
            "main_failures": sum(not r["main_valid"] for r in rows),
            "all_natural_stop": all(r["natural_stop"] for r in rows),
            "all_schema_valid": all(r["schema_valid"] for r in rows),
            "results": rows,
        }
    if len(result) == 2 and all(len(result[p]["results"]) == 16 for p in result):
        a = {r["seed"]: r["main_valid"] for r in result["baseline"]["results"]}
        b = {r["seed"]: r["main_valid"] for r in result["ngram8"]["results"]}
        result["paired_seed_outcomes"] = {
            "both_pass": [s for s in a if a[s] and b[s]],
            "both_fail": [s for s in a if not a[s] and not b[s]],
            "baseline_only_pass": [s for s in a if a[s] and not b[s]],
            "ngram_only_pass": [s for s in a if not a[s] and b[s]],
        }
    (ROOT / "sampling-check/validation.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )
    print(
        json.dumps(
            {
                k: {f: v for f, v in r.items() if f != "results"}
                for k, r in result.items()
            },
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
