"""Wait for the isolated trials, then run shared-GPU scheduling measurements."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parent


def main() -> None:
    deadline = time.monotonic() + 6 * 3600
    while not (ROOT / "restoration.json").exists():
        if time.monotonic() > deadline:
            raise TimeoutError("Isolated matrix did not restore within six hours")
        time.sleep(15)
    checks = json.loads((ROOT / "restoration.json").read_text())
    assert all(all(values.values()) for values in checks.values())
    # Let the first controller release its exclusive lock after restoration.
    time.sleep(5)
    subprocess.run(["python3", "-u", str(ROOT / "mixed.py")], check=True)


if __name__ == "__main__":
    main()
