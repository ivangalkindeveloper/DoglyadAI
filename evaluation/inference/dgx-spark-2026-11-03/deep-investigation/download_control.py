"""Download the pinned public BF16 control model; do not load it onto the GPU."""

import json
from pathlib import Path

from huggingface_hub import snapshot_download

MODEL = "Qwen/Qwen3-4B-Instruct-2507"
REVISION = "cdbee75f17c01a7cc42f958dc650907174af0554"

snapshot = Path(
    snapshot_download(
        MODEL,
        revision=REVISION,
        token=False,
        max_workers=2,
        allow_patterns=[
            "*.json",
            "*.safetensors",
            "*.jinja",
            "*.txt",
            "LICENSE",
            "README.md",
        ],
    )
)
manifest = {
    "model": MODEL,
    "revision": REVISION,
    "snapshot": str(snapshot),
    "files": [
        {"name": p.name, "bytes": p.stat().st_size}
        for p in sorted(snapshot.iterdir())
        if p.is_file()
    ],
}
Path("/evaluation/qwen-download.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(manifest), flush=True)
