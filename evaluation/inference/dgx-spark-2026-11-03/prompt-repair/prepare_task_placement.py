"""Test explicit user-task placement and conventional report field names."""

from __future__ import annotations

import copy
import json
from pathlib import Path

DIRECTORY = Path(__file__).resolve().parent


def main() -> None:
    variants = {}
    for name, source in (("full-task-last", "uncapped"), ("concise-task-last", "concise-ru"), ("audit-task-last", "audit-text")):
        cases = json.loads((DIRECTORY / f"{source}-cases.json").read_text())
        for case in cases:
            system = case["payload"]["messages"][0]["content"]
            data = case["payload"]["messages"][1]["content"]
            case["payload"]["messages"] = [
                {"role": "system", "content": "Ты — медицинский ассистент. Выполняй задание пользователя по предоставленным данным."},
                {"role": "user", "content": "ИСХОДНЫЕ ДАННЫЕ:\n" + data + "\nЗАДАНИЕ:\n" + system},
            ]
        variants[name] = cases
    aliases = {"description": "findings", "conclusion": "impression", "descriptionRemarks": "input_issues"}
    cases = json.loads((DIRECTORY / "concise-ru-cases.json").read_text())
    for case in cases:
        schema = case["schema"]
        schema["properties"] = {aliases.get(key, key): value for key, value in schema["properties"].items()}
        schema["required"] = [aliases.get(key, key) for key in schema["required"]]
        prompt = case["payload"]["messages"][0]["content"].split("JSON Schema:\n")[0]
        for old in sorted(aliases, key=len, reverse=True):
            prompt = prompt.replace(old, aliases[old])
        case["payload"]["messages"][0]["content"] = prompt + "JSON Schema:\n" + json.dumps(schema, ensure_ascii=False) + "\n"
        case["payload"]["response_format"]["json_schema"]["schema"] = copy.deepcopy(schema)
        case["output_aliases"] = {value: key for key, value in aliases.items()}
    variants["alias-fields"] = cases
    for name, cases in variants.items():
        (DIRECTORY / f"{name}-cases.json").write_text(json.dumps(cases, ensure_ascii=False, indent=2) + "\n")
    (DIRECTORY / "placement-manifest.json").write_text(json.dumps(list(variants), indent=2) + "\n")


if __name__ == "__main__":
    main()
