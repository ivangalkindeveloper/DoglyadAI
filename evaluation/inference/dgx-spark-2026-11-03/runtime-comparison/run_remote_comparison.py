"""DGX-only controller. Restore the original engine even if an experiment fails."""

from __future__ import annotations

import json
from pathlib import Path
import signal
import subprocess
import time

DIRECTORY = Path(__file__).resolve().parent
ENGINE = "doglyad-dgx-vllm_medgemma_4b-1"
TEMPORARY = "doglyad-structured-runtime-evaluation"


def _event(event: str, **values: object) -> None:
    print(json.dumps({"event": event, **values}), flush=True)


def _inspect(name: str) -> dict:
    return json.loads(subprocess.check_output(["docker", "inspect", name]))[0]


def _run_probe(
    container: str, script: str, payload: object, output_name: str, timeout: int
) -> None:
    with (DIRECTORY / output_name).open("x") as output:
        result = subprocess.run(
            [
                "docker",
                "exec",
                "-i",
                container,
                "python3",
                "-c",
                (DIRECTORY / script).read_text(),
            ],
            input=json.dumps(payload),
            text=True,
            stdout=output,
            timeout=timeout,
        )
    if result.returncode:
        raise RuntimeError(f"{script} failed: {result.returncode}")
    _event("probe_finished", output=output_name)


def _idle(name: str) -> None:
    code = "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/metrics', timeout=5).read().decode())"
    metrics = subprocess.check_output(
        ["docker", "exec", name, "python3", "-c", code], text=True
    )
    counters = [
        float(line.split()[-1])
        for line in metrics.splitlines()
        if line.startswith(("vllm:num_requests_running{", "vllm:num_requests_waiting{"))
    ]
    assert len(counters) >= 2 and sum(counters) == 0, f"{name} is busy"


def _health(name: str, timeout: int) -> None:
    started = time.monotonic()
    code = "import urllib.request; assert urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=5).status == 200"
    while time.monotonic() - started < timeout:
        if not _inspect(name)["State"]["Running"]:
            raise RuntimeError(f"{name} stopped during startup")
        result = subprocess.run(
            ["docker", "exec", name, "python3", "-c", code],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            _event(
                "engine_ready", name=name, seconds=round(time.monotonic() - started, 1)
            )
            return
        time.sleep(5)
    raise TimeoutError(f"{name} startup timed out")


def _interrupted(signum: int, frame: object) -> None:
    raise RuntimeError(f"Evaluation interrupted by signal {signum}")


def main() -> None:
    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(sig, _interrupted)
    cases = json.loads((DIRECTORY / "cases.json").read_text())
    original = _inspect(ENGINE)
    assert original["State"]["Running"]
    # Snapshot only non-secret runtime fields; never save container Env.
    with (DIRECTORY / "runtime-before.json").open("x") as output:
        json.dump(
            {
                "id": original["Id"],
                "image": original["Image"],
                "cmd": original["Config"]["Cmd"],
                "startedAt": original["State"]["StartedAt"],
            },
            output,
            indent=2,
        )
    others = ["doglyad-dgx-vllm_medgemma_15_4b-1", "doglyad-dgx-vllm_medgemma_27b-1"]
    other_starts = {name: _inspect(name)["State"]["StartedAt"] for name in others}
    for name in [ENGINE, *others]:
        _idle(name)
    _event("baseline_started")
    _run_probe(ENGINE, "probe_vllm.py", cases, "vllm-xgrammar.jsonl", 2400)
    baseline = [
        json.loads(line)
        for line in (DIRECTORY / "vllm-xgrammar.jsonl").read_text().splitlines()
    ]
    assert len(baseline) == len(cases) and not any(row.get("error") for row in baseline)
    for case, row in zip(cases, baseline, strict=True):
        assert case["id"] == row["id"]
        case["prompt_token_ids"] = row["prompt_token_ids"]
    try:
        for name in [ENGINE, *others]:
            _idle(name)
        subprocess.run(
            ["docker", "stop", "-t", "30", ENGINE],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
        )
        _event("original_engine_stopped")
        memory = {
            line.split(":")[0]: int(line.split()[1])
            for line in Path("/proc/meminfo").read_text().splitlines()
        }
        assert memory["MemAvailable"] > 22 * 1024 * 1024, "Insufficient available RAM"
        args = list(original["Config"]["Cmd"])
        index = args.index("--structured-outputs-config") + 1
        config = json.loads(args[index])
        assert config == {"backend": "xgrammar", "disable_any_whitespace": True}
        args[index] = json.dumps({**config, "backend": "guidance"})
        command = [
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
            ENGINE + ":ro",
            "-e",
            "HF_HUB_OFFLINE=1",
            "-e",
            "TRANSFORMERS_OFFLINE=1",
            "-e",
            "VLLM_NO_USAGE_STATS=1",
            original["Image"],
            *args,
        ]
        subprocess.run(command, check=True, timeout=60, stdout=subprocess.DEVNULL)
        _event("guidance_starting")
        _health(TEMPORARY, 600)
        _run_probe(TEMPORARY, "probe_vllm.py", cases, "vllm-guidance.jsonl", 2400)
        with (DIRECTORY / "guidance-container.log").open("w") as output:
            subprocess.run(
                ["docker", "logs", TEMPORARY], stdout=output, stderr=subprocess.STDOUT
            )
        subprocess.run(
            ["docker", "rm", "-f", TEMPORARY],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
        )
        args = original["Config"]["Cmd"]
        revision = args[args.index("--revision") + 1]
        snapshot = (
            "/root/.cache/huggingface/hub/models--google--medgemma-4b-it/snapshots/"
            + revision
        )
        command = [
            "docker",
            "run",
            "-d",
            "--name",
            TEMPORARY,
            "--gpus",
            "all",
            "--network",
            "none",
            "--volumes-from",
            ENGINE + ":ro",
            "-e",
            "HF_HUB_OFFLINE=1",
            "-e",
            "TRANSFORMERS_OFFLINE=1",
            "-e",
            "HF_HUB_DISABLE_PROGRESS_BARS=1",
            "--entrypoint",
            "sleep",
            original["Image"],
            "3600",
        ]
        subprocess.run(command, check=True, timeout=60, stdout=subprocess.DEVNULL)
        _event("transformers_starting")
        _run_probe(
            TEMPORARY,
            "probe_transformers.py",
            {"cases": cases, "snapshot": snapshot},
            "transformers-xgrammar.jsonl",
            2700,
        )
    finally:
        if (
            subprocess.run(
                ["docker", "inspect", TEMPORARY],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode
            == 0
        ):
            with (DIRECTORY / "last-container.log").open("w") as output:
                subprocess.run(
                    ["docker", "logs", TEMPORARY],
                    stdout=output,
                    stderr=subprocess.STDOUT,
                )
            subprocess.run(
                ["docker", "rm", "-f", TEMPORARY], timeout=60, stdout=subprocess.DEVNULL
            )
        subprocess.run(
            ["docker", "start", ENGINE],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
        )
        _event("original_engine_restoring")
        _health(ENGINE, 600)
        restored = _inspect(ENGINE)
        assert (
            restored["Id"] == original["Id"]
            and restored["Config"]["Cmd"] == original["Config"]["Cmd"]
        )
        for name in [ENGINE, *others]:
            _idle(name)
        assert all(
            _inspect(name)["State"]["StartedAt"] == started
            for name, started in other_starts.items()
        )
        _event("restoration_verified", unchanged_other_engines=others)
    _event("finished")


if __name__ == "__main__":
    main()
