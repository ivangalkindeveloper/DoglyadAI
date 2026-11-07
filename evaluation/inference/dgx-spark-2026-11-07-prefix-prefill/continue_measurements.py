"""Run independent measurement stages sequentially on the same GPU."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent


def main() -> None:
    pid = json.loads((ROOT / "comparison-pid.json").read_text())["pid"]
    while Path(f"/proc/{pid}").exists():
        time.sleep(5)
    rows = [
        json.loads(line)
        for line in (ROOT / "prefix-comparison.jsonl").read_text().splitlines()
    ]
    assert rows[-1]["event"] == "complete", "Initial comparison did not finish"
    stages = [
        (
            "prefix-fixed",
            [
                "run_prefix.py",
                "--scenarios",
                "ru-photo1-template1",
                "ru-photo0-template1",
                "--repetitions",
                "3",
                "--output-tokens",
                "16",
                "--output",
                "prefix-fixed.jsonl",
            ],
        ),
        (
            "template-holdout",
            [
                "run_prefix.py",
                "--scenarios",
                "ru-photo0-template1",
                "en-photo0-template1",
                "--variants",
                "baseline",
                "template_first",
                "--repetitions",
                "1",
                "--output",
                "template-holdout.jsonl",
            ],
        ),
        ("prefill", ["prefill_controller.py"]),
        (
            "restored-smoke",
            [
                "run_prefix.py",
                "--scenarios",
                "ru-photo0-template0",
                "--variants",
                "baseline",
                "--repetitions",
                "1",
                "--output",
                "restored-smoke.jsonl",
            ],
        ),
    ]
    for name, arguments in stages:
        (ROOT / "queue-status.json").write_text(
            json.dumps({"stage": name, "state": "running", "unix": time.time()})
        )
        print(json.dumps({"stage": name, "state": "starting"}), flush=True)
        with (ROOT / f"{name}.log").open("x") as log:
            result = subprocess.run(
                ["python3", "-u", *arguments],
                cwd=ROOT,
                stdout=log,
                stderr=subprocess.STDOUT,
            )
        print(json.dumps({"stage": name, "exit_code": result.returncode}), flush=True)
        if result.returncode:
            (ROOT / "queue-status.json").write_text(
                json.dumps(
                    {
                        "stage": name,
                        "state": "failed",
                        "exit_code": result.returncode,
                        "unix": time.time(),
                    }
                )
            )
            raise RuntimeError(f"Stage failed: {name}")
    (ROOT / "queue-status.json").write_text(
        json.dumps({"state": "complete", "unix": time.time()})
    )


if __name__ == "__main__":
    main()
