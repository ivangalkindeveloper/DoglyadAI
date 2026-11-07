"""Full synthetic answers at 4/4/4, using unchanged application cases.

Run on the DGX host. Engine URLs stay inside the Docker network. No App Check
route is disabled; this is an engine benchmark, not an authenticated API test.
"""

import concurrent.futures
import copy
import fcntl
import json
from pathlib import Path
import sys
import threading
import time

from observe import NAMES, healthy, idle, inspect, save, snapshot, telemetry
from probe import request

ROOT = Path(__file__).resolve().parent
KEYS = ["4b", "15-4b", "27b"]
WAVES = [
    ("warmup", ["report-greedy-0"] * 4),
    ("report-1", ["report-greedy-0"] * 4),
    ("report-2", ["report-greedy-0"] * 4),
    ("mixed-1", ["report-sample-42", "conflict-greedy-0", "dictation-greedy-0", "vision-2"]),
    ("mixed-2", ["bladder-correction-sample-42", "bladder-en-sample-42", "conflict-sample-42", "vision-1"]),
]


def main():
    profile = sys.argv[1]
    assert profile in {"baseline", "ngram8"}
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    out = ROOT / profile
    out.mkdir(exist_ok=False)
    save(out / "runtime-before.json", snapshot())
    endpoints, cases = {}, {}
    for key, name in zip(KEYS, NAMES[:3]):
        healthy(name)
        idle(name)
        info = inspect(name)
        command = info["Config"]["Cmd"]
        assert ("--speculative-config" in command) == (profile == "ngram8")
        if profile == "ngram8":
            assert json.loads(command[command.index("--speculative-config") + 1]) == {
                "method": "ngram", "num_speculative_tokens": 8,
                "prompt_lookup_min": 2, "prompt_lookup_max": 5,
            }
        addresses = [n["IPAddress"] for n in info["NetworkSettings"]["Networks"].values() if n["IPAddress"]]
        assert len(addresses) == 1
        endpoints[key] = "http://" + addresses[0] + ":8000"
        cases[key] = {c["id"]: c for c in json.loads((ROOT / f"cases-{key}.json").read_text())}
    save(out / "plan.json", {"waves": WAVES, "endpoints": endpoints, "concurrency": [4, 4, 4]})
    finish = threading.Event()
    current = {"wave": "starting"}

    def watch():
        with (out / "telemetry.jsonl").open("x") as f:
            while not finish.is_set():
                f.write(json.dumps({**telemetry(), **current}) + "\n")
                f.flush()
                finish.wait(5)

    watcher = threading.Thread(target=watch)
    watcher.start()
    try:
        with (out / "results.jsonl").open("x") as f:
            for wave, ids in WAVES:
                current["wave"] = wave
                before = {name: idle(name) for name in NAMES[:3]}
                barrier = threading.Barrier(12)

                def perform(job):
                    key, client, case_id = job
                    payload = copy.deepcopy(cases[key][case_id]["payload"])
                    # Distinct cache keys prevent cross-request prefix hits.
                    payload["cache_salt"] = f"rollout:{profile}:{wave}:{key}:{client}"
                    return {"model": key, "client": client, "case": case_id,
                            **request(payload, endpoints[key], barrier)}

                jobs = [(key, i, case) for i, case in enumerate(ids) for key in KEYS]
                started = time.perf_counter()
                with concurrent.futures.ThreadPoolExecutor(12) as pool:
                    results = list(pool.map(perform, jobs))
                after = {name: idle(name) for name in NAMES[:3]}
                row = {"wave": wave, "unix": time.time(), "seconds": time.perf_counter() - started,
                       "requests": results, "metrics_before": before, "metrics_after": after}
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
                f.flush()
                valid = all(r["done"] and r["finish"] == "stop" and not r.get("error") for r in results)
                print(json.dumps({"profile": profile, "wave": wave, "seconds": row["seconds"], "natural_stop_all": valid}), flush=True)
                if not valid:
                    raise RuntimeError("Incomplete full answer; see retained results")
    finally:
        finish.set()
        watcher.join(timeout=20)
        save(out / "runtime-after.json", snapshot())


if __name__ == "__main__":
    main()
