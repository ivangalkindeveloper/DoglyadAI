from __future__ import annotations

import argparse
import json
import re
import subprocess
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR, NOISE_PROFILE, add_reproducible_noise, wav_metadata
from evaluation.voice.audio_script_v2 import _description, _spoken_digits, _spoken_number
from evaluation.voice.audio_v2 import FIELD_PAUSE_MS, merge_segments
from evaluation.voice.common import FIELD_IDS, LABELS, ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256, write_corpus

MODE = "phrase-holdout"
OUTPUT_DIR = AUDIO_OUTPUT_DIR / MODE
SWIFT_SOURCE = ROOT / "evaluation/voice/AudioSynthAlt/main.swift"
SOURCE = ROOT / "evaluation/voice/phrase_holdout.py"
VOICES = {
    "en": "com.apple.eloquence.en-US.Eddy",
    "ru": "com.apple.ttsbundle.gryphon-neural_Yelena_ru-RU_premium",
}


def spoken_segments(case: dict[str, Any]) -> list[str]:
    """Render held-out control values with a new, deterministic field order.

    Gold fields come from the control corpus, never from this script or ASR.
    The explicit field names keep this an evaluation of the current labeled
    dictation contract; it does not simulate free-form physician speech.
    """
    locale = case["locale"]

    def pronounce_number(match: re.Match[str]) -> str:
        return _spoken_number(match.group(), locale)

    labels = dict(zip(FIELD_IDS, LABELS[locale], strict=True))
    values: dict[str, str] = case["expectedSourceQuotes"]
    if set(values) != set(FIELD_IDS) or case["scenario"] != "findings_first":
        raise ValueError(f"Expected a complete findings-first control case: {case['id']}")
    tail = list(FIELD_IDS[:-1])
    rotation = sum(case["examinationTypeId"].encode()) % len(tail)
    tail = tail[rotation:] + tail[:rotation]
    order = ["examinationDescription", *tail]
    segments = []
    for field in order:
        original = values[field]
        spoken = original
        if field == "examinationNumber":
            spoken = _spoken_digits(original, locale)
        elif field == "patientDateOfBirth":
            year, month, day = original.split("-")
            spoken = ", ".join(_spoken_digits(part, locale) for part in (year, month, day))
        elif field in {"patientHeightCM", "patientWeightKG"}:
            spoken = re.sub(r"(?<!\w)\d{1,3}(?!\w)", pronounce_number, original)
        elif field == "examinationDescription":
            spoken = _description(original, locale)
        segments.append(f"{labels[field]}: {spoken.rstrip('.')}.")
    return segments


def build_phrase_holdout(*, limit_types: int | None = None) -> dict[str, Any]:
    write_corpus(TEXT_OUTPUT_DIR, release_control=True)
    text_manifest = json.loads((TEXT_OUTPUT_DIR / "manifest.json").read_text(encoding="utf-8"))
    control_path = TEXT_OUTPUT_DIR / "control.jsonl"
    control_hash = file_sha256(control_path)
    if control_hash != text_manifest["controlSha256"]:
        raise ValueError("The reserved control corpus changed")
    cases = [json.loads(line) for line in control_path.read_text(encoding="utf-8").splitlines()]
    selected = [case for case in cases if case["scenario"] == "findings_first"]
    type_ids = list(dict.fromkeys(case["examinationTypeId"] for case in selected))
    if limit_types is not None:
        if limit_types < 1:
            raise ValueError("Limit must be positive")
        selected = [case for case in selected if case["examinationTypeId"] in type_ids[:limit_types]]
    if len(selected) != 2 * (limit_types or len(type_ids)):
        raise ValueError("Expected one case per examination type and language")
    directory = OUTPUT_DIR if limit_types is None else AUDIO_OUTPUT_DIR / f"{MODE}-smoke-{limit_types}"
    manifest_path = directory / "manifest.json"
    source_hashes = {
        "regressionSha256": text_manifest["regressionSha256"],
        "controlSha256": control_hash,
        "synthesizerSourceSha256": file_sha256(SWIFT_SOURCE),
        "generatorSourceSha256": file_sha256(SOURCE),
    }
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if (
            all(manifest.get(key) == value for key, value in source_hashes.items())
            and [entry["caseId"] for entry in manifest.get("entries", [])] == [case["id"] for case in selected]
            and all(
                entry["status"] == "ok"
                and all(
                    file_sha256(ROOT / entry[variant]["path"]) == entry[variant]["sha256"]
                    for variant in ("clean", "noisy")
                )
                for entry in manifest["entries"]
            )
        ):
            return manifest
        raise ValueError("Existing phrase holdout differs; create a new version instead")

    directory.mkdir(parents=True, exist_ok=True)
    scripts = {case["id"]: spoken_segments(case) for case in selected}
    jobs = [
        {
            "id": f"{case['id']}/{part}",
            "locale": case["locale"],
            "voiceIdentifier": VOICES[case["locale"]],
            "spokenText": " ".join(scripts[case["id"]][part * 4 : (part + 1) * 4]),
            "outputPath": str((directory / "segments" / f"{case['id']}-{part}.wav").resolve()),
        }
        for case in selected
        for part in (0, 1)
    ]
    jobs_path = directory / "jobs.json"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    results_path = directory / "synthesis-results.jsonl"
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
        raise ValueError("Synthesis results differ from requested jobs")
    by_id = {result["id"]: result for result in results}
    entries = []
    for case in selected:
        case_id = case["id"]
        parts = [by_id[f"{case_id}/{part}"] for part in (0, 1)]
        entry = {
            "caseId": case_id,
            "locale": case["locale"],
            "examinationTypeId": case["examinationTypeId"],
            "scenario": case["scenario"],
            "ttsText": " ".join(scripts[case_id]),
            "werReference": " ".join(scripts[case_id]),
            "voiceIdentifier": VOICES[case["locale"]],
            "status": "ok" if all(part["status"] == "ok" for part in parts) else "failed",
        }
        if entry["status"] == "ok":
            clean = directory / "clean" / f"{case_id}.wav"
            try:
                if any(part["voiceIdentifier"] != entry["voiceIdentifier"] for part in parts):
                    raise ValueError("Unexpected synthesis voice")
                merge_segments([directory / "segments" / f"{case_id}-{part}.wav" for part in (0, 1)], clean)
                entry["clean"] = {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)}
                noisy = directory / "noisy" / clean.name
                add_reproducible_noise(clean, noisy, f"phrase-holdout-{case_id}")
                entry["noisy"] = {"path": str(noisy.relative_to(ROOT)), **wav_metadata(noisy)}
            except (OSError, ValueError) as error:
                entry["status"] = "failed"
                entry["reason"] = str(error)
        else:
            entry["reason"] = "; ".join(
                part.get("reason") or part["status"] for part in parts if part["status"] != "ok"
            )
        entries.append(entry)
    manifest = {
        "schemaVersion": 2,
        "mode": MODE,
        "split": "control",
        "requestedCases": len(entries),
        "synthesizedCases": sum(entry["status"] == "ok" for entry in entries),
        **source_hashes,
        "fieldPauseMs": FIELD_PAUSE_MS,
        "noiseProfile": NOISE_PROFILE,
        "referenceKind": "intended-tts-words-not-audited-human-transcription",
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Synthesize new-value and new-order holdout dictations")
    parser.add_argument("--limit-types", type=int)
    args = parser.parse_args()
    manifest = build_phrase_holdout(limit_types=args.limit_types)
    print(f"Synthesized {manifest['synthesizedCases']}/{manifest['requestedCases']} phrase holdout cases")
    if manifest["synthesizedCases"] != manifest["requestedCases"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
