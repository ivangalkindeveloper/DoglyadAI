"""Freeze prior synthetic inputs for paired grammar/runtime comparisons."""

from __future__ import annotations

import json
from pathlib import Path


def main() -> None:
    directory = Path(__file__).parent
    sources = [
        directory.parent / "formatting-historical-control.jsonl",
        directory.parent / "formatting-bounded8-validation.jsonl",
    ]
    selected = {}
    for source in sources:
        for line in source.read_text().splitlines():
            row = json.loads(line)
            if row["model"] != "google/medgemma-4b-it" or row["seed"] != 0:
                continue
            if row["kind"] not in selected:
                selected[row["kind"]] = (row, source.name)
    cases = []
    for kind in ("historical", "report", "conflict", "dictation"):
        row, source_name = selected[kind]
        settings = [("greedy", 0, 0)]
        if kind != "dictation":
            settings += [("sample", seed, 0.3) for seed in (0, 42, 123)]
        for mode, seed, temperature in settings:
            payload = dict(row["payload"])
            payload.update(
                temperature=temperature,
                seed=seed,
                top_p=1.0,
                top_k=-1,
                repetition_penalty=1.0,
                stream=True,
                response_format={
                    "type": "json_schema",
                    "json_schema": {
                        "name": "response",
                        "schema": row["schema"],
                        "strict": True,
                    },
                },
            )
            case = {key: row[key] for key in ("kind", "model", "body", "schema")}
            if "transcript" in row:
                case["transcript"] = row["transcript"]
            case.update(id=f"{kind}-{mode}-{seed}", payload=payload, source=source_name)
            cases.append(case)
    with (directory / "cases.json").open("x") as output:
        json.dump(cases, output, ensure_ascii=False, indent=2)
    print(f"Frozen {len(cases)} cases")


if __name__ == "__main__":
    main()
