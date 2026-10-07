from __future__ import annotations

import argparse
import json
import signal
from pathlib import Path

from gpu_remote_orchestrator import command, restore, switch_model

BASE = Path("/opt/doglyad/.voice-benchmark/quality-v2")
MODEL = "Qwen/Qwen3.5-4B"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int)
    parser.add_argument("--directory", type=Path, default=BASE)
    parser.add_argument("--variants", nargs="+", default=["baseline", "updated"])
    args = parser.parse_args()
    base = args.directory
    status_path = base / "status.json"
    status: dict[str, str | bool] = {"modelId": MODEL, "stage": "starting", "restored": False}
    original = command("docker", "compose", "config", "--format", "json")
    if json.loads(original.stdout)["services"]["vllm"]["command"][0] != "google/medgemma-4b-it":
        raise RuntimeError("Original model is not MedGemma; refusing to change the VM")
    image = command("docker", "inspect", "doglyad-backend_inference-1", "--format", "{{.Image}}").stdout.strip()

    def save_status(stage: str) -> None:
        status["stage"] = stage
        status_path.write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
        print(stage, flush=True)

    def stop_requested(_signal: int, _frame: object) -> None:
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop_requested)
    try:
        save_status("loading-qwen")
        command("docker", "compose", "stop", "backend_inference")
        switch_model(MODEL)
        for variant in args.variants:
            save_status(f"running-{variant}")
            arguments = [
                "docker",
                "run",
                "--rm",
                "--network",
                "doglyad_default",
                "-v",
                f"{base}:/bench:rw",
                image,
                "python",
                "/bench/gpu_remote_runner.py",
                f"/bench/{variant}-cases.jsonl",
                f"/bench/{variant}-raw.jsonl",
                MODEL,
            ]
            if args.limit is not None:
                arguments += ["--limit", str(args.limit)]
            result = command(*arguments)
            print(result.stdout, flush=True)
    except BaseException as error:
        status["error"] = f"{type(error).__name__}: {str(error)[:300]}"
        raise
    finally:
        save_status("restoring-medgemma")
        restore()
        status["restored"] = True
        save_status("failed" if "error" in status else "complete")


if __name__ == "__main__":
    main()
