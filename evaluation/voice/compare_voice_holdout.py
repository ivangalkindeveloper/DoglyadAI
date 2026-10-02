from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.score_candidate import FIELDS


def compare(original: dict[str, Any], holdout: dict[str, Any]) -> dict[str, Any]:
    if original.get("audioMode") != "extended-v2" or holdout.get("audioMode") != "voice-holdout":
        raise ValueError("Expected original v2 and alternate-voice holdout summaries")
    if original.get("audioVariant") != holdout.get("audioVariant"):
        raise ValueError("Audio variants differ")
    if original.get("regressionSha256") != holdout.get("regressionSha256"):
        raise ValueError("Regression corpora differ")
    manifests = {}
    for name, summary in (("extended-v2", original), ("voice-holdout", holdout)):
        path = AUDIO_OUTPUT_DIR / name / "manifest.json"
        if file_sha256(path) != summary.get("audioManifestSha256"):
            raise ValueError(f"{name} summary uses another audio manifest")
        manifests[name] = json.loads(path.read_text(encoding="utf-8"))
    source_entries = {entry["caseId"]: entry for entry in manifests["extended-v2"]["entries"]}
    target_entries = {entry["caseId"]: entry for entry in manifests["voice-holdout"]["entries"]}
    original_rows = {row["id"]: row for row in original["scoredCases"]}
    holdout_rows = {row["id"]: row for row in holdout["scoredCases"]}
    if len(original_rows) != len(original["scoredCases"]) or len(holdout_rows) != len(holdout["scoredCases"]):
        raise ValueError("Duplicate case IDs")
    if holdout_rows.keys() != target_entries.keys() or not holdout_rows.keys() <= original_rows.keys():
        raise ValueError("Holdout case IDs differ from the manifest or original run")
    for case_id, entry in target_entries.items():
        source = source_entries.get(case_id)
        if source is None or source["ttsText"] != entry["ttsText"] or source["locale"] != entry["locale"]:
            raise ValueError(f"Holdout script differs from original: {case_id}")

    by_locale = {}
    for locale in ("en", "ru"):
        pairs = [
            (original_rows[id], holdout_rows[id]) for id in sorted(holdout_rows) if holdout_rows[id]["locale"] == locale
        ]
        fields = {field: {"originalOnly": 0, "holdoutOnly": 0, "bothCorrect": 0, "bothWrong": 0} for field in FIELDS}
        original_exact = holdout_exact = original_unnoticed = holdout_unnoticed = 0
        original_wer = holdout_wer = 0.0
        for old, new in pairs:
            if old["locale"] != new["locale"] or old["examinationTypeId"] != new["examinationTypeId"]:
                raise ValueError(f"Case metadata differs: {old['id']}")
            if old["speechAnalyzerParseStatus"] != "ok" or new["speechAnalyzerParseStatus"] != "ok":
                raise ValueError(f"Incomplete parse: {old['id']}")
            a, b = old["speechAnalyzer"], new["speechAnalyzer"]
            original_exact += a["equivalentExactCase"]
            holdout_exact += b["equivalentExactCase"]
            original_unnoticed += len(a["equivalentUnnoticedWrongFields"])
            holdout_unnoticed += len(b["equivalentUnnoticedWrongFields"])
            original_wer += old["speechAnalyzerCorrectedWER"]
            holdout_wer += new["speechAnalyzerCorrectedWER"]
            for field in FIELDS:
                first, second = a["equivalentMatches"][field], b["equivalentMatches"][field]
                category = (
                    "bothCorrect"
                    if first and second
                    else "originalOnly"
                    if first
                    else "holdoutOnly"
                    if second
                    else "bothWrong"
                )
                fields[field][category] += 1
        by_locale[locale] = {
            "cases": len(pairs),
            "originalEquivalentExact": original_exact,
            "holdoutEquivalentExact": holdout_exact,
            "originalEquivalentUnnoticedWrongFields": original_unnoticed,
            "holdoutEquivalentUnnoticedWrongFields": holdout_unnoticed,
            "originalMeanWER": original_wer / len(pairs) if pairs else None,
            "holdoutMeanWER": holdout_wer / len(pairs) if pairs else None,
            "fields": fields,
        }
    return {
        "schemaVersion": 1,
        "audioVariant": original["audioVariant"],
        "regressionSha256": original["regressionSha256"],
        "originalAudioManifestSha256": original["audioManifestSha256"],
        "holdoutAudioManifestSha256": holdout["audioManifestSha256"],
        "byLocale": by_locale,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare frozen scripts spoken by two pairs of voices")
    parser.add_argument("original", type=Path)
    parser.add_argument("holdout", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = compare(
        json.loads(args.original.read_text(encoding="utf-8")),
        json.loads(args.holdout.read_text(encoding="utf-8")),
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Alternate-voice holdout on iPhone",
        "",
        "The same intended TTS scripts and form values use different system voices. This checks voice variation, not new wording or natural physician speech.",
        "",
        "| Locale | Paired cases | Original exact | Other voice exact | Original WER | Other voice WER | Unnoticed wrong fields, original / other |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for locale, group in result["byLocale"].items():
        lines.append(
            f"| {locale} | {group['cases']} | {group['originalEquivalentExact']} | "
            f"{group['holdoutEquivalentExact']} | {group['originalMeanWER']:.3f} | "
            f"{group['holdoutMeanWER']:.3f} | "
            f"{group['originalEquivalentUnnoticedWrongFields']} / {group['holdoutEquivalentUnnoticedWrongFields']} |"
        )
    for locale, group in result["byLocale"].items():
        lines.extend(
            [
                "",
                f"## {locale} field changes",
                "",
                "| Field | Original only correct | Other voice only correct | Both wrong |",
                "|---|---:|---:|---:|",
            ]
        )
        for field, counts in group["fields"].items():
            lines.append(f"| {field} | {counts['originalOnly']} | {counts['holdoutOnly']} | {counts['bothWrong']} |")
    args.output.with_suffix(".md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(args.output.with_suffix(".md"))


if __name__ == "__main__":
    main()
