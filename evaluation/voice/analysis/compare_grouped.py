from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.scoring.grouped_confidence import grouped_confidence


def compare_grouped(
    path: Path, left: str, right: str, *, locale: str, modes: list[str], variant: str = "all"
) -> dict[str, Any]:
    """Compare recognizer/method pairs on exactly the same non-terminology cases."""
    candidates: dict[str, dict[str, Any]] = {left: {}, right: {}}
    with path.open(encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            if row["stage"] != "extraction" or row["locale"] != locale or row["mode"] not in modes:
                continue
            if variant != "all" and row["variant"] != variant:
                continue
            key = row["recognizer"] + "/" + row["method"]
            if key in candidates:
                if row["id"] in candidates[key]:
                    raise ValueError("Duplicate paired result")
                candidates[key][row["id"]] = row
    a, b = candidates[left], candidates[right]
    if not a or a.keys() != b.keys() or "terminology" in modes or left == right:
        raise ValueError("Choose distinct candidates with the same nonempty clinical case set")
    cohorts = {
        (row.get("sourceKind"), row.get("recordingMode"), row.get("split")) for row in [*a.values(), *b.values()]
    }
    if len(cohorts) != 1:
        raise ValueError("Do not pool different source kinds, recording modes or splits")
    differences = []
    for key, first in a.items():
        second = b[key]
        if first.get("clusterId") != second.get("clusterId"):
            raise ValueError("Paired results use different clusters")
        if any(
            first.get(field) != second.get(field)
            for field in ("audioSha256", "goldSha256", "expectedFieldIds", "variant", "mode")
        ):
            raise ValueError("Paired results use different audio, gold or conditions")
        differences.append(
            {
                "clusterId": first.get("clusterId"),
                "numerator": int(first["status"] == "ok" and first["score"]["equivalentExactCase"])
                - int(second["status"] == "ok" and second["score"]["equivalentExactCase"]),
                "denominator": 1,
            }
        )
    return {
        "sourceSha256": file_sha256(path),
        "left": left,
        "right": right,
        "locale": locale,
        "modes": modes,
        "variant": variant,
        "metric": "normalizedTextExactFormRateDifference",
        "cases": len(a),
        "confidence": grouped_confidence(differences),
        "note": "Textual agreement, not adjudicated clinical correctness. A cluster joins related stories, translations, augmentations and shared human speakers. No CI for unannotated legacy groups.",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Paired comparison with explicit independent clusters")
    parser.add_argument("scores", type=Path)
    parser.add_argument("--left", required=True)
    parser.add_argument("--right", required=True)
    parser.add_argument("--locale", choices=("ru", "en"), required=True)
    parser.add_argument("--modes", nargs="+", required=True)
    parser.add_argument("--variant", default="all")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = compare_grouped(
        args.scores, args.left, args.right, locale=args.locale, modes=args.modes, variant=args.variant
    )
    with args.output.open("x", encoding="utf-8") as destination:
        destination.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
