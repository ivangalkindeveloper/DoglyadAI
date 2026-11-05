"""Confirm the restored host remains ready when the collected results are published."""

import json
from pathlib import Path
import shlex
import time

from run import NAMES, ROOT, TEMP, call, healthy, save, snapshot


def main() -> None:
    original = json.loads((ROOT / "runtime-before.json").read_text())
    completed = json.loads((ROOT / "verification.json").read_text())
    for name in NAMES[:3]:
        healthy(name, timeout=30)
    current = snapshot()
    checks = {}
    for name in NAMES:
        checks[name] = {
            field: original[name][field] == current[name][field]
            for field in ["id", "image", "command", "restart_policy"]
        }
        checks[name]["running"] = current[name]["running"]
    processes = []
    for line in call(["ps", "-eo", "pid=,args="]).splitlines():
        try:
            tokens = shlex.split(line)
        except ValueError:
            continue
        if len(tokens) < 3 or not Path(tokens[1]).name.startswith("python"):
            continue
        owned = [
            str(ROOT / filename)
            for filename in [
                "run.py",
                "after_matrix.py",
                "mixed.py",
                "cache_pressure.py",
                "prefix.py",
                "observe.py",
            ]
        ]
        if any(path in tokens[2:] for path in owned):
            processes.append(line.strip())
    result = {
        "unix": time.time(),
        "containers": checks,
        "backend_never_restarted": original[NAMES[3]]["started"]
        == current[NAMES[3]]["started"],
        "same_boot": Path("/proc/sys/kernel/random/boot_id").read_text().strip()
        == completed["boot_id"],
        "no_temporary_container": TEMP
        not in call(["docker", "ps", "-a", "--format", "{{.Names}}"]).splitlines(),
        "remaining_experiment_processes": processes,
    }
    save(ROOT / "readiness-latest.json", result)
    save(ROOT / "runtime-latest.json", current)
    assert all(all(row.values()) for row in checks.values())
    assert result["backend_never_restarted"] and result["same_boot"]
    assert result["no_temporary_container"] and not processes
    print(
        "All original services remain ready; no experiment processes or temporary container remain."
    )


if __name__ == "__main__":
    main()
