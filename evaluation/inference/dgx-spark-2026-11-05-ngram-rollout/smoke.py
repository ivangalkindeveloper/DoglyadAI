"""One complete synthetic report after restoring the 1.5 4B N-gram engine."""

import fcntl
import json
from pathlib import Path

from observe import idle, inspect, save
from probe import request

ROOT = Path(__file__).resolve().parent


def main():
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    assert (
        json.loads((ROOT / "sampling-check/status.json").read_text())["status"]
        == "ngram8_restored"
    )
    name = "doglyad-dgx-vllm_medgemma_15_4b-1"
    info = inspect(name)
    assert "--speculative-config" in info["Config"]["Cmd"]
    addresses = [
        n["IPAddress"]
        for n in info["NetworkSettings"]["Networks"].values()
        if n["IPAddress"]
    ]
    assert len(addresses) == 1
    case = next(
        c
        for c in json.loads((ROOT / "cases-15-4b.json").read_text())
        if c["id"] == "report-greedy-0"
    )
    before = idle(name)
    result = request(case["payload"], "http://" + addresses[0] + ":8000")
    save(
        ROOT / "post-restore-smoke.json",
        {"result": result, "metrics_before": before, "metrics_after": idle(name)},
    )
    assert result["done"] and result["finish"] == "stop" and not result.get("error")
    assert result["seconds"] < 120
    json.loads(result["text"])
    print("Restored 1.5 4B generated a complete JSON report.")


if __name__ == "__main__":
    main()
