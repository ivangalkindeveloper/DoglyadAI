from __future__ import annotations

import json
import os
import signal
import subprocess
import time
from pathlib import Path
from typing import Any


BASE = Path("/opt/doglyad/.voice-benchmark")
MODEL_IDS = (
    "google/medgemma-4b-it",
    "Qwen/Qwen3-8B",
    "numind/NuExtract3-W4A16",
    "Qwen/Qwen3.5-4B",
    "numind/NuExtract-2.0-8B",
)


def command(*arguments: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(arguments, cwd="/opt/doglyad", env=env, capture_output=True, text=True, check=True)


def health(timeout_seconds: int = 1800) -> None:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        state = command(
            "docker",
            "inspect",
            "doglyad-vllm-1",
            "--format",
            "{{.State.Status}} {{.State.Health.Status}} {{.RestartCount}}",
        )
        container_status, health_status, restart_count = state.stdout.strip().split()
        if container_status == "running" and health_status == "healthy":
            return
        if container_status in {"dead", "exited"} or int(restart_count) >= 3:
            raise RuntimeError(f"vLLM stopped or repeatedly restarted: {container_status}, restarts={restart_count}")
        time.sleep(15)
    raise TimeoutError("vLLM did not become healthy")


def run_cases(image: str, model_id: str, suffix: str, limit: int | None = None) -> None:
    output_name = model_id.replace("/", "_") + suffix + ".jsonl"
    arguments = [
        "docker",
        "run",
        "--rm",
        "--network",
        "doglyad_default",
        "-v",
        f"{BASE}:/bench:rw",
        image,
        "python",
        "/bench/gpu_remote_runner.py",
        "/bench/cases.jsonl",
        f"/bench/results/{output_name}",
        model_id,
    ]
    if limit is not None:
        arguments += ["--limit", str(limit)]
    result = command(*arguments)
    print(result.stdout, flush=True)
    if result.stderr:
        print(result.stderr[-2000:], flush=True)


def switch_model(model_id: str) -> None:
    environment = os.environ.copy()
    environment["SERVED_MODEL_ID"] = model_id
    environment["VLLM_MAX_MODEL_LEN"] = "4096"
    environment["VLLM_MAX_NUM_SEQS"] = "2"
    command("docker", "compose", "up", "-d", "--no-deps", "--force-recreate", "vllm", env=environment)
    health()


def restore() -> None:
    # The original .env is never edited. Compose reads its original model ID here.
    command("docker", "compose", "up", "-d", "--force-recreate", "vllm", "backend_inference")
    health()
    state = command("docker", "inspect", "doglyad-backend_inference-1", "--format", "{{.State.Running}}")
    if state.stdout.strip() != "true":
        raise RuntimeError("Inference backend is not running after restoration")


def main() -> None:
    BASE.mkdir(mode=0o700, parents=True, exist_ok=True)
    (BASE / "results").mkdir(mode=0o700, exist_ok=True)
    original = {}
    for line in Path("/opt/doglyad/.env").read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            original[key] = value
    if original.get("SERVED_MODEL_ID") != MODEL_IDS[0]:
        raise RuntimeError("Original model is not MedGemma; refusing to change the VM")
    image = command("docker", "inspect", "doglyad-backend_inference-1", "--format", "{{.Image}}").stdout.strip()
    status_path = BASE / "status.json"
    status: dict[str, Any] = {"originalModel": MODEL_IDS[0], "models": {}}

    def stop_requested(_signal: int, _frame: object) -> None:
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop_requested)
    try:
        print("Running direct vLLM MedGemma baseline", flush=True)
        health()
        run_cases(image, MODEL_IDS[0], "")
        status["models"][MODEL_IDS[0]] = "complete"
        status_path.write_text(json.dumps(status, indent=2), encoding="utf-8")
        command("docker", "compose", "stop", "backend_inference")
        for model_id in MODEL_IDS[1:]:
            print(f"Switching to {model_id}", flush=True)
            try:
                switch_model(model_id)
                run_cases(image, model_id, "-pilot", limit=12)
                pilot_path = BASE / "results" / (model_id.replace("/", "_") + "-pilot.jsonl")
                pilot = [json.loads(line) for line in pilot_path.read_text(encoding="utf-8").splitlines()]
                if all(row["status"] != "ok" for row in pilot):
                    raise RuntimeError("All pilot requests failed")
                run_cases(image, model_id, "")
                status["models"][model_id] = "complete"
            except Exception as error:
                status["models"][model_id] = f"failed: {type(error).__name__}: {str(error)[:300]}"
                print(f"{model_id}: {status['models'][model_id]}", flush=True)
                logs = subprocess.run(
                    ("docker", "logs", "--tail", "100", "doglyad-vllm-1"), capture_output=True, text=True, check=False
                )
                (BASE / "results" / (model_id.replace("/", "_") + "-startup.log")).write_text(
                    (logs.stdout + logs.stderr)[-15000:], encoding="utf-8"
                )
            status_path.write_text(json.dumps(status, indent=2), encoding="utf-8")
    finally:
        print("Restoring MedGemma and inference backend", flush=True)
        try:
            restore()
            status["restored"] = True
        except Exception as error:
            status["restored"] = False
            status["restorationError"] = f"{type(error).__name__}: {str(error)[:300]}"
            raise
        finally:
            status_path.write_text(json.dumps(status, indent=2), encoding="utf-8")
    print("Benchmark complete", flush=True)


if __name__ == "__main__":
    main()
