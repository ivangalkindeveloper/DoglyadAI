"""Measure reuse of system instructions while the user-message prefix changes."""

from __future__ import annotations

import copy
import fcntl
import json
from pathlib import Path

from run import NAMES, ROOT, healthy, idle, run_probe, save


def main() -> None:
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    plans = []
    for index, key in enumerate(["4b", "15-4b", "27b"]):
        healthy(NAMES[index])
        for name in NAMES[:3]:
            idle(name)
        cases = json.loads((ROOT / f"cases-{key}.json").read_text())
        original = next(c["payload"] for c in cases if c["id"] == "report-greedy-0")
        groups = []
        for family in ["system", "application-corrected"]:
            for mode in ["cold", "warm"]:
                for number in range(-1, 3):
                    payload = copy.deepcopy(original)
                    payload.update(max_tokens=16, ignore_eos=True)
                    prefix = (
                        f"Пациент тестового набора: {number + 100}.\n"
                        if family == "system"
                        else ""
                    )
                    suffix = (
                        f"\nНомер синтетического запроса: {number + 10}-0."
                        if family != "system"
                        else ""
                    )
                    content = payload["messages"][-1]["content"]
                    if isinstance(content, str):
                        payload["messages"][-1]["content"] = prefix + content + suffix
                    else:
                        assert content and all(
                            part["type"] == "text" for part in content
                        )
                        content[0]["text"] = prefix + content[0]["text"]
                        content[-1]["text"] += suffix
                    group = {
                        "study": "03-prefix-cache",
                        "id": f"{family}-{mode}-{number}",
                        "payload": payload,
                        "fixed_tokens": 16,
                        "concurrency": 1,
                        "warmup": number == -1,
                        "repetitions": 0 if number == -1 else 1,
                    }
                    if mode == "warm":
                        group["shared_salt"] = f"prefix-control:{family}:{key}"
                    groups.append(group)
        plan = {
            "model_key": key,
            "model_index": index,
            "profile": "prefix-controls",
            "groups": groups,
        }
        plans.append(plan)
        directory = ROOT / "runs" / f"{key}-prefix-controls"
        directory.mkdir(exist_ok=False)
        run_probe(NAMES[index], plan, directory)
    save(ROOT / "prefix-plan.json", plans)


if __name__ == "__main__":
    main()
