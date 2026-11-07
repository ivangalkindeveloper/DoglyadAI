"""Check final evidence, smoke answer and memory-recheck responses."""

import hashlib
import json
from pathlib import Path
import sys

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
    reports = ReportGenerationService(
        ConfigurationLoader(REPOSITORY / "backend/main/config/development").load(),
        MockNeuralModelService(),
    )
    cases = {
        m: {c["id"]: c for c in json.loads((ROOT / f"cases-{m}.json").read_text())}
        for m in ["4b", "15-4b", "27b"]
    }
    checks = []
    waves = [
        json.loads(line)
        for line in (ROOT / "memory-recheck/ngram8/results.jsonl")
        .read_text()
        .splitlines()
    ]
    for wave in waves:
        for r in wave["requests"]:
            case = cases[r["model"]][r["case"]]
            value = json.loads(r["text"])
            validator_for(case["schema"])(case["schema"]).validate(value)
            assert r["done"] and r["finish"] == "stop" and not r.get("error")
            assert copies(value) <= 1
            checks.append(
                {
                    "model": r["model"],
                    "case": r["case"],
                    "natural_stop": True,
                    "schema_valid": True,
                    "maximum_sentence_copies": copies(value),
                    "seconds": r["seconds"],
                }
            )
    assert len(checks) == 24
    smoke = json.loads((ROOT / "post-restore-smoke.json").read_text())["result"]
    case = cases["15-4b"]["report-greedy-0"]
    validator_for(case["schema"])(case["schema"]).validate(json.loads(smoke["text"]))
    reports.complete(
        smoke["text"],
        USExaminationRequest.model_validate(case["body"]),
        model_id=case["model"],
        language_code=LanguageCode.RU,
    )
    verification = json.loads((ROOT / "verification.json").read_text())
    assert all(
        verification[k]
        for k in [
            "backend_never_restarted",
            "same_boot",
            "only_expected_running_containers",
            "commands_match_canonical_profile",
        ]
    )
    assert all(v == 401 for v in verification["unauthenticated_api_status"].values())
    sys.path.insert(0, str(REPOSITORY / "deploy/inference"))
    from host_profile import HostProfile

    profile = HostProfile.load(REPOSITORY / "deploy/inference/profiles/dgx-spark.json")
    assert profile.fingerprint == verification["profile_fingerprint"]
    source_hashes = json.loads((ROOT / "source-input-hashes.json").read_text())
    for model in cases:
        name = f"cases-{model}.json"
        expected = next(
            h for path, h in source_hashes.items() if Path(path).name == name
        )
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == expected
    result = {
        "status": "complete",
        "ngram_enabled_for_all_three_models": True,
        "smoke_main_validator_passed": True,
        "canonical_profile_matches_runtime": True,
        "memory_recheck": checks,
        "known_driver_warning": "NV_ERR_NO_MEMORY at 2026-11-05 22:15:01 MSK; cause unknown",
        "clinical_equivalence_established": False,
        "quantization_changed": False,
    }
    (ROOT / "final-audit.json").write_text(json.dumps(result, indent=2) + "\n")
    print(
        "Final audit passed: canonical N-gram profile active, smoke valid, 24 recheck answers complete."
    )


if __name__ == "__main__":
    main()
