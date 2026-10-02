from __future__ import annotations

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

MODE = "guided-format"
SCENARIOS = ("complete", "missing_demographics")
OUTPUT_DIR = AUDIO_OUTPUT_DIR / MODE
SOURCE = ROOT / "evaluation/voice/guided_format.py"
SYNTH_SOURCE = ROOT / "evaluation/voice/AudioSynthAlt/main.swift"
NOISE_SOURCE = ROOT / "evaluation/voice/audio.py"
VOICES = {
    "en": "com.apple.eloquence.en-US.Flo",
    "ru": "com.apple.voice.compact.ru-RU.Milena",
}


def selected_cases() -> list[dict[str, Any]]:
    write_corpus(TEXT_OUTPUT_DIR)
    cases = [
        case
        for line in (TEXT_OUTPUT_DIR / "regression.jsonl").read_text(encoding="utf-8").splitlines()
        if (case := json.loads(line))["scenario"] in SCENARIOS
    ]
    keys = [(case["locale"], case["examinationTypeId"], case["scenario"]) for case in cases]
    if len(keys) != len(set(keys)) or len(cases) != 62 * len(SCENARIOS):
        raise ValueError("Guided format needs one complete and one partial case per type and locale")
    return cases


def spoken_segments(case: dict[str, Any]) -> list[str]:
    locale = case["locale"]

    def pronounce_number(match: re.Match[str]) -> str:
        return _spoken_number(match.group(), locale)

    labels = dict(zip(FIELD_IDS, LABELS[locale], strict=True))
    sources: dict[str, str] = case["expectedSourceQuotes"]
    segments = []
    for field in FIELD_IDS:
        if field not in sources:
            continue
        original = sources[field]
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
    if len(segments) != len(case["expectedFields"]):
        raise ValueError(f"Guided audio fields differ from gold: {case['id']}")
    return segments


def build_audio(*, limit: int | None = None) -> dict[str, Any]:
    cases = selected_cases()
    if limit is not None:
        if limit < 1:
            raise ValueError("Limit must be positive")
        cases = cases[:limit]
    output = OUTPUT_DIR if limit is None else AUDIO_OUTPUT_DIR / f"{MODE}-smoke-{limit}"
    scripts = {case["id"]: spoken_segments(case) for case in cases}
    hashes = {
        "regressionSha256": file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl"),
        "generatorSourceSha256": file_sha256(SOURCE),
        "synthesizerSourceSha256": file_sha256(SYNTH_SOURCE),
        "noiseSourceSha256": file_sha256(NOISE_SOURCE),
    }
    manifest_path = output / "manifest.json"
    if manifest_path.exists():
        previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        valid = (
            previous.get("mode") == MODE
            and previous.get("schemaVersion") == 2
            and all(previous.get(key) == value for key, value in hashes.items())
            and [entry["caseId"] for entry in previous["entries"]] == [case["id"] for case in cases]
            and all(
                entry["status"] == "ok"
                and entry["ttsText"] == " ".join(scripts[case["id"]])
                and all(
                    file_sha256(ROOT / entry[variant]["path"]) == entry[variant]["sha256"]
                    for variant in ("clean", "noisy")
                )
                for entry, case in zip(previous["entries"], cases, strict=True)
            )
        )
        if not valid:
            raise ValueError("Guided format audio differs from its manifest; create a new version")
        return previous

    output.mkdir(parents=True, exist_ok=True)
    jobs = []
    for case in cases:
        segments = scripts[case["id"]]
        midpoint = max(1, len(segments) // 2)
        for index, chunk in enumerate((segments[:midpoint], segments[midpoint:])):
            jobs.append(
                {
                    "id": f"{case['id']}/{index}",
                    "locale": case["locale"],
                    "voiceIdentifier": VOICES[case["locale"]],
                    "spokenText": " ".join(chunk),
                    "outputPath": str((output / "segments" / f"{case['id']}-{index}.wav").resolve()),
                }
            )
    jobs_path = output / "jobs.json"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    results_path = output / "synthesis-results.jsonl"
    subprocess.run(
        [
            "swift",
            "-module-cache-path",
            str(AUDIO_OUTPUT_DIR / "swift-module-cache"),
            str(SYNTH_SOURCE),
            str(jobs_path),
            str(results_path),
        ],
        check=True,
    )
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [result["id"] for result in results] != [job["id"] for job in jobs]:
        raise ValueError("Guided synthesis results differ from jobs")
    by_id = {result["id"]: result for result in results}
    entries = []
    for case in cases:
        case_id = case["id"]
        if any(by_id[f"{case_id}/{index}"]["status"] != "ok" for index in (0, 1)):
            raise ValueError(f"Guided synthesis failed: {case_id}")
        clean = output / "clean" / f"{case_id}.wav"
        merge_segments([output / "segments" / f"{case_id}-{index}.wav" for index in (0, 1)], clean)
        noisy = output / "noisy" / clean.name
        add_reproducible_noise(clean, noisy, f"guided-format-{case_id}")
        script = " ".join(scripts[case_id])
        entries.append(
            {
                "caseId": case_id,
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "scenario": case["scenario"],
                "ttsText": script,
                "werReference": script,
                "voiceIdentifier": VOICES[case["locale"]],
                "status": "ok",
                "clean": {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)},
                "noisy": {"path": str(noisy.relative_to(ROOT)), **wav_metadata(noisy)},
            }
        )
    manifest = {
        "schemaVersion": 2,
        "mode": MODE,
        "split": "regression",
        "suite": "guidedFormat",
        "requestedCases": len(entries),
        "fieldPauseMs": FIELD_PAUSE_MS,
        "noiseProfile": NOISE_PROFILE,
        "referenceKind": "intended-tts-words-not-audited-human-transcription",
        **hashes,
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Synthesize dictation in the exact order shown in the recording sheet")
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    manifest = build_audio(limit=args.limit)
    print(f"Guided format: {len(manifest['entries'])} clean and noisy WAV pairs")


if __name__ == "__main__":
    main()
