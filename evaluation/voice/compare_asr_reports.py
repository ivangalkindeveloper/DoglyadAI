from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.comparison import _critical_retention
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256

CRITICAL_KINDS = ("side", "negation", "number", "unit")


def _rows(report: dict[str, Any]) -> dict[tuple[str, str], dict[str, Any]]:
    rows = {(row["caseId"], row["variant"]): row for row in report["results"]}
    if len(rows) != len(report["results"]):
        raise ValueError("Duplicate ASR case and variant")
    return rows


def compare_reports(baseline_path: Path, candidate_path: Path, output_path: Path) -> dict[str, Any]:
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    if baseline["audioManifestSha256"] != candidate["audioManifestSha256"]:
        raise ValueError("ASR reports use different audio manifests")
    if baseline["audioMode"] != candidate["audioMode"]:
        raise ValueError("ASR reports use different audio modes")

    old = _rows(baseline)
    new = _rows(candidate)
    variants = {variant for _, variant in new}
    paired = {key: row for key, row in old.items() if key[1] in variants}
    if not variants or set(paired) != set(new):
        raise ValueError("ASR reports do not cover the same cases for the candidate variants")
    split = {
        "voice-blind-v3": "voiceBlind",
        "reordered-format": "voiceBlind",
        "freeform-development": "freeformDevelopment",
    }.get(baseline["audioMode"], "regression")
    corpus_path = TEXT_OUTPUT_DIR / f"{split}.jsonl"
    if split in ("voiceBlind", "freeformDevelopment"):
        manifest_path = AUDIO_OUTPUT_DIR / baseline["audioMode"] / "manifest.json"
        if file_sha256(manifest_path) != baseline["audioManifestSha256"]:
            raise ValueError("ASR report and audio manifest hashes differ")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        hash_key = "voiceBlindSha256" if split == "voiceBlind" else "freeformDevelopmentSha256"
        if manifest[hash_key] != file_sha256(corpus_path):
            raise ValueError("ASR report and corpus hashes differ")
    cases = {case["id"]: case for case in map(json.loads, corpus_path.read_text(encoding="utf-8").splitlines())}

    groups: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for key, current in new.items():
        previous = paired[key]
        case = cases[key[0]]
        if previous["locale"] != current["locale"] or case["locale"] != current["locale"]:
            raise ValueError(f"ASR locale differs for {key[0]}")
        item: dict[str, Any] = {"caseId": key[0], "variant": key[1], "locale": current["locale"]}
        if previous["status"] != "ok" or current["status"] != "ok":
            item["status"] = "unavailable"
        else:
            item["status"] = "ok"
            item["baselineWER"] = previous["correctedWER"]
            item["candidateWER"] = current["correctedWER"]
            before = _critical_retention(case, previous["correctedText"])
            after = _critical_retention(case, current["correctedText"])
            item["literalFactRegressions"] = [
                kind for kind in CRITICAL_KINDS if before[kind] is True and after[kind] is False
            ]
            item["literalFactImprovements"] = [
                kind for kind in CRITICAL_KINDS if before[kind] is False and after[kind] is True
            ]
        groups.setdefault((current["locale"], key[1]), []).append(item)

    by_group: dict[str, Any] = {}
    for (locale, variant), items in sorted(groups.items()):
        scored = [item for item in items if item["status"] == "ok"]
        by_group[f"{locale}/{variant}"] = {
            "cases": len(items),
            "pairedRecognized": len(scored),
            "baselineMeanWER": sum(item["baselineWER"] for item in scored) / len(scored) if scored else None,
            "candidateMeanWER": sum(item["candidateWER"] for item in scored) / len(scored) if scored else None,
            "literalFactRegressions": {
                kind: [item["caseId"] for item in scored if kind in item["literalFactRegressions"]]
                for kind in CRITICAL_KINDS
            },
            "literalFactImprovements": {
                kind: [item["caseId"] for item in scored if kind in item["literalFactImprovements"]]
                for kind in CRITICAL_KINDS
            },
        }

    # Written-out numbers can preserve their meaning while failing a literal
    # digit check. Side and negation losses are the hard ASR experiment gate.
    side_negation_gate = all(
        group["pairedRecognized"] == group["cases"]
        and not group["literalFactRegressions"]["side"]
        and not group["literalFactRegressions"]["negation"]
        for group in by_group.values()
    )
    result = {
        "schemaVersion": 1,
        "baselineReportSha256": file_sha256(baseline_path),
        "candidateReportSha256": file_sha256(candidate_path),
        "audioManifestSha256": baseline["audioManifestSha256"],
        "literalSideNegationGatePassed": side_negation_gate,
        "byLocaleAndVariant": by_group,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare ASR variants on identical synthetic WAV files")
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    result = compare_reports(args.baseline, args.candidate, args.output)
    print(f"Literal side/negation gate: {'passed' if result['literalSideNegationGatePassed'] else 'failed'}")
    print(f"Report: {args.output}")


if __name__ == "__main__":
    main()
