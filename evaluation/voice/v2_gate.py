from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256


def _load(path: Path, variant: str) -> dict[str, Any]:
    summary = json.loads(path.read_text(encoding="utf-8"))
    if summary.get("platform") != "iOS" or summary.get("audioMode") != "extended-v2":
        raise ValueError("Release report must come from physical-iPhone v2 audio")
    if summary.get("audioVariant") != variant:
        raise ValueError(f"Expected {variant} audio report")
    rows = summary["scoredCases"]
    if len(rows) != len({row["id"] for row in rows}):
        raise ValueError("Duplicate case IDs")
    return summary


def check_v2_gate(clean_path: Path, noisy_path: Path, output_path: Path) -> dict[str, Any]:
    clean = _load(clean_path, "clean")
    noisy = _load(noisy_path, "noisy")
    for key in ("audioManifestSha256", "regressionSha256", "systemVersion", "deviceModel"):
        if clean.get(key) != noisy.get(key):
            raise ValueError(f"Clean and noisy reports differ in {key}")
    manifest_path = AUDIO_OUTPUT_DIR / "extended-v2" / "manifest.json"
    if clean["audioManifestSha256"] != file_sha256(manifest_path):
        raise ValueError("Release reports use a stale v2 audio manifest")
    clean_cases = {row["id"]: (row["locale"], row["examinationTypeId"]) for row in clean["scoredCases"]}
    noisy_cases = {row["id"]: (row["locale"], row["examinationTypeId"]) for row in noisy["scoredCases"]}
    if clean_cases != noisy_cases:
        raise ValueError("Clean and noisy reports cover different cases")

    results: dict[str, Any] = {}
    for variant, summary, target in (("clean", clean, 118), ("noisy", noisy, 106)):
        by_locale: dict[str, Any] = {}
        for locale in ("en", "ru"):
            group = summary["byLocale"][locale]
            analyzer = group["speechAnalyzer"]
            complete = (
                group["cases"] == analyzer["scoredCases"] == 124
                and sum(row["locale"] == locale for row in summary["scoredCases"]) == 124
                and analyzer["asrStatuses"] == {"ok": 124}
                and analyzer["parseStatuses"] == {"ok": 124}
            )
            by_locale[locale] = {
                "cases": group["cases"],
                "completed": analyzer["scoredCases"],
                "equivalentExactCases": analyzer["equivalentExactCases"],
                "equivalentUnnoticedWrongFields": analyzer["equivalentUnnoticedWrongFields"],
                "targetExactCases": target,
                "passed": complete
                and analyzer["equivalentExactCases"] >= target
                and analyzer["equivalentUnnoticedWrongFields"] == 0,
            }
        results[variant] = by_locale

    report = {
        "schemaVersion": 1,
        "audioMode": "extended-v2",
        "audioManifestSha256": clean["audioManifestSha256"],
        "regressionSha256": clean["regressionSha256"],
        "cleanSummarySha256": file_sha256(clean_path),
        "noisySummarySha256": file_sha256(noisy_path),
        "byVariant": results,
        "releaseReady": all(group["passed"] for variant in results.values() for group in variant.values()),
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Check the full clean/noisy v2 candidate release targets")
    parser.add_argument("clean_summary", type=Path)
    parser.add_argument("noisy_summary", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    report = check_v2_gate(args.clean_summary, args.noisy_summary, args.output)
    print(f"v2 release ready: {report['releaseReady']}; output: {args.output}")


if __name__ == "__main__":
    main()
