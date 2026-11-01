from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.scoring.score_asr_matrix import score_asr_matrix


def _stage_effects(path: Path) -> dict[str, Any]:
    comparisons = (
        ("explicitRules", "medgemma"),
        ("explicitRules", "productionMedgemma"),
        ("medgemma", "productionMedgemma"),
        ("explicitRules", "medgemma15"),
        ("explicitRules", "productionMedgemma15"),
        ("medgemma15", "productionMedgemma15"),
    )
    groups: dict[str, Any] = defaultdict(
        lambda: {
            "cases": 0,
            "gainedFields": 0,
            "lostFields": 0,
            "gainedForms": 0,
            "lostForms": 0,
            "rightFailedCases": 0,
        }
    )
    current: dict[str, Any] = {}

    def consume() -> None:
        if not current:
            return
        sample = next(iter(current.values()))
        if sample["mode"] == "terminology":
            return
        dataset = "natural" if sample["mode"].startswith("natural-") else "dictation"
        for left, right in comparisons:
            if left not in current or right not in current:
                continue
            a, b = current[left], current[right]
            group = groups[f"{sample['recognizer']}/{sample['locale']}/{dataset}/{left}->{right}"]
            group["cases"] += 1
            group["rightFailedCases"] += b["status"] != "ok"
            for field in sample["expectedFieldIds"]:
                first = a["status"] == "ok" and a["score"]["equivalentMatches"][field]
                second = b["status"] == "ok" and b["score"]["equivalentMatches"][field]
                group["gainedFields"] += second and not first
                group["lostFields"] += first and not second
            first = a["status"] == "ok" and a["score"]["equivalentExactCase"]
            second = b["status"] == "ok" and b["score"]["equivalentExactCase"]
            group["gainedForms"] += second and not first
            group["lostForms"] += first and not second

    with path.open(encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            if row["stage"] == "asr":
                consume()
                current = {}
            else:
                current[row["method"]] = row
        consume()
    return {
        "metric": "normalized textual agreement with original unreviewed gold",
        "note": "Paired gains AND losses; validated model output versus rules/merge. Historical data do not isolate every validator decision; these are observed pipeline-stage differences, not a causal attribution to a model alone.",
        "groups": dict(groups),
    }


def rescore_baseline(baseline_dir: Path, output: Path) -> dict[str, Any]:
    baseline_path = baseline_dir / "baseline.json"
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    original = json.loads((baseline_dir / "summary.json").read_text(encoding="utf-8"))
    manifest_path = baseline_dir / "corpus-final.json"
    if file_sha256(manifest_path) != original["manifestSha256"]:
        raise ValueError("Historical corpus hash differs")
    paths = []
    for artifact in baseline["rawArtifacts"]:
        path = ROOT / artifact["path"]
        if file_sha256(path) != artifact["sha256"]:
            raise ValueError(f"Historical raw artifact differs: {path}")
        paths.append(path)
    result = score_asr_matrix(
        manifest_path=manifest_path,
        asr_paths=[path for path in paths if "/asr/" in str(path)],
        extraction_paths=[path for path in paths if "/extraction/" in str(path)],
        output=output,
        methods=tuple(baseline["methods"]),
    )
    changes = []
    for section, keys in (
        ("asr", ("meanNormalizedWER", "meanWER")),
        (
            "extraction",
            (
                "correctFields",
                "equivalentCorrectFields",
                "exactForms",
                "equivalentExactForms",
                "automaticFields",
                "wrongAutomaticFields",
            ),
        ),
    ):
        for group, scores in result[section].items():
            for metric in keys:
                before, after = original[section][group].get(metric), scores[metric]
                if before != after:
                    changes.append(
                        {"section": section, "group": group, "metric": metric, "before": before, "after": after}
                    )
    delta = {
        "rescoreSourceSha256": file_sha256(Path(__file__)),
        "baselineSha256": file_sha256(baseline_path),
        "originalSummarySha256": file_sha256(baseline_dir / "summary.json"),
        "newSummarySha256": file_sha256(output / "summary.json"),
        "note": "Same recorded hypotheses and unreviewed gold; differences are scorer changes, not model improvements or clinical validation.",
        "changes": changes,
    }
    (output / "scorer-changes.json").write_text(
        json.dumps(delta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (output / "stage-effects.json").write_text(
        json.dumps(_stage_effects(output / "case-scores.jsonl"), ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    notes_path = baseline_dir / "model-card-notes.json"
    if notes_path.exists():
        notes = json.loads(notes_path.read_text(encoding="utf-8"))
        (output / "conditions.json").write_text(
            json.dumps(
                {
                    "baselineSha256": file_sha256(baseline_path),
                    "modelCardNotesSha256": file_sha256(notes_path),
                    "backendSourceRevision": baseline.get("backendSourceRevision"),
                    "measurementDates": baseline.get("measurementDates"),
                    "modelAndTimingNotes": notes,
                    "diagnosticOnlyLocalePairs": ["gigaam/en", "medasr/ru"],
                    "isNewInferenceRun": False,
                },
                ensure_ascii=False,
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
    return {
        "isASRComplete": result["isASRComplete"],
        "isExtractionComplete": result["isExtractionComplete"],
        "changedAggregateMetrics": len(changes),
        "output": str(output),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Rescore a frozen run with hashes; never overwrite historical evidence"
    )
    parser.add_argument("baseline", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(rescore_baseline(args.baseline, args.output), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
