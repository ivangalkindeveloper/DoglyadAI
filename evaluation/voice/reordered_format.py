from __future__ import annotations

import json
import shutil
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR, NOISE_PROFILE, add_reproducible_noise, wav_metadata
from evaluation.voice.common import ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256, jsonl_bytes, write_corpus
from evaluation.voice.voice_blind_v3 import (
    CORPUS_PATH,
    OUTPUT_DIR as SOURCE_AUDIO_DIR,
    SOURCE as CORPUS_SOURCE,
    SWIFT_SOURCE,
    make_cases,
    spoken_segments,
)

MODE = "reordered-format"
OUTPUT_DIR = AUDIO_OUTPUT_DIR / MODE
SOURCE = ROOT / "evaluation/voice/reordered_format.py"
NOISE_SOURCE = ROOT / "evaluation/voice/audio.py"


def reordered_cases() -> list[dict[str, Any]]:
    write_corpus(TEXT_OUTPUT_DIR)
    cases = make_cases()
    if not CORPUS_PATH.exists() or CORPUS_PATH.read_bytes() != jsonl_bytes(cases):
        raise ValueError("Frozen reordered corpus differs from voice-blind-v3")
    return cases


def build_audio() -> dict[str, Any]:
    cases = reordered_cases()
    source_manifest_path = SOURCE_AUDIO_DIR / "manifest.json"
    source_manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    if (
        source_manifest.get("mode") != "voice-blind-v3"
        or source_manifest.get("voiceBlindSha256") != file_sha256(CORPUS_PATH)
        or source_manifest.get("regressionSha256") != file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl")
        or source_manifest.get("generatorSourceSha256") != file_sha256(CORPUS_SOURCE)
        or source_manifest.get("synthesizerSourceSha256") != file_sha256(SWIFT_SOURCE)
        or [entry["caseId"] for entry in source_manifest["entries"]] != [case["id"] for case in cases]
    ):
        raise ValueError("Frozen source audio does not match reordered cases")

    hashes = {
        "regressionSha256": file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl"),
        "voiceBlindSha256": file_sha256(CORPUS_PATH),
        "sourceAudioManifestSha256": file_sha256(source_manifest_path),
        "generatorSourceSha256": file_sha256(SOURCE),
        "noiseSourceSha256": file_sha256(NOISE_SOURCE),
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    if manifest_path.exists():
        previous = json.loads(manifest_path.read_text(encoding="utf-8"))
        valid = (
            previous.get("schemaVersion") == 2
            and previous.get("mode") == MODE
            and previous.get("split") == "voiceBlind"
            and all(previous.get(key) == value for key, value in hashes.items())
            and [entry["caseId"] for entry in previous["entries"]] == [case["id"] for case in cases]
            and all(
                entry["status"] == "ok"
                and entry["ttsText"] == " ".join(spoken_segments(case))
                and all(
                    file_sha256(ROOT / entry[variant]["path"]) == entry[variant]["sha256"]
                    for variant in ("clean", "noisy")
                )
                for entry, case in zip(previous["entries"], cases, strict=True)
            )
        )
        if not valid:
            raise ValueError("Reordered audio differs from its manifest; create a new version")
        return previous

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    entries = []
    for case, source in zip(cases, source_manifest["entries"], strict=True):
        script = " ".join(spoken_segments(case))
        original = ROOT / source["clean"]["path"]
        if (
            source["status"] != "ok"
            or source["ttsText"] != script
            or file_sha256(original) != source["clean"]["sha256"]
        ):
            raise ValueError(f"Frozen clean audio differs from its source: {case['id']}")
        clean = OUTPUT_DIR / "clean" / f"{case['id']}.wav"
        clean.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(original, clean)
        noisy = OUTPUT_DIR / "noisy" / clean.name
        add_reproducible_noise(clean, noisy, f"reordered-format-{case['id']}")
        entries.append(
            {
                "caseId": case["id"],
                "locale": case["locale"],
                "examinationTypeId": case["examinationTypeId"],
                "scenario": case["scenario"],
                "ttsText": script,
                "werReference": script,
                "voiceIdentifier": source["voiceIdentifier"],
                "status": "ok",
                "clean": {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)},
                "noisy": {"path": str(noisy.relative_to(ROOT)), **wav_metadata(noisy)},
            }
        )
    manifest = {
        "schemaVersion": 2,
        "mode": MODE,
        "split": "voiceBlind",
        "suite": "reorderedFormat",
        "requestedCases": len(entries),
        "noiseProfile": NOISE_PROFILE,
        "referenceKind": "intended-tts-words-not-audited-human-transcription",
        **hashes,
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    manifest = build_audio()
    print(f"Reordered format: {len(manifest['entries'])} clean and noisy WAV pairs")


if __name__ == "__main__":
    main()
