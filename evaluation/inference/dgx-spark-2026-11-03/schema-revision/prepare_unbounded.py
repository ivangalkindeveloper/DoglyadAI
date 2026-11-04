"""Diagnostic only: remove grammar caps while keeping every prompt byte fixed."""

from __future__ import annotations

import copy
import json
from pathlib import Path

DIRECTORY = Path(__file__).resolve().parent


def remove_limits(value: object) -> None:
    if isinstance(value, dict):
        value.pop("maxLength", None)
        for item in value.values():
            remove_limits(item)
    elif isinstance(value, list):
        for item in value:
            remove_limits(item)


def main() -> None:
    cases = json.loads((DIRECTORY / "working-cases.json").read_text())
    for case in cases:
        case["actual_main_request"] = False
        case["diagnostic"] = "Only grammar maxLength removed; prompt, embedded schema text and sampling unchanged."
        remove_limits(case["schema"])
        case["payload"]["response_format"]["json_schema"]["schema"] = copy.deepcopy(case["schema"])
    (DIRECTORY / "unbounded-grammar-cases.json").write_text(
        json.dumps(cases, ensure_ascii=False, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
