"""Run the four family trials sequentially after CPU preparation is complete."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent


def main() -> None:
    receipt = json.loads((ROOT / "gguf-artifacts.json").read_text())
    assert len(receipt) == 4
    names = ["vllm-15-4b", "llama-15-4b", "vllm-27b", "llama-27b"]
    for name in names:
        assert not (ROOT / name).exists(), f"Existing trial: {name}"
    for name in names:
        subprocess.run(
            ["python3", str(ROOT / "run_trial.py"), str(ROOT / f"{name}.json")],
            cwd=ROOT,
            check=True,
        )
    subprocess.run(["python3", str(ROOT / "check_restoration.py")], check=True)


if __name__ == "__main__":
    main()
