"""Create the complete, reviewable experiment plan from existing synthetic inputs."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OLD = ROOT.parent / "dgx-spark-2026-11-04"
STUDIES = [
    "01-batching",
    "02-prefill-budget",
    "03-prefix-cache",
    "04-kv-cache",
    "05-speculative-decoding",
    "06-shared-gpu-scheduling",
    "07-host-health",
]


def main() -> None:
    if (ROOT / "plan.json").exists():
        raise FileExistsError("Use a new study directory; existing inputs are evidence")
    for study in STUDIES:
        (ROOT / study).mkdir(exist_ok=True)
    plans = []
    origins = []
    for key, source, index in [
        ("4b", OLD / "engine-survey/cases.json", 0),
        ("15-4b", OLD / "llama-family-comparison/cases-15-4b.json", 1),
        ("27b", OLD / "llama-family-comparison/cases-27b.json", 2),
    ]:
        cases = json.loads(source.read_text())
        cases = [
            case
            for case in cases
            if case["id"]
            in {
                "report-greedy-0",
                "report-sample-42",
                "conflict-greedy-0",
                "conflict-sample-42",
                "bladder-correction-sample-42",
                "bladder-en-sample-42",
                "dictation-greedy-0",
                "vision-1",
                "vision-2",
            }
        ]
        assert len(cases) == 9, (key, len(cases))
        (ROOT / f"cases-{key}.json").write_text(
            json.dumps(cases, ensure_ascii=False, indent=2) + "\n"
        )
        origins.append(
            {
                "path": str(source.relative_to(ROOT.parent)),
                "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            }
        )
        model = cases[0]["payload"]["model"]
        fixed = {
            "model": model,
            "messages": [
                {
                    "role": "user",
                    "content": "Перечисли числа от 1 до 1000 словами по-русски.",
                }
            ],
            "temperature": 0.0,
            "top_p": 1.0,
            "top_k": 0,
            "repetition_penalty": 1.0,
            "seed": 42,
            "max_tokens": 128,
            "ignore_eos": True,
        }

        def group(
            study: str, name: str, count: int = 1, target: int = 1500, **kwargs
        ) -> dict:
            return {
                "study": study,
                "id": name,
                "concurrency": count,
                "target_tokens": target,
                "payload": copy.deepcopy(fixed),
                "fixed_tokens": 128,
                **kwargs,
            }

        for profile in [
            "baseline",
            "seq8",
            "prefill1024",
            "prefill4096",
            "prefill8192",
            "kv-plus",
            "ngram4",
            "ngram8",
        ]:
            groups = []
            if profile in {"baseline", "seq8"}:
                groups += [group(STUDIES[0], f"medium-c{c}", c) for c in [1, 4, 8]]
            if profile == "baseline" or profile.startswith("prefill"):
                groups += [group(STUDIES[1], "long-c4", 4, 8000)]
            if profile in {"baseline", "seq8", "kv-plus"}:
                stress = group(STUDIES[3], "near-context-c8", 8, 15000, fixed_tokens=64)
                stress["payload"]["max_tokens"] = 64
                groups.append(stress)
            if profile == "baseline":
                for source_name, target, payload in [
                    ("application", 0, cases[0]["payload"]),
                    ("long", 8000, fixed),
                ]:
                    for cache in ["cold", "warm"]:
                        item = group(
                            STUDIES[2],
                            f"{source_name}-{cache}",
                            1,
                            target,
                            vary_suffix=True,
                            fixed_tokens=16,
                        )
                        item["payload"] = copy.deepcopy(payload)
                        item["payload"].update(max_tokens=16, ignore_eos=True)
                        if cache == "warm":
                            item["shared_salt"] = f"tuning-prefix-{key}-{source_name}"
                        groups.append(item)
            if profile == "baseline" or profile.startswith("ngram"):
                for case in cases:
                    groups.append(
                        {
                            "study": STUDIES[4],
                            "id": case["id"],
                            "payload": copy.deepcopy(case["payload"]),
                            "concurrency": 1,
                            "warmup": case["id"] == "report-greedy-0",
                            "repetitions": 3
                            if case["id"] in {"report-greedy-0", "dictation-greedy-0"}
                            else 1,
                        }
                    )
            flags = {}
            if profile in {"seq8", "kv-plus"}:
                flags["--max-num-seqs"] = "8"
            if profile.startswith("prefill"):
                flags["--max-num-batched-tokens"] = profile.removeprefix("prefill")
            if profile == "kv-plus":
                flags["--kv-cache-memory-bytes"] = str(
                    (12 if key == "27b" else 6) * 1024**3
                )
            if profile.startswith("ngram"):
                flags["--speculative-config"] = json.dumps(
                    {
                        "method": "ngram",
                        "num_speculative_tokens": int(profile[-1]),
                        "prompt_lookup_min": 2,
                        "prompt_lookup_max": 5,
                    }
                )
            plans.append(
                {
                    "model_key": key,
                    "model_index": index,
                    "model": model,
                    "profile": profile,
                    "flags": flags,
                    "groups": groups,
                }
            )
    (ROOT / "plan.json").write_text(
        json.dumps(plans, ensure_ascii=False, indent=2) + "\n"
    )
    (ROOT / "input-provenance.json").write_text(json.dumps(origins, indent=2) + "\n")
    print(
        f"Prepared {len(plans)} profiles, {sum(len(p['groups']) for p in plans)} groups"
    )


if __name__ == "__main__":
    main()
