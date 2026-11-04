"""Summarize structural validity separately from synthetic-case expectations."""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+")
    args = parser.parse_args()
    groups = defaultdict(list)
    for filename in args.files:
        for line in Path(filename).read_text().splitlines():
            result = json.loads(line)
            key = (
                result["model"],
                result["kind"],
                result["variant"],
                result.get("prompt_style", "original"),
                result["mode"],
            )
            groups[key].append(result)
    for key, rows in groups.items():
        output = {
            "model": key[0],
            "case": key[1],
            "format": key[2],
            "prompt": key[3],
            "mode": key[4],
            "count": len(rows),
            "schema_valid": sum(r.get("schema_valid", False) for r in rows),
            "main_valid": sum(r.get("main_valid", False) for r in rows),
            "length_stops": sum(r.get("finish") == "length" for r in rows),
            "active_after": max(r.get("active_after", 0) for r in rows),
        }
        if key[1] == "dictation":
            expected = {
                "patient_name",
                "patient_complaints",
                "patient_height_cm",
                "patient_weight_kg",
            }
            output["all_expected_fields_present"] = sum(
                expected
                <= {
                    p["fieldId"]
                    for p in r.get("validated_value", {}).get("proposals", [])
                }
                for r in rows
            )
            output["unexpected_fields"] = sorted(
                {
                    p["fieldId"]
                    for r in rows
                    for p in r.get("validated_value", {}).get("proposals", [])
                }
                - expected
            )
        if key[1] == "conflict":
            # Presence alone does not establish that the remark identifies the conflict.
            output["nonempty_remark"] = sum(
                bool(json.loads(r["text"]).get("descriptionRemarks"))
                for r in rows
                if r.get("schema_valid")
            )
        print(json.dumps(output, ensure_ascii=False))


if __name__ == "__main__":
    main()
