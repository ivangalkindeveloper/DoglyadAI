"""Run prepared trials serially; stop if restoration cannot be verified."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys


def main() -> None:
    root = Path(__file__).resolve().parent
    for filename in sys.argv[1:]:
        plan = json.loads((root / filename).read_text())
        print(json.dumps({"event": "trial_begin", "plan": filename}), flush=True)
        code = subprocess.run(
            [sys.executable, str(root / "run_trial.py"), str(root / filename)]
        ).returncode
        after = json.loads((root / plan["name"] / "after.json").read_text())
        assert all(
            value["running"]
            for name, value in after.items()
            if name.startswith("doglyad-")
        )
        print(
            json.dumps({"event": "trial_end", "plan": filename, "exit": code}),
            flush=True,
        )


if __name__ == "__main__":
    main()
