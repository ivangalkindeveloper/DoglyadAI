"""Verify completed evidence before publication, retaining content-validator failures."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def load(name: str):
    return json.loads((ROOT / name).read_text())


def success_count(metrics: str) -> float:
    return sum(
        float(line.split()[-1])
        for line in metrics.splitlines()
        if line.startswith("vllm:request_success_total{")
    )


def main() -> None:
    completeness = load("completeness.json")
    unavailable = load("unavailable-profiles.json")
    unavailable_groups = [g for p in unavailable for g in p["groups"]]
    assert completeness["expected_groups"] == completeness["observed_groups"] + len(
        unavailable_groups
    )
    assert sorted(completeness["missing_groups"]) == sorted(unavailable_groups)
    assert not completeness["incomplete_groups"]
    assert sorted(completeness["startup_or_probe_failures"]) == sorted(
        p["failure"] for p in unavailable
    )
    for profile in unavailable:
        assert load(profile["failure"])["phase"] == profile["phase"]
        assert profile["required_log_fragment"] in (ROOT / profile["log"]).read_text()
    accounting = load("request-accounting.json")
    assert len(accounting) == 33 - len(
        unavailable
    )  # 24 primary profiles, 6 KV profiles, 3 prefix profiles.
    assert all(
        r["ends_after_last_group"]
        and r["counter_matches_observed"]
        and not r["client_errors"]
        for r in accounting
    )
    mixed = [
        json.loads(line)
        for line in (ROOT / "06-shared-gpu-scheduling/results.jsonl")
        .read_text()
        .splitlines()
    ]
    assert len(mixed) == 16 and all(r["valid"] for r in mixed)
    for wave in mixed:
        assert len(wave["requests"]) == 12
        for name, before in wave["metrics_before"].items():
            after = wave["metrics_after"][name]
            assert (
                success_count(after["metrics"]) - success_count(before["metrics"]) == 4
            )
    final = load("verification.json")
    assert all(all(v.values()) for v in final["containers"].values())
    assert final["backend_never_restarted"] and final["same_boot"]
    assert final["no_temporary_container"]
    assert all(v == 401 for v in final["unauthenticated_api_status"].values())
    assert len(final["backend_engine_routes"]) == 3
    assert all(
        r["health_status"] == 200 and r["configured_model_present"]
        for r in final["backend_engine_routes"].values()
    )
    latest = load("readiness-latest.json")
    assert all(all(v.values()) for v in latest["containers"].values())
    assert latest["backend_never_restarted"] and latest["same_boot"]
    assert latest["no_temporary_container"]
    assert not latest["remaining_experiment_processes"]
    assert all(
        r["equal_token_ids"]
        for r in load("03-prefix-cache/corrected-content-format-parity.json").values()
    )
    assert all(
        v
        for r in load("report-input-parity.json")
        for k, v in r.items()
        if k.startswith("same_")
    )
    assert all(
        r["equal_payload_except_model"] for r in load("cross-model-input-parity.json")
    )
    summaries = [
        r
        for directory in sorted(ROOT.glob("0[1-5]-*"))
        for r in json.loads((directory / "summary.json").read_text())
    ]
    answers = [v for row in summaries for v in row.get("validation", [])]
    assert len(answers) == 117
    assert all(v["prompt_ids_match_baseline"] for v in answers)
    measured = sum(r["measured_requests"] for r in summaries) + sum(
        len(r["requests"]) for r in mixed if r["wave"] >= 0
    )
    excluded = sum(
        r["measured_requests"]
        for r in summaries
        if r["group"] in {"application-cold", "application-warm"}
    )
    content_failures = [
        {"model": r["model"], "profile": r["profile"], "case": r["group"], **v}
        for r in summaries
        for v in r.get("validation", [])
        if v.get("validation_error")
    ]
    parsed = 0
    for path in ROOT.rglob("*.json"):
        if path.name == "audit.json":
            continue  # Keep the count stable when this audit is repeated.
        json.loads(path.read_text())
        parsed += 1
    result = {
        "transport_and_restoration_checks_passed": True,
        "complete_parameter_groups": completeness["observed_groups"],
        "assessed_unavailable_groups": unavailable_groups,
        "mixed_waves_including_warmup": len(mixed),
        "requests_including_warmup": sum(
            r["observed_requests_including_warmup"] for r in accounting
        )
        + sum(len(r["requests"]) for r in mixed),
        "measured_requests": measured,
        "excluded_marker_format_requests": excluded,
        "interpreted_measured_requests": measured - excluded,
        "full_answers_checked": len(answers),
        "full_answer_prompt_ids_match_baseline": True,
        "natural_stops": sum(v["natural_stop"] for v in answers),
        "schema_valid": sum(v["schema_valid"] for v in answers),
        "answers_with_repeated_long_sentences": sum(
            v.get("maximum_sentence_copies", 0) > 1 for v in answers
        ),
        "content_validator_failures": content_failures,
        "json_files_parsed_excluding_this_audit": parsed,
        "restored_host_ready_at_publication": True,
    }
    (ROOT / "audit.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )
    print(
        json.dumps(
            {k: v for k, v in result.items() if k != "content_validator_failures"}
        )
    )


if __name__ == "__main__":
    main()
