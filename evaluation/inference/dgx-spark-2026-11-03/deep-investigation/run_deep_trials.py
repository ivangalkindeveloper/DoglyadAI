"""Run a fixed DGX trial plan and restore the original 4B engine in all paths."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import signal
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "runtime-comparison"))
import run_remote_comparison as lifecycle

DIRECTORY = Path(__file__).resolve().parent
ENGINE = "doglyad-dgx-vllm_medgemma_4b-1"
TEMPORARY = "doglyad-deep-evaluation"


def _remove_temporary(directory: Path, name: str) -> None:
    if subprocess.run(["docker", "inspect", TEMPORARY], capture_output=True).returncode:
        return
    with (directory / (name + "-container.log")).open("w") as output:
        subprocess.run(
            ["docker", "logs", TEMPORARY], stdout=output, stderr=subprocess.STDOUT
        )
    subprocess.run(
        ["docker", "rm", "-f", TEMPORARY],
        check=True,
        timeout=60,
        stdout=subprocess.DEVNULL,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    directory = DIRECTORY / plan["output_directory"]
    directory.mkdir(exist_ok=False)
    lifecycle.DIRECTORY = directory
    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(sig, lifecycle._interrupted)
    names = [
        ENGINE,
        "doglyad-dgx-vllm_medgemma_15_4b-1",
        "doglyad-dgx-vllm_medgemma_27b-1",
        "doglyad-dgx-backend_inference-1",
    ]
    states = {name: lifecycle._inspect(name) for name in names}
    original = states[ENGINE]
    assert original["State"]["Running"]
    safe = {
        name: {
            "id": value["Id"],
            "image": value["Image"],
            "cmd": value["Config"]["Cmd"],
            "started_at": value["State"]["StartedAt"],
        }
        for name, value in states.items()
    }
    (directory / "runtime-before.json").write_text(json.dumps(safe, indent=2) + "\n")
    for name in names[:3]:
        lifecycle._idle(name)
    stage_name = "setup"
    try:
        subprocess.run(
            ["docker", "stop", "-t", "30", ENGINE],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
        )
        lifecycle._event("original_engine_stopped")
        memory = {
            line.split(":")[0]: int(line.split()[1])
            for line in Path("/proc/meminfo").read_text().splitlines()
        }
        assert memory["MemAvailable"] > 22 * 1024 * 1024
        for stage in plan["stages"]:
            stage_name = stage["name"]
            cases = json.loads((DIRECTORY / stage["cases"]).read_text())
            if stage.get("greedy_only"):
                cases = [case for case in cases if "greedy" in case["id"]]
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
                "--mount",
                f"type=bind,src={DIRECTORY},dst=/evaluation,readonly",
                "-e",
                "HF_HUB_OFFLINE=1",
                "-e",
                "TRANSFORMERS_OFFLINE=1",
                "-e",
                "HF_HUB_DISABLE_PROGRESS_BARS=1",
                "-e",
                "VLLM_NO_USAGE_STATS=1",
            ]
            if stage.get("python_path"):
                command += ["-e", "PYTHONPATH=" + stage["python_path"]]
            if stage["kind"] == "vllm":
                engine_args = list(original["Config"]["Cmd"])
                if stage.get("model"):
                    engine_args[0] = stage["model"]
                    engine_args[engine_args.index("--served-model-name") + 1] = stage[
                        "model"
                    ]
                    engine_args[engine_args.index("--revision") + 1] = stage["revision"]
                    # Qwen text-only control has no image encoder or multimodal limits.
                    index = engine_args.index("--limit-mm-per-prompt")
                    del engine_args[index : index + 2]
                command += [original["Image"], *engine_args]
                subprocess.run(
                    command, check=True, timeout=60, stdout=subprocess.DEVNULL
                )
                lifecycle._event("starting", stage=stage_name)
                lifecycle._health(TEMPORARY, 900)
                lifecycle._run_probe(
                    TEMPORARY,
                    "../../runtime-comparison/probe_vllm.py",
                    cases,
                    stage_name + ".jsonl",
                    3000,
                )
            else:
                reference_path = DIRECTORY / stage["reference"]
                reference = {
                    row["id"]: row
                    for row in (
                        json.loads(line)
                        for line in reference_path.read_text().splitlines()
                    )
                    if "id" in row
                }
                for case in cases:
                    case["prompt_token_ids"] = reference[case["id"]]["prompt_token_ids"]
                command += ["--entrypoint", "sleep", original["Image"], "3600"]
                subprocess.run(
                    command, check=True, timeout=60, stdout=subprocess.DEVNULL
                )
                lifecycle._event("starting", stage=stage_name)
                lifecycle._run_probe(
                    TEMPORARY,
                    "../probe_hf_trials.py",
                    {
                        "cases": cases,
                        "snapshot": stage["snapshot"],
                        "family": stage["family"],
                        "sampling_overrides": stage.get("sampling_overrides", {}),
                    },
                    stage_name + ".jsonl",
                    3000,
                )
            _remove_temporary(directory, stage_name)
    finally:
        _remove_temporary(directory, stage_name)
        subprocess.run(
            ["docker", "start", ENGINE],
            check=True,
            timeout=60,
            stdout=subprocess.DEVNULL,
        )
        lifecycle._event("restoring_original")
        lifecycle._health(ENGINE, 900)
        restored = lifecycle._inspect(ENGINE)
        assert (
            restored["Id"] == original["Id"]
            and restored["Config"]["Cmd"] == original["Config"]["Cmd"]
        )
        after = {}
        for name in names:
            current = lifecycle._inspect(name)
            if name != ENGINE:
                assert (
                    current["State"]["StartedAt"] == states[name]["State"]["StartedAt"]
                )
            if name in names[:3]:
                lifecycle._idle(name)
            after[name] = {
                "id": current["Id"],
                "image": current["Image"],
                "started_at": current["State"]["StartedAt"],
                "running": current["State"]["Running"],
                "health": current["State"].get("Health", {}).get("Status"),
            }
        (directory / "runtime-after.json").write_text(
            json.dumps(after, indent=2) + "\n"
        )
        lifecycle._event("restoration_verified")
    lifecycle._event("finished")


if __name__ == "__main__":
    main()
