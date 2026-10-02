from __future__ import annotations

import argparse
import json
import subprocess
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR, NOISE_PROFILE, add_reproducible_noise, wav_metadata
from evaluation.voice.audio_script_v2 import make_audio_segments
from evaluation.voice.audio_v2 import FIELD_PAUSE_MS, merge_segments
from evaluation.voice.common import ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256

MODE = "voice-holdout"
OUTPUT_DIR = AUDIO_OUTPUT_DIR / MODE
SWIFT_SOURCE = ROOT / "evaluation/voice/AudioSynthAlt/main.swift"
SOURCE = ROOT / "evaluation/voice/holdout_voice.py"
VOICES = {
    "en": "com.apple.eloquence.en-US.Eddy",
    "ru": "com.apple.ttsbundle.gryphon-neural_Yelena_ru-RU_premium",
}


def build_holdout(*, limit_types: int | None = None, force: bool = False) -> dict[str, Any]:
    original_path = AUDIO_OUTPUT_DIR / "extended-v2" / "manifest.json"
    original = json.loads(original_path.read_text(encoding="utf-8"))
    if original.get("mode") != "extended-v2":
        raise ValueError("Expected the frozen v2 audio corpus")
    regression_path = TEXT_OUTPUT_DIR / "regression.jsonl"
    if original["regressionSha256"] != file_sha256(regression_path):
        raise ValueError("V2 audio and regression cases differ")
    cases = {case["id"]: case for case in map(json.loads, regression_path.read_text(encoding="utf-8").splitlines())}
    selected = [entry for entry in original["entries"] if entry["scenario"] == "complete"]
    type_ids = list(dict.fromkeys(entry["examinationTypeId"] for entry in selected))
    if limit_types is not None:
        if limit_types < 1:
            raise ValueError("Limit must be positive")
        type_ids = type_ids[:limit_types]
        selected = [entry for entry in selected if entry["examinationTypeId"] in type_ids]
    if len(selected) != 2 * len(type_ids) or {entry["locale"] for entry in selected} != {"en", "ru"}:
        raise ValueError("Expected one complete case per examination type and locale")

    directory = OUTPUT_DIR if limit_types is None else AUDIO_OUTPUT_DIR / f"{MODE}-smoke-{limit_types}"
    manifest_path = directory / "manifest.json"
    source_hashes = {
        "originalAudioManifestSha256": file_sha256(original_path),
        "synthesizerSourceSha256": file_sha256(SWIFT_SOURCE),
        "generatorSourceSha256": file_sha256(SOURCE),
    }
    if manifest_path.exists() and not force:
        previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        if (
            all(previous.get(key) == value for key, value in source_hashes.items())
            and all(
                entry["status"] == "ok"
                and all(
                    file_sha256(ROOT / entry[variant]["path"]) == entry[variant]["sha256"]
                    for variant in ("clean", "noisy")
                )
                for entry in previous.get("entries", [])
            )
            and [entry["caseId"] for entry in previous["entries"]] == [entry["caseId"] for entry in selected]
        ):
            return previous
        raise ValueError("Existing holdout differs; use --force to replace it")

    directory.mkdir(parents=True, exist_ok=True)
    jobs = []
    for entry in selected:
        segments = make_audio_segments(cases[entry["caseId"]])
        if " ".join(segments) != entry["ttsText"]:
            raise ValueError(f"TTS script drift for {entry['caseId']}")
        for part, field_segments in enumerate((segments[:4], segments[4:])):
            jobs.append(
                {
                    "id": f"{entry['caseId']}/{part}",
                    "locale": entry["locale"],
                    "voiceIdentifier": VOICES[entry["locale"]],
                    "spokenText": " ".join(field_segments),
                    "outputPath": str((directory / "segments" / f"{entry['caseId']}-{part}.wav").resolve()),
                }
            )
    jobs_path = directory / "jobs.json"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    results_path = directory / "synthesis-results.jsonl"
    # The Swift interpreter can see downloaded system voices that macOS hides
    # from an unsigned standalone executable.
    subprocess.run(
        [
            "swift",
            "-module-cache-path",
            str(AUDIO_OUTPUT_DIR / "swift-module-cache"),
            str(SWIFT_SOURCE),
            str(jobs_path),
            str(results_path),
        ],
        check=True,
    )
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [result["id"] for result in results] != [job["id"] for job in jobs]:
        raise ValueError("Holdout synthesis results differ from jobs")
    by_id = {result["id"]: result for result in results}
    entries = []
    for original_entry in selected:
        case_id = original_entry["caseId"]
        parts = [by_id[f"{case_id}/{part}"] for part in (0, 1)]
        entry = {
            "caseId": case_id,
            "locale": original_entry["locale"],
            "examinationTypeId": original_entry["examinationTypeId"],
            "scenario": "complete",
            "ttsText": original_entry["ttsText"],
            "werReference": original_entry["werReference"],
            "voiceIdentifier": VOICES[original_entry["locale"]],
            "status": "ok" if all(part["status"] == "ok" for part in parts) else "failed",
        }
        if entry["status"] == "ok":
            clean = directory / "clean" / f"{case_id}.wav"
            try:
                if any(part["voiceIdentifier"] != entry["voiceIdentifier"] for part in parts):
                    raise ValueError("Unexpected holdout voice")
                merge_segments([directory / "segments" / f"{case_id}-{part}.wav" for part in (0, 1)], clean)
                entry["clean"] = {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)}
                noisy = directory / "noisy" / clean.name
                add_reproducible_noise(clean, noisy, f"holdout-{case_id}")
                entry["noisy"] = {"path": str(noisy.relative_to(ROOT)), **wav_metadata(noisy)}
            except (OSError, ValueError) as error:
                entry["status"] = "failed"
                entry["reason"] = str(error)
        else:
            entry["reason"] = "; ".join(
                part.get("reason") or part["status"] for part in parts if part["status"] != "ok"
            )
        entries.append(entry)
    manifest: dict[str, Any] = {
        "schemaVersion": 2,
        "mode": MODE,
        "requestedCases": len(entries),
        "synthesizedCases": sum(entry["status"] == "ok" for entry in entries),
        "regressionSha256": original["regressionSha256"],
        **source_hashes,
        "fieldPauseMs": FIELD_PAUSE_MS,
        "noiseProfile": NOISE_PROFILE,
        "referenceKind": "intended-tts-words-not-audited-human-transcription",
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Create an alternate-voice holdout from frozen v2 scripts")
    parser.add_argument("--limit-types", type=int)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    result = build_holdout(limit_types=args.limit_types, force=args.force)
    print(f"Synthesized {result['synthesizedCases']}/{result['requestedCases']} holdout cases")
    if result["synthesizedCases"] != result["requestedCases"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
