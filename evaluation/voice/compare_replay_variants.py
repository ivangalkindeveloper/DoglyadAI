from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.score_candidate import FIELDS


def compare(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    if left.get("inputSource") != "asrReplay" or right.get("inputSource") != "asrReplay":
        raise ValueError("Both summaries must be fixed ASR replays")
    if left.get("audioMode") != "extended-v2" or right.get("audioMode") != "extended-v2":
        raise ValueError("Both summaries must use audio v2")
    for key in ("regressionSha256", "audioManifestSha256", "audioVariant"):
        if left.get(key) != right.get(key):
            raise ValueError(f"Replays disagree on {key}")
    left_rows = {row["id"]: row for row in left["scoredCases"]}
    right_rows = {row["id"]: row for row in right["scoredCases"]}
    if len(left_rows) != len(left["scoredCases"]) or len(right_rows) != len(right["scoredCases"]):
        raise ValueError("Duplicate case IDs")
    if left_rows.keys() != right_rows.keys():
        raise ValueError("Replays contain different cases")
    by_locale = {}
    for locale in ("en", "ru"):
        pairs = [(left_rows[id], right_rows[id]) for id in sorted(left_rows) if left_rows[id]["locale"] == locale]
        fields = {field: {"leftOnly": 0, "rightOnly": 0, "bothCorrect": 0, "bothWrong": 0} for field in FIELDS}
        left_exact = right_exact = left_unnoticed = right_unnoticed = 0
        for old, new in pairs:
            if old["locale"] != new["locale"] or old["examinationTypeId"] != new["examinationTypeId"]:
                raise ValueError(f"Case metadata differs: {old['id']}")
            if old["goldTextStatus"] != "ok" or new["goldTextStatus"] != "ok":
                raise ValueError(f"Incomplete ASR replay: {old['id']}")
            a, b = old["goldText"], new["goldText"]
            left_exact += a["equivalentExactCase"]
            right_exact += b["equivalentExactCase"]
            left_unnoticed += len(a["equivalentUnnoticedWrongFields"])
            right_unnoticed += len(b["equivalentUnnoticedWrongFields"])
            for field in FIELDS:
                first, second = a["equivalentMatches"][field], b["equivalentMatches"][field]
                category = (
                    "bothCorrect"
                    if first and second
                    else "leftOnly"
                    if first
                    else "rightOnly"
                    if second
                    else "bothWrong"
                )
                fields[field][category] += 1
        by_locale[locale] = {
            "cases": len(pairs),
            "leftEquivalentExact": left_exact,
            "rightEquivalentExact": right_exact,
            "leftEquivalentUnnoticedWrongFields": left_unnoticed,
            "rightEquivalentUnnoticedWrongFields": right_unnoticed,
            "fields": fields,
        }
    return {
        "schemaVersion": 1,
        "audioVariant": left["audioVariant"],
        "audioManifestSha256": left["audioManifestSha256"],
        "leftASRReportSha256": left["asrReportSha256"],
        "rightASRReportSha256": right["asrReportSha256"],
        "byLocale": by_locale,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare two fixed ASR replays with the same iOS parser")
    parser.add_argument("left", type=Path)
    parser.add_argument("right", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = compare(
        json.loads(args.left.read_text(encoding="utf-8")),
        json.loads(args.right.read_text(encoding="utf-8")),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Fixed ASR replay comparison", "", "Left and right use the same audio corpus and iOS parser.", ""]
    for locale, group in result["byLocale"].items():
        lines.extend(
            [
                f"## {locale}",
                "",
                f"Full forms: left {group['leftEquivalentExact']}/{group['cases']}; "
                f"right {group['rightEquivalentExact']}/{group['cases']}.",
                f"Wrong proposed fields without a warning: left {group['leftEquivalentUnnoticedWrongFields']}; "
                f"right {group['rightEquivalentUnnoticedWrongFields']}.",
                "",
                "| Field | Left only correct | Right only correct | Both wrong |",
                "|---|---:|---:|---:|",
            ]
        )
        for field, counts in group["fields"].items():
            lines.append(f"| {field} | {counts['leftOnly']} | {counts['rightOnly']} | {counts['bothWrong']} |")
        lines.append("")
    args.output.with_suffix(".md").write_text("\n".join(lines), encoding="utf-8")
    print(args.output.with_suffix(".md"))


if __name__ == "__main__":
    main()
