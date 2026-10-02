from __future__ import annotations

import json
import re
import subprocess
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR, NOISE_PROFILE, add_reproducible_noise, wav_metadata
from evaluation.voice.audio_script_v2 import _description, _spoken_digits, _spoken_number
from evaluation.voice.audio_v2 import FIELD_PAUSE_MS, merge_segments
from evaluation.voice.common import ROOT
from evaluation.voice.freeform_development import SPLIT, write_cases
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256

MODE = "freeform-development"
OUTPUT_DIR = AUDIO_OUTPUT_DIR / MODE
SOURCE = ROOT / "evaluation/voice/freeform_audio.py"
SYNTH_SOURCE = ROOT / "evaluation/voice/AudioSynthAlt/main.swift"
NOISE_SOURCE = ROOT / "evaluation/voice/audio.py"
VOICES = {
    "en": "com.apple.eloquence.en-US.Flo",
    "ru": "com.apple.voice.compact.ru-RU.Milena",
}


def tts_script(case: dict[str, Any]) -> str:
    text = case["spokenText"]
    locale = case["locale"]
    sources: dict[str, str] = case["expectedSourceQuotes"]
    # Replace whole source quotes once; expected values were fixed before this
    # phonetic rendering and are never inferred from the synthesized output.
    for field in (
        "examinationDescription",
        "patientDateOfBirth",
        "patientHeightCM",
        "patientWeightKG",
        "examinationNumber",
    ):
        if field not in sources:
            continue
        original = sources[field]
        if field == "examinationDescription":
            spoken = _description(original, locale)
        elif field == "patientDateOfBirth":
            year, month, day = original.split("-")
            spoken = ", ".join(_spoken_digits(part, locale) for part in (year, month, day))
        elif field in {"patientHeightCM", "patientWeightKG"}:
            spoken = re.sub(
                r"(?<!\w)\d{1,3}(?!\w)",
                lambda match: _spoken_number(match.group(), locale),
                original,
            )
        else:
            spoken = _spoken_digits(original, locale)
        if text.count(original) != 1:
            raise ValueError(f"Source quote must be unique in {case['id']}: {field}")
        text = text.replace(original, spoken, 1)
    return text


def tts_chunks(script: str) -> tuple[str, str]:
    sentences = re.split(r"(?<=\.)\s+", script.strip())
    if len(sentences) < 2:
        raise ValueError("Freeform dictation needs at least two sentences")
    midpoint = min(
        range(1, len(sentences)),
        key=lambda index: abs(len(" ".join(sentences[:index])) - len(script) / 2),
    )
    return " ".join(sentences[:midpoint]), " ".join(sentences[midpoint:])


def build_audio() -> dict[str, Any]:
    corpus_manifest = write_cases(TEXT_OUTPUT_DIR)
    corpus_path = TEXT_OUTPUT_DIR / f"{SPLIT}.jsonl"
    cases = [json.loads(line) for line in corpus_path.read_text(encoding="utf-8").splitlines()]
    hashes = {
        "freeformDevelopmentSha256": corpus_manifest["corpusSha256"],
        "regressionSha256": file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl"),
        "generatorSourceSha256": corpus_manifest["generatorSourceSha256"],
        "audioSourceSha256": file_sha256(SOURCE),
        "synthesizerSourceSha256": file_sha256(SYNTH_SOURCE),
        "noiseSourceSha256": file_sha256(NOISE_SOURCE),
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    if manifest_path.exists():
        previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        if (
            previous.get("mode") == MODE
            and all(previous.get(key) == value for key, value in hashes.items())
            and [entry["caseId"] for entry in previous["entries"]] == [case["id"] for case in cases]
            and all(
                entry["status"] == "ok"
                and entry["ttsText"] == tts_script(case)
                and all(
                    file_sha256(ROOT / entry[variant]["path"]) == entry[variant]["sha256"]
                    for variant in ("clean", "noisy")
                )
                for entry, case in zip(previous["entries"], cases, strict=True)
            )
        ):
            return previous

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    scripts = {case["id"]: tts_script(case) for case in cases}
    jobs = []
    for case in cases:
        for index, chunk in enumerate(tts_chunks(scripts[case["id"]])):
            jobs.append(
                {
                    "id": f"{case['id']}/{index}",
                    "locale": case["locale"],
                    "voiceIdentifier": VOICES[case["locale"]],
                    "spokenText": chunk,
                    "outputPath": str((OUTPUT_DIR / "segments" / f"{case['id']}-{index}.wav").resolve()),
                }
            )
    jobs_path = OUTPUT_DIR / "jobs.json"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    results_path = OUTPUT_DIR / "synthesis-results.jsonl"
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
        raise ValueError("TTS results differ from jobs")
    by_id = {result["id"]: result for result in results}
    entries = []
    for case in cases:
        case_id = case["id"]
        parts = [by_id[f"{case_id}/{index}"] for index in (0, 1)]
        if any(part["status"] != "ok" for part in parts):
            raise ValueError(f"TTS failed for {case_id}")
        clean = OUTPUT_DIR / "clean" / f"{case_id}.wav"
        merge_segments([OUTPUT_DIR / "segments" / f"{case_id}-{index}.wav" for index in (0, 1)], clean)
        noisy = OUTPUT_DIR / "noisy" / clean.name
        add_reproducible_noise(clean, noisy, f"freeform-dev-{case_id}")
        entries.append(
            {
                "caseId": case_id,
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "scenario": case["scenario"],
                "ttsText": scripts[case_id],
                "werReference": scripts[case_id],
                "voiceIdentifier": VOICES[case["locale"]],
                "status": "ok",
                "clean": {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)},
                "noisy": {"path": str(noisy.relative_to(ROOT)), **wav_metadata(noisy)},
            }
        )
    manifest = {
        "schemaVersion": 1,
        "mode": MODE,
        "split": SPLIT,
        "noiseProfile": NOISE_PROFILE,
        "fieldPauseMs": FIELD_PAUSE_MS,
        **hashes,
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    manifest = build_audio()
    print(f"Synthesized {len(manifest['entries'])} freeform development cases")


if __name__ == "__main__":
    main()
