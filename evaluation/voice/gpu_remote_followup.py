from __future__ import annotations

import json
import signal
from pathlib import Path

from gpu_remote_orchestrator import BASE, command, restore, run_cases, switch_model

MODEL_ID = "numind/NuExtract-2.0-8B-GPTQ"


def main() -> None:
    status_path = BASE / "status-gptq.json"
    status: dict[str, object] = {"modelId": MODEL_ID, "status": "running", "restored": False}
    original = {}
    for line in Path("/opt/doglyad/.env").read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            original[key] = value
    if original.get("SERVED_MODEL_ID") != "google/medgemma-4b-it":
        raise RuntimeError("Original model is not MedGemma")
    image = command("docker", "inspect", "doglyad-backend_inference-1", "--format", "{{.Image}}").stdout.strip()

    def stop_requested(_signal: int, _frame: object) -> None:
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, stop_requested)
    try:
        command("docker", "compose", "stop", "backend_inference")
        print(f"Switching to {MODEL_ID}", flush=True)
        switch_model(MODEL_ID)
        run_cases(image, MODEL_ID, "-pilot", limit=12)
        pilot_path = BASE / "results" / (MODEL_ID.replace("/", "_") + "-pilot.jsonl")
        pilot = [json.loads(line) for line in pilot_path.read_text(encoding="utf-8").splitlines()]
        if all(row["status"] != "ok" for row in pilot):
            raise RuntimeError("All pilot requests failed")
        run_cases(image, MODEL_ID, "")
        status["status"] = "complete"
    except Exception as error:
        status["status"] = f"failed: {type(error).__name__}: {str(error)[:300]}"
        raise
    finally:
        print("Restoring MedGemma and inference backend", flush=True)
        try:
            restore()
            status["restored"] = True
        finally:
            status_path.write_text(json.dumps(status, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
