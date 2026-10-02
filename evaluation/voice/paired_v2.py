from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.score_ios import SUPPORTED_FIELDS


def _rows(summary: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = summary["scoredCases"]
    by_id = {row["id"]: row for row in rows}
    if len(by_id) != len(rows):
        raise ValueError("Duplicate iOS case IDs")
    return by_id


def compare_v2(baseline_path: Path, candidate_path: Path, output_path: Path) -> dict[str, Any]:
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    if baseline.get("audioMode") != candidate.get("audioMode") or candidate.get("audioMode") != "extended-v2":
        raise ValueError("Both reports must use the v2 audio corpus")
    variant = candidate.get("audioVariant")
    if variant not in ("clean", "noisy") or baseline.get("audioVariant") != variant:
        raise ValueError("Baseline and candidate audio variants differ")
    for key in ("audioManifestSha256", "regressionSha256"):
        if baseline.get(key) != candidate.get(key):
            raise ValueError(f"Baseline and candidate use different {key}")
    if file_sha256(AUDIO_OUTPUT_DIR / "extended-v2" / "manifest.json") != candidate["audioManifestSha256"]:
        raise ValueError("Paired reports use a stale v2 audio manifest")
    if baseline.get("platform") != "iOS" or candidate.get("platform") != "iOS":
        raise ValueError("Both reports must come from a physical iOS device")
    old_rows = _rows(baseline)
    new_rows = _rows(candidate)
    if set(old_rows) != set(new_rows):
        raise ValueError("Baseline and candidate case IDs differ")

    by_locale: dict[str, Any] = {}
    for locale in ("en", "ru"):
        pairs = []
        for case_id, old in old_rows.items():
            if old["locale"] != locale:
                continue
            new = new_rows[case_id]
            if new["locale"] != locale or new["examinationTypeId"] != old["examinationTypeId"]:
                raise ValueError(f"Case metadata differs for {case_id}")
            pairs.append((old, new))
        complete = [
            (old, new)
            for old, new in pairs
            if old["asrStatus"] == old["recognizedTextStatus"] == "ok"
            and new["speechAnalyzerASRStatus"] == new["speechAnalyzerParseStatus"] == "ok"
        ]
        by_locale[locale] = {
            "cases": len(pairs),
            "completedPairs": len(complete),
            "baselineCommonFieldsExact": sum(old["recognizedText"]["exactCase"] for old, _ in complete),
            "candidateCommonFieldsExact": sum(
                all(new["speechAnalyzer"]["matches"][field] for field in SUPPORTED_FIELDS) for _, new in complete
            ),
            "candidateFullFormExact": sum(new["speechAnalyzer"]["exactCase"] for _, new in complete),
            "candidateEquivalentFullFormExact": sum(
                new["speechAnalyzer"]["equivalentExactCase"] for _, new in complete
            ),
            "baselineMeanWER": sum(old["correctedWER"] for old, _ in complete) / len(complete) if complete else None,
            "baselineMeanLiteralWER": sum(old["correctedLiteralWER"] for old, _ in complete) / len(complete)
            if complete
            else None,
            "candidateMeanWER": sum(new["speechAnalyzerCorrectedWER"] for _, new in complete) / len(complete)
            if complete
            else None,
            "candidateMeanLiteralWER": sum(new["speechAnalyzerCorrectedLiteralWER"] for _, new in complete)
            / len(complete)
            if complete
            else None,
            "candidateUnnoticedWrongFields": sum(
                len(new["speechAnalyzer"]["unnoticedWrongFields"]) for _, new in complete
            ),
            "candidateEquivalentUnnoticedWrongFields": sum(
                len(new["speechAnalyzer"]["equivalentUnnoticedWrongFields"]) for _, new in complete
            ),
        }

    report = {
        "schemaVersion": 1,
        "audioMode": "extended-v2",
        "audioVariant": variant,
        "audioManifestSha256": candidate["audioManifestSha256"],
        "regressionSha256": candidate["regressionSha256"],
        "baselineSummarySha256": file_sha256(baseline_path),
        "candidateSummarySha256": file_sha256(candidate_path),
        "byLocale": by_locale,
        "pairedComplete": all(group["completedPairs"] == group["cases"] for group in by_locale.values()),
        "releaseGate": (
            all(
                group["cases"] == group["completedPairs"] == 124
                and group["candidateEquivalentFullFormExact"] >= (118 if variant == "clean" else 106)
                and group["candidateEquivalentUnnoticedWrongFields"] == 0
                for group in by_locale.values()
            )
            if all(group["cases"] == 124 for group in by_locale.values())
            else None
        ),
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = [
        "# Paired iPhone voice evaluation, audio v2",
        "",
        "WER uses the intended TTS script and accepts written digits and unit abbreviations as equivalents of spoken forms. Literal WER is retained in JSON. The script is not a human-audited transcription of the audio.",
        "",
        "The release gate uses equivalent full forms and equivalent wrong fields without warnings. Strict string equality is retained as a diagnostic.",
        "",
        "Baseline does not support the examination number. The common-field comparison uses its seven fields; the release gate uses all eight candidate fields.",
        "",
        "| Locale | Paired cases | Baseline 7 fields | Candidate 7 fields | Candidate strict 8 | Candidate equivalent 8 | WER baseline | WER candidate | Candidate equivalent wrong fields without warning |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for locale, group in by_locale.items():
        count = group["completedPairs"]
        before = f"{group['baselineMeanWER']:.3f}" if count else "n/a"
        after = f"{group['candidateMeanWER']:.3f}" if count else "n/a"
        lines.append(
            f"| {locale} | {count}/{group['cases']} | {group['baselineCommonFieldsExact']}/{count} | "
            f"{group['candidateCommonFieldsExact']}/{count} | {group['candidateFullFormExact']}/{count} | "
            f"{group['candidateEquivalentFullFormExact']}/{count} | "
            f"{before} | {after} | "
            f"{group['candidateEquivalentUnnoticedWrongFields']} |"
        )
    (output_path.parent / f"{output_path.stem}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare baseline and candidate on identical physical-iPhone v2 WAVs")
    parser.add_argument("baseline_summary", type=Path)
    parser.add_argument("candidate_summary", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = compare_v2(args.baseline_summary, args.candidate_summary, args.output)
    print(f"Paired: {report['pairedComplete']}; release gate: {report['releaseGate']}; output: {args.output}")


if __name__ == "__main__":
    main()
