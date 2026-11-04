"""Match the existing vLLM/SGLang whitespace policy in the experimental venv."""

import difflib
import hashlib
import json
from pathlib import Path

root = Path("/survey")
path = root / "lmdeploy-venv/lib/python3.12/site-packages/lmdeploy/_guided_decoding.py"
original = path.read_text()
needle = "return compiler.compile_json_schema(source)"
assert original.count(needle) == 1
modified = original.replace(
    needle, "return compiler.compile_json_schema(source, any_whitespace=False)"
)
(root / "lmdeploy-grammar.patch").write_text(
    "".join(
        difflib.unified_diff(
            original.splitlines(True),
            modified.splitlines(True),
            fromfile="upstream/_guided_decoding.py",
            tofile="experimental/_guided_decoding.py",
        )
    )
)
(root / "lmdeploy-grammar-patch.json").write_text(
    json.dumps(
        {
            "original_sha256": hashlib.sha256(original.encode()).hexdigest(),
            "modified_sha256": hashlib.sha256(modified.encode()).hexdigest(),
            "scope": "JSON whitespace policy only; schema and token limit unchanged",
        },
        indent=2,
    )
    + "\n"
)
path.write_text(modified)
