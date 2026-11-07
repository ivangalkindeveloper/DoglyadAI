"""Arm a single local model fault and bind its receipt to the observed backend job."""

import hashlib
import json
from pathlib import Path
import re


def arm_worker(directory: Path, control: dict) -> set[Path]:
    if set(control) != {"mode", "examinationNumber"} or control["mode"] not in {
        "fail-before", "fail-after-preview", "delay-completion"
    } or not re.fullmatch(r"REG-[A-Z0-9-]+", control["examinationNumber"]):
        raise ValueError("Invalid worker control")
    directory.mkdir(mode=0o777, exist_ok=True)
    directory.chmod(0o777)
    before = set(directory.glob("worker-applied-*.json"))
    with (directory / "worker-control.json").open("x") as output:
        json.dump(control, output)
    return before


def verify_worker(directory: Path, before: set[Path], control: dict, identity: str) -> dict:
    if not re.fullmatch(r"[a-fA-F0-9-]{36}", identity):
        raise ValueError("Invalid controlled job identity")
    expected = directory / ("worker-applied-" + identity + ".json")
    if (directory / "worker-control.json").exists() or set(directory.glob("worker-applied-*.json")) - before != {expected}:
        raise ValueError("The expected report job did not consume exactly one worker control")
    if json.loads(expected.read_text()) != control:
        raise ValueError("Worker control receipt differs from the requested scenario")
    return {"generationId": identity, "control": control, "sha256": hashlib.sha256(expected.read_bytes()).hexdigest()}
