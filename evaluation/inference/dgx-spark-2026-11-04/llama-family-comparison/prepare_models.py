"""Convert pinned local checkpoints to BF16 GGUF without GPU execution."""

from __future__ import annotations

import fcntl
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

from run_trial import NAMES, _activity, _inspect, _snapshot

ROOT = Path(__file__).resolve().parent


def main() -> None:
    assert not (ROOT / "runtime-initial.json").exists(), "Use a new trial directory"
    provenance = json.loads((ROOT / "provenance.json").read_text())
    assets = Path(provenance["assets_directory"])
    with (assets / "engine.lock").open("a") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert shutil.disk_usage(ROOT).free > 150 * 1024**3
        commit = subprocess.check_output(
            ["git", "-C", str(assets / "llama.cpp"), "rev-parse", "HEAD"], text=True
        ).strip()
        assert commit == provenance["llama_commit"], commit
        initial = _snapshot()
        assert initial["memory"]["MemAvailable"] > 16 * 1024**2
        for index, name in enumerate(NAMES):
            assert initial[name]["running"]
            if index < 3:
                assert initial[name]["health"] == "healthy"
                assert initial[name]["image"] == provenance["vllm_image"]
            initial[name]["restart_policy"] = _inspect(name)["HostConfig"][
                "RestartPolicy"
            ]
        (ROOT / "runtime-initial.json").write_text(json.dumps(initial, indent=2) + "\n")
        (ROOT / "activity-initial.json").write_text(
            json.dumps(_activity(), indent=2) + "\n"
        )
        receipts = {}
        for key, index in (("15-4b", 1), ("27b", 2)):
            model = (
                "google/medgemma-1.5-4b-it" if index == 1 else "google/medgemma-27b-it"
            )
            command = initial[NAMES[index]]["command"]
            revision = command[command.index("--revision") + 1]
            assert command[0] == model
            assert revision == provenance["model_revisions"][model]
            snapshot = f"/root/.cache/huggingface/hub/models--{model.replace('/', '--')}/snapshots/{revision}"
            for is_projector in (False, True):
                stem = f"medgemma-{key}-{'mmproj-' if is_projector else ''}bf16"
                output = ROOT / f"{stem}.gguf"
                assert not output.exists(), output
                args = [
                    "docker",
                    "run",
                    "--rm",
                    "--name",
                    f"doglyad-family-convert-{stem}",
                    "--network",
                    "none",
                    "--cpus",
                    "4",
                    "--memory",
                    "12g",
                    "--memory-swap",
                    "12g",
                    "--volumes-from",
                    NAMES[index] + ":ro",
                    "--mount",
                    f"type=bind,src={ROOT},dst=/survey",
                    "--mount",
                    f"type=bind,src={assets},dst=/assets,readonly",
                    "--env",
                    "HF_HUB_OFFLINE=1",
                    "--env",
                    "TRANSFORMERS_OFFLINE=1",
                    "--env",
                    "PYTHONPATH=/assets/llama.cpp/gguf-py",
                    "--entrypoint",
                    "python3",
                    provenance["vllm_image"],
                    "/assets/llama.cpp/convert_hf_to_gguf.py",
                    snapshot,
                    "--outfile",
                    f"/survey/{stem}.partial.gguf",
                    "--outtype",
                    "bf16",
                    "--use-temp-file",
                ]
                if is_projector:
                    args.append("--mmproj")
                (ROOT / f"{stem}-conversion-command.json").write_text(
                    json.dumps(args, indent=2) + "\n"
                )
                print(
                    json.dumps({"event": "conversion_started", "file": output.name}),
                    flush=True,
                )
                with (ROOT / f"{stem}-conversion.log").open("x") as log:
                    subprocess.run(
                        args, stdout=log, stderr=subprocess.STDOUT, check=True
                    )
                partial = ROOT / f"{stem}.partial.gguf"
                with partial.open("rb") as data:
                    digest = hashlib.file_digest(data, "sha256").hexdigest()
                partial.rename(output)
                receipts[output.name] = {
                    "bytes": output.stat().st_size,
                    "sha256": digest,
                    "source_model": model,
                    "revision": revision,
                    "outtype": "bf16",
                }
                (ROOT / "gguf-artifacts.json").write_text(
                    json.dumps(receipts, indent=2) + "\n"
                )
                print(
                    json.dumps({"event": "conversion_completed", "file": output.name}),
                    flush=True,
                )


if __name__ == "__main__":
    main()
