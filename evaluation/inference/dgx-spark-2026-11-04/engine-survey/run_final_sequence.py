"""Wait for the LMDeploy trial to restore vLLM, then run the final comparisons."""

import fcntl
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
with (root / "engine.lock").open("a") as lock:
    fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
    assert (root / "lmdeploy-4b-grammar-experimental/after.json").exists()
subprocess.run(
    ["python3", "run_prepared.py", "tensorrt-4b-bf16.json", "vllm-4b-final.json"],
    cwd=root,
    check=True,
)
