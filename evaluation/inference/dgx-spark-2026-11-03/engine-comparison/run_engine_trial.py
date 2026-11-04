"""Run one isolated engine experiment on DGX, then restore the original container."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import signal
import subprocess
import sys
import time

DIRECTORY = Path(__file__).resolve().parent
sys.path.insert(0, str(DIRECTORY.parent / "runtime-comparison"))
import run_remote_comparison as lifecycle  # noqa: E402

ORIGINAL = "doglyad-dgx-vllm_medgemma_4b-1"
TEMPORARY = "doglyad-engine-evaluation"
OTHERS = [
    "doglyad-dgx-vllm_medgemma_15_4b-1",
    "doglyad-dgx-vllm_medgemma_27b-1",
    "doglyad-dgx-backend_inference-1",
]


def _snapshot(names: list[str]) -> dict:
    result = {}
    for name in names:
        value = lifecycle._inspect(name)
        result[name] = {
            "id": value["Id"],
            "image": value["Image"],
            "cmd": value["Config"]["Cmd"],
            "started_at": value["State"]["StartedAt"],
            "running": value["State"]["Running"],
            "health": value["State"].get("Health", {}).get("Status"),
        }
    return result


def _memory() -> dict:
    values = {}
    for line in Path("/proc/meminfo").read_text().splitlines():
        key = line.split(":")[0]
        if key in ("MemTotal", "MemAvailable", "SwapTotal", "SwapFree"):
            values[key + "_kib"] = int(line.split()[1])
    return values


def _activity() -> dict:
    result = {}
    for name in OTHERS[:2]:
        code = "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/metrics', timeout=5).read().decode())"
        metrics = subprocess.check_output(
            ["docker", "exec", name, "python3", "-c", code], text=True
        )
        result[name] = [
            line
            for line in metrics.splitlines()
            if line.startswith(
                ("vllm:request_success_total{", "vllm:generation_tokens_total{")
            )
        ]
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    output = DIRECTORY / plan["name"]
    output.mkdir(exist_ok=False)
    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(sig, lifecycle._interrupted)
    names = [ORIGINAL, *OTHERS]
    original = lifecycle._inspect(ORIGINAL)
    before = _snapshot(names)
    assert all(v["running"] for v in before.values())
    (output / "runtime-before.json").write_text(json.dumps(before, indent=2) + "\n")
    for name in names[:3]:
        lifecycle._idle(name)
    activity_before = _activity()
    failure = None
    try:
        subprocess.run(
            ["docker", "stop", "-t", "30", ORIGINAL],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
        )
        lifecycle._event("original_stopped", memory=_memory())
        assert _memory()["MemAvailable_kib"] > 22 * 1024 * 1024
        common = [
            "docker",
            "run",
            "-d",
            "--name",
            TEMPORARY,
            "--gpus",
            "all",
            "--network",
            "none",
            "--shm-size",
            str(original["HostConfig"]["ShmSize"]),
            "--volumes-from",
            ORIGINAL + ":ro",
            "--mount",
            f"type=bind,src={DIRECTORY},dst=/evaluation,readonly",
            "-e",
            "HF_HUB_OFFLINE=1",
            "-e",
            "TRANSFORMERS_OFFLINE=1",
            "-e",
            "HF_HUB_DISABLE_PROGRESS_BARS=1",
            "-e",
            "VLLM_NO_USAGE_STATS=1",
        ]
        if plan["engine"] == "vllm":
            engine_args = list(original["Config"]["Cmd"])
            engine_args[engine_args.index("--max-num-seqs") + 1] = str(
                plan["max_sequences"]
            )
            command = common + [original["Image"], *engine_args]
        else:
            command = common + [
                plan["image"],
                "python3",
                "-m",
                "sglang.launch_server",
                *plan["args"],
            ]
        (output / "command.json").write_text(json.dumps(command, indent=2) + "\n")
        subprocess.run(command, check=True, timeout=60, stdout=subprocess.DEVNULL)
        lifecycle._event("starting", name=plan["name"])
        lifecycle._health(TEMPORARY, 1200)
        lifecycle._event("probe_started", memory=_memory())
        cases = json.loads((DIRECTORY / plan.get("cases", "cases.json")).read_text())
        if plan["engine"] == "sglang":
            reference = {
                row["id"]: row
                for line in (DIRECTORY / "vllm-maxseq-1/results.jsonl")
                .read_text()
                .splitlines()
                if (row := json.loads(line)).get("phase") == "quality"
            }
            for case in cases:
                if case["kind"] != "vision":
                    case["expected_prompt_token_ids"] = reference[case["id"]][
                        "prompt_token_ids"
                    ]
        if plan.get("case_ids"):
            cases = [case for case in cases if case["id"] in plan["case_ids"]]
        payload = {
            "engine": plan["engine"],
            "cases": cases,
            "performance": False,
            "concurrencies": plan.get("concurrencies", [1, 4]),
            "repetitions": plan.get("repetitions", 3),
        }
        with (output / "results.jsonl").open("x") as destination:
            subprocess.run(
                [
                    "docker",
                    "exec",
                    "-i",
                    TEMPORARY,
                    "python3",
                    "-c",
                    (DIRECTORY / "probe_engine.py").read_text(),
                ],
                input=json.dumps(payload),
                text=True,
                stdout=destination,
                check=True,
                timeout=5400,
            )
        if plan.get("performance", True):
            # A concurrent Docker image download/unpack must not contaminate speed measurements.
            required_image = plan.get("wait_for_image")
            if required_image:
                lifecycle._event("waiting_for_image_before_timing")
                deadline = time.monotonic() + 3600
                while subprocess.run(
                    ["docker", "image", "inspect", required_image], capture_output=True
                ).returncode:
                    if time.monotonic() > deadline:
                        raise TimeoutError("Image pull did not finish before benchmark")
                    time.sleep(5)
            lifecycle._event("performance_started")
            payload.update(quality=False, performance=True)
            with (output / "results.jsonl").open("a") as destination:
                subprocess.run(
                    [
                        "docker",
                        "exec",
                        "-i",
                        TEMPORARY,
                        "python3",
                        "-c",
                        (DIRECTORY / "probe_engine.py").read_text(),
                    ],
                    input=json.dumps(payload),
                    text=True,
                    stdout=destination,
                    check=True,
                    timeout=2400,
                )
        lifecycle._event("probe_finished", memory=_memory())
        activity_after = _activity()
        (output / "other-engine-activity.json").write_text(
            json.dumps(
                {
                    "before": activity_before,
                    "after": activity_after,
                    "unchanged": activity_before == activity_after,
                },
                indent=2,
            )
            + "\n"
        )
        assert activity_before == activity_after, (
            "Other engines received traffic; timings are contaminated"
        )
        for name in OTHERS[:2]:
            lifecycle._idle(name)
    except Exception as error:
        failure = type(error).__name__ + ": " + str(error)[:1000]
        (output / "failure.json").write_text(json.dumps({"error": failure}) + "\n")
        lifecycle._event("trial_failed", error=failure)
    finally:
        if (
            subprocess.run(
                ["docker", "inspect", TEMPORARY], capture_output=True
            ).returncode
            == 0
        ):
            with (output / "container.log").open("w") as log:
                subprocess.run(
                    ["docker", "logs", TEMPORARY], stdout=log, stderr=subprocess.STDOUT
                )
            subprocess.run(
                ["docker", "rm", "-f", TEMPORARY],
                check=True,
                timeout=60,
                stdout=subprocess.DEVNULL,
            )
        subprocess.run(
            ["docker", "start", ORIGINAL],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
        )
        lifecycle._event("restoring_original")
        lifecycle._health(ORIGINAL, 900)
        after = _snapshot(names)
        for name in names:
            assert all(
                before[name][key] == after[name][key] for key in ("id", "image", "cmd")
            )
            if name != ORIGINAL:
                assert before[name]["started_at"] == after[name]["started_at"]
        for name in names[:3]:
            lifecycle._idle(name)
        (output / "runtime-after.json").write_text(json.dumps(after, indent=2) + "\n")
        lifecycle._event("restoration_verified")
    if failure:
        raise RuntimeError(failure)
    lifecycle._event("finished")


if __name__ == "__main__":
    main()
