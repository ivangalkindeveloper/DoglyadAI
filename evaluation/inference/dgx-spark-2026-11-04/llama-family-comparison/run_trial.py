"""Run one DGX experiment with guaranteed restoration of the selected vLLM."""

from __future__ import annotations

import argparse
import fcntl
import json
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parent
NAMES = [
    "doglyad-dgx-vllm_medgemma_4b-1",
    "doglyad-dgx-vllm_medgemma_15_4b-1",
    "doglyad-dgx-vllm_medgemma_27b-1",
    "doglyad-dgx-backend_inference-1",
]
TEMP = "doglyad-survey-engine"


def _inspect(name: str) -> dict:
    return json.loads(subprocess.check_output(["docker", "inspect", name]))[0]


def _snapshot() -> dict:
    result = {}
    for name in NAMES:
        d = _inspect(name)
        result[name] = {
            "id": d["Id"],
            "image": d["Image"],
            "command": d["Config"]["Cmd"],
            "started": d["State"]["StartedAt"],
            "running": d["State"]["Running"],
            "health": d["State"].get("Health", {}).get("Status"),
        }
    result["memory"] = {
        line.split(":")[0]: int(line.split()[1])
        for line in Path("/proc/meminfo").read_text().splitlines()
        if line.startswith(("MemAvailable:", "SwapFree:"))
    }
    result["gpu"] = subprocess.check_output(
        [
            "nvidia-smi",
            "--query-gpu=temperature.gpu,power.draw",
            "--format=csv,noheader",
        ],
        text=True,
    ).strip()
    return result


def _metrics(name: str) -> str:
    return subprocess.check_output(
        [
            "docker",
            "exec",
            name,
            "python3",
            "-c",
            "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/metrics',timeout=5).read().decode())",
        ],
        text=True,
    )


def _activity() -> dict:
    result = {}
    for name in NAMES[:3]:
        lines = _metrics(name).splitlines()
        busy = [
            float(line.split()[-1])
            for line in lines
            if line.startswith(
                ("vllm:num_requests_running{", "vllm:num_requests_waiting{")
            )
        ]
        assert len(busy) >= 2 and sum(busy) == 0, f"Busy engine: {name}"
        result[name] = [
            line
            for line in lines
            if line.startswith(
                ("vllm:generation_tokens_total{", "vllm:request_success_total{")
            )
        ]
    return result


def _health(name: str, url: str, seconds: int = 900) -> None:
    code = f"import urllib.request; assert urllib.request.urlopen({url!r},timeout=5).status == 200"
    start = time.monotonic()
    while time.monotonic() - start < seconds:
        if not _inspect(name)["State"]["Running"]:
            raise RuntimeError(f"Engine exited: {name}")
        if (
            subprocess.run(
                ["docker", "exec", name, "python3", "-c", code],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode
            == 0
        ):
            return
        time.sleep(5)
    raise TimeoutError("Engine startup")


def _signal(signum: int, frame: object) -> None:
    raise RuntimeError(f"Interrupted: {signum}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("plan", type=Path)
    args = parser.parse_args()
    lock = Path("/var/tmp/doglyad-engine-survey-20261104/engine.lock").open("a")
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    plan = json.loads(args.plan.read_text())
    directory = ROOT / plan["name"]
    directory.mkdir(exist_ok=False)
    (directory / "plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    original_name = NAMES[plan.get("model_index", 0)]
    original = _inspect(original_name)
    before = _snapshot()
    assert all(before[n]["running"] for n in NAMES)
    activity_before = _activity()
    (directory / "before.json").write_text(json.dumps(before, indent=2) + "\n")
    for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, _signal)
    temporary = False
    stopped = False
    try:
        if plan["engine"] != "vllm":
            stopped = True
            subprocess.run(
                ["docker", "stop", "-t", "30", original_name],
                check=True,
                stdout=subprocess.DEVNULL,
                timeout=60,
            )
            print(
                json.dumps({"event": "original_stopped", "trial": plan["name"]}),
                flush=True,
            )
            # The original two other models stay idle and loaded. Prevent host OOM.
            memory = _snapshot()["memory"]["MemAvailable"]
            assert memory > plan.get("minimum_available_gib", 20) * 1024 * 1024, memory
            command = [
                "docker",
                "run",
                "-d",
                "--name",
                TEMP,
                "--gpus",
                "all",
                "--network",
                plan.get("network", "none"),
                "--shm-size",
                "2g",
                "--memory",
                plan.get("memory", "24g"),
                "--memory-swap",
                plan.get("memory", "24g"),
                "--volumes-from",
                original_name + ":ro",
                "--mount",
                f"type=bind,src={ROOT},dst=/survey",
                "-e",
                "HF_HUB_OFFLINE=1",
                "-e",
                "TRANSFORMERS_OFFLINE=1",
                "-e",
                "HF_HUB_DISABLE_PROGRESS_BARS=1",
                "--entrypoint",
                plan["entrypoint"],
                plan.get("image", original["Image"]),
                *plan["args"],
            ]
            for value in plan.get("env", []):
                command[2:2] = ["--env", value]
            if plan.get("asset_directory"):
                command[2:2] = [
                    "--mount",
                    f"type=bind,src={plan['asset_directory']},dst=/assets,readonly",
                ]
            (directory / "command.json").write_text(
                json.dumps(command, indent=2) + "\n"
            )
            subprocess.run(command, check=True, stdout=subprocess.DEVNULL, timeout=60)
            temporary = True
            container = TEMP
            if plan.get("mode") != "direct":
                _health(
                    container, plan.get("health_url", "http://127.0.0.1:8000/health")
                )
        else:
            container = original_name
        print(json.dumps({"event": "probe_started", "trial": plan["name"]}), flush=True)
        cases = json.loads((ROOT / plan["cases_file"]).read_text())
        if "case_ids" in plan:
            cases = [c for c in cases if c["id"] in plan["case_ids"]]
        settings = {
            "engine": plan["engine"],
            "cases": cases,
            "performance": json.loads((ROOT / plan["performance_file"]).read_text()),
            "concurrencies": plan.get("concurrencies", [1, 4]),
            "repetitions": plan.get("repetitions", 5),
            **plan.get("settings", {}),
        }
        with (
            (directory / "results.jsonl").open("x") as output,
            (directory / "probe-stderr.log").open("x") as errors,
        ):
            result = subprocess.run(
                [
                    "docker",
                    "exec",
                    "-i",
                    container,
                    plan.get("python", "python3"),
                    "-c",
                    (ROOT / plan.get("probe", "probe_http.py")).read_text(),
                ],
                input=json.dumps(settings),
                text=True,
                stdout=output,
                stderr=errors,
                timeout=7200,
            )
            if result.returncode:
                raise RuntimeError(f"Probe failed: {result.returncode}")
    except Exception as error:
        (directory / "failure.json").write_text(
            json.dumps({"type": type(error).__name__, "detail": str(error)}, indent=2)
            + "\n"
        )
        raise
    finally:
        if temporary:
            with (directory / "container.log").open("w") as log:
                subprocess.run(
                    ["docker", "logs", TEMP], stdout=log, stderr=subprocess.STDOUT
                )
            subprocess.run(
                ["docker", "rm", "-f", TEMP],
                check=True,
                stdout=subprocess.DEVNULL,
                timeout=60,
            )
        if stopped:
            subprocess.run(
                ["docker", "start", original_name],
                check=True,
                stdout=subprocess.DEVNULL,
                timeout=60,
            )
            _health(original_name, "http://127.0.0.1:8000/health", 1200)
        after = _snapshot()
        (directory / "after.json").write_text(json.dumps(after, indent=2) + "\n")
        activity_after = _activity()
        (directory / "activity.json").write_text(
            json.dumps({"before": activity_before, "after": activity_after}, indent=2)
            + "\n"
        )
        for name in NAMES:
            assert (
                after[name]["id"] == before[name]["id"]
                and after[name]["image"] == before[name]["image"]
                and after[name]["running"]
            )
            if name != original_name:
                assert after[name]["started"] == before[name]["started"]
                if name in NAMES[:3]:
                    assert activity_before[name] == activity_after[name], name
        print(json.dumps({"event": "restored", "trial": plan["name"]}), flush=True)


if __name__ == "__main__":
    main()
