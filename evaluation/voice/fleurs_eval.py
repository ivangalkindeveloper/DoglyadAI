from __future__ import annotations

import json
import subprocess
from typing import Any

from evaluation.voice.asr import ASR_SOURCE, CLASSIC_SOURCE, CORRECTOR_SOURCE, FILE_ERROR_SOURCE, FILE_RESULT_SOURCE
from evaluation.voice.comparison import character_error_rate
from evaluation.voice.fleurs import LANGUAGES, OUTPUT_DIR, REVISION
from evaluation.voice.generate import file_sha256
from evaluation.voice.asr import word_error_rate
from evaluation.voice.common import ROOT


def run_fleurs_asr() -> dict[str, Any]:
    manifests = {
        locale: json.loads((OUTPUT_DIR / code / "manifest.json").read_text(encoding="utf-8"))
        for locale, code in LANGUAGES.items()
    }
    jobs = []
    lookup = {}
    for locale, manifest in manifests.items():
        if manifest["revision"] != REVISION or len(manifest["entries"]) != 100:
            raise ValueError(f"Unexpected FLEURS manifest for {locale}")
        for entry in manifest["entries"]:
            path = ROOT / entry["audioPath"]
            if file_sha256(path) != entry["audioSha256"]:
                raise ValueError(f"FLEURS audio hash mismatch: {path}")
            for version, hints in (("baseline", False), ("candidate", True)):
                job_id = f"{entry['id']}::{version}"
                jobs.append(
                    {
                        "id": job_id,
                        "locale": locale,
                        "audioPath": str(path),
                        "contextualStrings": [],
                        "engine": "speechAnalyzer",
                        "useHints": hints,
                    }
                )
                lookup[job_id] = (locale, entry, version)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    jobs_path = OUTPUT_DIR / "asr-jobs.json"
    results_path = OUTPUT_DIR / "asr-results.jsonl"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    executable = OUTPUT_DIR / "voice-audio-asr"
    subprocess.run(
        [
            "swiftc",
            "-O",
            "-parse-as-library",
            "-module-cache-path",
            str(OUTPUT_DIR / "swift-module-cache"),
            *map(str, (ASR_SOURCE, CORRECTOR_SOURCE, CLASSIC_SOURCE, FILE_RESULT_SOURCE, FILE_ERROR_SOURCE)),
            "-o",
            str(executable),
        ],
        check=True,
    )
    subprocess.run([str(executable), str(jobs_path), str(results_path)], check=True, timeout=400 * 45)
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [result["id"] for result in results] != [job["id"] for job in jobs]:
        raise ValueError("FLEURS ASR results do not match jobs")
    scored = []
    for result in results:
        locale, entry, version = lookup[result["id"]]
        row = {
            "id": entry["id"],
            "locale": locale,
            "version": version,
            "status": result["status"],
            "reason": result.get("reason"),
            "elapsedSeconds": result.get("elapsedSeconds"),
        }
        if result["status"] == "ok":
            text = result["correctedText"]
            reference = entry["normalizedTranscription"]
            row.update(wer=word_error_rate(reference, text), cer=character_error_rate(reference, text), text=text)
        scored.append(row)
    by_locale = {}
    paired = {}
    for locale in LANGUAGES:
        baseline = {row["id"]: row for row in scored if row["locale"] == locale and row["version"] == "baseline"}
        candidate = {row["id"]: row for row in scored if row["locale"] == locale and row["version"] == "candidate"}
        matched = [
            (baseline[key], candidate[key])
            for key in baseline
            if baseline[key]["status"] == candidate[key]["status"] == "ok"
        ]
        paired[locale] = len(matched)
        by_locale[locale] = {
            "requested": 100,
            "paired": len(matched),
            "baselineWER": sum(old["wer"] for old, _ in matched) / len(matched) if matched else None,
            "baselineCER": sum(old["cer"] for old, _ in matched) / len(matched) if matched else None,
            "candidateWER": sum(new["wer"] for _, new in matched) / len(matched) if matched else None,
            "candidateCER": sum(new["cer"] for _, new in matched) / len(matched) if matched else None,
        }
    report = {
        "schemaVersion": 1,
        "dataset": "google/fleurs",
        "revision": REVISION,
        "baselineCandidatePaired": paired,
        "byLocale": by_locale,
        "results": scored,
        "note": "Both labels use the same unchanged SpeechAnalyzer with empty hints; separate runs check stability on natural general speech, not a medical ASR improvement.",
    }
    (OUTPUT_DIR / "asr-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return report


if __name__ == "__main__":
    result = run_fleurs_asr()
    print(f"Paired FLEURS clips: {result['baselineCandidatePaired']}")
