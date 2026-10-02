from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR, NOISE_PROFILE, add_reproducible_noise, wav_metadata
from evaluation.voice.audio_script_v2 import _description, _spoken_digits, _spoken_number
from evaluation.voice.audio_v2 import FIELD_PAUSE_MS, merge_segments
from evaluation.voice.common import FIELD_IDS, LABELS, ROOT, load_catalog, make_source, render_case, seeded_random
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256, jsonl_bytes, write_corpus

MODE = "voice-blind-v3"
SPLIT = "voiceBlind"
OUTPUT_DIR = AUDIO_OUTPUT_DIR / MODE
CORPUS_PATH = TEXT_OUTPUT_DIR / f"{SPLIT}.jsonl"
SWIFT_SOURCE = ROOT / "evaluation/voice/AudioSynthAlt/main.swift"
SOURCE = ROOT / "evaluation/voice/voice_blind_v3.py"
NOISE_SOURCE = ROOT / "evaluation/voice/audio.py"
NAMES = {
    "en": {
        "male": ("James Parker", "Oliver Hughes", "Thomas Bennett"),
        "female": ("Sophie Carter", "Amelia Brooks", "Grace Miller"),
    },
    "ru": {
        "male": ("Сергей Волков", "Павел Соколов", "Николай Егоров"),
        "female": ("Ольга Морозова", "Наталья Белова", "Татьяна Кузнецова"),
    },
}
VOICES = {
    "en": (
        "com.apple.eloquence.en-US.Flo",
        "com.apple.eloquence.en-US.Reed",
    ),
    "ru": (
        "com.apple.voice.compact.ru-RU.Milena",
        "com.apple.ttsbundle.gryphon-neural_Yelena_ru-RU_premium",
    ),
}
PARTIAL_FIELDS = (
    "examinationDescription",
    "patientComplaints",
    "patientWeightKG",
    "examinationNumber",
)


def make_cases() -> list[dict[str, Any]]:
    type_ids, terms = load_catalog()
    cases = []
    for locale in ("en", "ru"):
        for type_id in type_ids:
            for index in (0, 1):
                values, spoken, facts = make_source(
                    "voice-blind-v3",
                    locale,
                    type_id,
                    index,
                    terms,
                    side="right" if index == 0 else "left",
                )
                rng = seeded_random("voice-blind-v3-names", locale, type_id, index)
                name = rng.choice(NAMES[locale][values["patientGender"]])
                values["patientName"] = name
                spoken["patientName"] = name
                included = FIELD_IDS if index == 0 else PARTIAL_FIELDS
                tail = [field for field in included if field != "examinationDescription"]
                rotation = rng.randrange(len(tail))
                order = ("examinationDescription", *(tail[rotation:] + tail[:rotation]))
                cases.append(
                    render_case(
                        split=SPLIT,
                        locale=locale,
                        type_id=type_id,
                        index=index,
                        scenario="complete" if index == 0 else "partial",
                        values=values,
                        spoken=spoken,
                        facts=facts,
                        included=included,
                        order=order,
                        separator="; ",
                    )
                )
    if len(cases) != len(type_ids) * 4 or len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Blind corpus is not balanced by locale, type and scenario")
    return cases


def spoken_segments(case: dict[str, Any]) -> list[str]:
    locale = case["locale"]

    def pronounce_number(match: re.Match[str]) -> str:
        return _spoken_number(match.group(), locale)

    labels = dict(zip(FIELD_IDS, LABELS[locale], strict=True))
    sources: dict[str, str] = case["expectedSourceQuotes"]
    field_order = ["examinationDescription"]
    for part in case["spokenText"].split("; "):
        label = part.split(":", 1)[0]
        field = next((key for key, value in labels.items() if value == label), None)
        if field is None:
            raise ValueError(f"Unknown blind label in {case['id']}: {label}")
        if field != "examinationDescription":
            field_order.append(field)
    if len(field_order) != len(sources) or set(field_order) != set(sources):
        raise ValueError(f"Audio fields differ from gold in {case['id']}")
    segments = []
    for field in field_order:
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
    return segments


def _validated_existing(
    manifest_path: Path, cases: list[dict[str, Any]], hashes: dict[str, str]
) -> dict[str, Any] | None:
    if not manifest_path.exists():
        return None
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    valid = (
        manifest.get("mode") == MODE
        and manifest.get("split") == SPLIT
        and all(manifest.get(key) == value for key, value in hashes.items())
        and [entry["caseId"] for entry in manifest.get("entries", [])] == [case["id"] for case in cases]
        and all(
            entry["status"] == "ok"
            and entry["ttsText"] == " ".join(spoken_segments(case))
            and all(
                file_sha256(ROOT / entry[variant]["path"]) == entry[variant]["sha256"] for variant in ("clean", "noisy")
            )
            for entry, case in zip(manifest.get("entries", []), cases, strict=True)
        )
    )
    if not valid:
        raise ValueError("Frozen blind audio differs; create a new version instead")
    return manifest


def build_blind() -> dict[str, Any]:
    write_corpus(TEXT_OUTPUT_DIR)
    cases = make_cases()
    corpus_bytes = jsonl_bytes(cases)
    if CORPUS_PATH.exists():
        if CORPUS_PATH.read_bytes() != corpus_bytes:
            raise ValueError("Frozen blind text differs; create a new version instead")
    else:
        CORPUS_PATH.write_bytes(corpus_bytes)
    regression_hash = file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl")
    hashes = {
        "regressionSha256": regression_hash,
        "voiceBlindSha256": file_sha256(CORPUS_PATH),
        "generatorSourceSha256": file_sha256(SOURCE),
        "synthesizerSourceSha256": file_sha256(SWIFT_SOURCE),
        "noiseSourceSha256": file_sha256(NOISE_SOURCE),
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    existing = _validated_existing(manifest_path, cases, hashes)
    if existing is not None:
        return existing

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    scripts = {case["id"]: spoken_segments(case) for case in cases}
    jobs = []
    for case in cases:
        segments = scripts[case["id"]]
        midpoint = len(segments) // 2
        for part, piece in enumerate((segments[:midpoint], segments[midpoint:])):
            jobs.append(
                {
                    "id": f"{case['id']}/{part}",
                    "locale": case["locale"],
                    "voiceIdentifier": VOICES[case["locale"]][int(case["scenario"] == "partial")],
                    "spokenText": " ".join(piece),
                    "outputPath": str((OUTPUT_DIR / "segments" / f"{case['id']}-{part}.wav").resolve()),
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
            str(SWIFT_SOURCE),
            str(jobs_path),
            str(results_path),
        ],
        check=True,
    )
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [result["id"] for result in results] != [job["id"] for job in jobs]:
        raise ValueError("Blind synthesis results differ from requested jobs")
    by_id = {result["id"]: result for result in results}
    entries = []
    for case in cases:
        case_id = case["id"]
        parts = [by_id[f"{case_id}/{part}"] for part in (0, 1)]
        voice = VOICES[case["locale"]][int(case["scenario"] == "partial")]
        script = " ".join(scripts[case_id])
        entry = {
            "caseId": case_id,
            "locale": case["locale"],
            "examinationTypeId": case["examinationTypeId"],
            "scenario": case["scenario"],
            "ttsText": script,
            "werReference": script,
            "voiceIdentifier": voice,
            "status": "ok" if all(part["status"] == "ok" for part in parts) else "failed",
        }
        if entry["status"] == "ok":
            clean = OUTPUT_DIR / "clean" / f"{case_id}.wav"
            try:
                if any(part["voiceIdentifier"] != voice for part in parts):
                    raise ValueError("Unexpected synthesis voice")
                merge_segments([OUTPUT_DIR / "segments" / f"{case_id}-{part}.wav" for part in (0, 1)], clean)
                entry["clean"] = {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)}
                noisy = OUTPUT_DIR / "noisy" / clean.name
                add_reproducible_noise(clean, noisy, f"blind-v3-{case_id}")
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
        "split": SPLIT,
        "requestedCases": len(entries),
        "synthesizedCases": sum(entry["status"] == "ok" for entry in entries),
        **hashes,
        "fieldPauseMs": FIELD_PAUSE_MS,
        "noiseProfile": NOISE_PROFILE,
        "referenceKind": "intended-tts-words-not-audited-human-transcription",
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Freeze independent synthetic voice forms and WAV")
    parser.parse_args()
    manifest = build_blind()
    print(f"Synthesized {manifest['synthesizedCases']}/{manifest['requestedCases']} blind cases")
    if manifest["synthesizedCases"] != manifest["requestedCases"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
