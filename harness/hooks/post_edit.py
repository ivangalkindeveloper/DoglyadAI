"""Format edited Swift sources, then check architecture in the edited files."""

from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from harness.checks.architecture import is_source  # noqa: E402


def edited_paths(payload: dict) -> list[Path]:
    tool_input = payload.get("tool_input", {})
    if isinstance(tool_input, str):
        patch, paths = tool_input, []
    elif isinstance(tool_input, dict):
        patch = tool_input.get("patch", tool_input.get("input", ""))
        paths = [tool_input.get("file_path", ""), tool_input.get("path", "")]
    else:
        return []
    if isinstance(patch, str):
        paths.extend(
            re.findall(
                r"^\*\*\* (?:Add File|Update File|Move to): (.+)$", patch, re.MULTILINE
            )
        )
    cwd = Path(payload.get("cwd", ROOT))
    if not cwd.is_absolute():
        cwd = ROOT / cwd
    return sorted(
        {(cwd / value).resolve() for value in paths if isinstance(value, str) and value}
    )


def main() -> int:
    try:
        payload = json.load(sys.stdin)
        paths = [
            path for path in edited_paths(payload) if is_source(path) and path.is_file()
        ]
        if not paths:
            return 0
        if any(path.suffix == ".swift" for path in paths):
            completed = subprocess.run(
                ["make", "format-ios"], cwd=ROOT, timeout=170, check=False
            )
            if completed.returncode:
                print(
                    "iOS formatting failed; run make format-ios and inspect its output.",
                    file=sys.stderr,
                )
                return 2
        completed = subprocess.run(
            [
                sys.executable,
                str(ROOT / "harness/checks/architecture.py"),
                *map(str, paths),
            ],
            cwd=ROOT,
            timeout=160,
            check=False,
            capture_output=True,
            text=True,
        )
        if completed.returncode:
            print(completed.stdout + completed.stderr, file=sys.stderr, end="")
            print(
                "Fix the reported architecture violations, then rerun make check-architecture.",
                file=sys.stderr,
            )
            return 2
        return 0
    except (
        ValueError,
        TypeError,
        AttributeError,
        OSError,
        subprocess.TimeoutExpired,
    ) as error:
        print(f"Post-edit hook failed: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
