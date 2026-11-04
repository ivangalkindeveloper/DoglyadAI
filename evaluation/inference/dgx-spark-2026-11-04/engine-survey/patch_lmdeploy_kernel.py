"""Apply a documented experimental SM121 tile change to the isolated LMDeploy venv."""

import difflib
import hashlib
import json
from pathlib import Path

root = Path("/survey")
path = (
    root
    / "lmdeploy-venv/lib/python3.12/site-packages/lmdeploy/pytorch/kernels/cuda/flashattention.py"
)
original = path.read_text()
needle = "def _kernel_meta_sm12x(BLOCK_DK: int, shared_kv: bool):\n"
assert original.count(needle) == 1
replacement = needle + (
    "    # Experimental DGX Spark tile: avoid exceeding SM121 shared memory.\n"
    "    if BLOCK_DK == 256 and not shared_kv:\n"
    "        return 32, 32, 4, 1\n"
)
assert "Experimental DGX Spark tile" not in original
modified = original.replace(needle, replacement)
(root / "lmdeploy-kernel-sm121.patch").write_text(
    "".join(
        difflib.unified_diff(
            original.splitlines(True),
            modified.splitlines(True),
            fromfile="upstream/flashattention.py",
            tofile="experimental/flashattention.py",
        )
    )
)
(root / "lmdeploy-kernel-patch.json").write_text(
    json.dumps(
        {
            "original_sha256": hashlib.sha256(original.encode()).hexdigest(),
            "modified_sha256": hashlib.sha256(modified.encode()).hexdigest(),
            "scope": "isolated experimental venv only; BF16 weights unchanged",
        },
        indent=2,
    )
    + "\n"
)
path.write_text(modified)
