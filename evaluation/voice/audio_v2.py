from __future__ import annotations

import argparse
import json
import subprocess
import wave
from pathlib import Path
from typing import Any

from evaluation.voice.audio import (
    AUDIO_OUTPUT_DIR,
    NOISE_PROFILE,
    SWIFT_SOURCE,
    add_reproducible_noise,
    select_cases,
    wav_metadata,
)
from evaluation.voice.audio_script_v2 import make_audio_script, make_audio_segments
from evaluation.voice.common import ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256, write_corpus

MODE = "extended-v2"
SCRIPT_SOURCE = ROOT / "evaluation/voice/audio_script_v2.py"
NOISE_SOURCE = ROOT / "evaluation/voice/audio.py"
GENERATOR_SOURCE = ROOT / "evaluation/voice/audio_v2.py"
FIELD_PAUSE_MS = 180


def merge_segments(sources: list[Path], destination: Path) -> None:
    if len(sources) != 2:
        raise ValueError("A complete v2 dictation needs both audio segments")
    destination.parent.mkdir(parents=True, exist_ok=True)
    sample_rate: int | None = None
    chunks: list[bytes] = []
    for source in sources:
        with wave.open(str(source), "rb") as wav:
            if wav.getnchannels() != 1 or wav.getsampwidth() != 2 or wav.getcomptype() != "NONE":
                raise ValueError(f"Invalid PCM16 segment: {source}")
            if sample_rate is not None and sample_rate != wav.getframerate():
                raise ValueError(f"Segment sample rates differ: {source}")
            sample_rate = wav.getframerate()
            chunks.append(wav.readframes(wav.getnframes()))
    if sample_rate is None or not all(chunks):
        raise ValueError("Empty v2 audio segment")
    silence = b"\x00\x00" * round(sample_rate * FIELD_PAUSE_MS / 1000)
    with wave.open(str(destination), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(chunks[0] + silence + chunks[1])


def _existing_manifest(
    path: Path, cases: list[dict[str, Any]], scripts: list[str], regression_hash: str
) -> dict[str, Any] | None:
    if not path.exists():
        return None
    manifest = json.loads(path.read_text(encoding="utf-8"))
    valid = (
        manifest.get("schemaVersion") == 2
        and manifest.get("mode") == MODE
        and manifest.get("regressionSha256") == regression_hash
        and manifest.get("scriptSourceSha256") == file_sha256(SCRIPT_SOURCE)
        and manifest.get("synthesizerSourceSha256") == file_sha256(SWIFT_SOURCE)
        and manifest.get("noiseSourceSha256") == file_sha256(NOISE_SOURCE)
        and manifest.get("generatorSourceSha256") == file_sha256(GENERATOR_SOURCE)
        and manifest.get("fieldPauseMs") == FIELD_PAUSE_MS
        and manifest.get("requestedCases") == len(cases)
        and [entry["caseId"] for entry in manifest.get("entries", [])] == [case["id"] for case in cases]
        and [entry.get("ttsText") for entry in manifest.get("entries", [])] == scripts
        and [entry.get("werReference") for entry in manifest.get("entries", [])] == scripts
    )
    if valid:
        for entry in manifest["entries"]:
            if entry["status"] != "ok":
                valid = False
                break
            for variant in ("clean", "noisy"):
                audio = entry[variant]
                if file_sha256(ROOT / audio["path"]) != audio["sha256"]:
                    valid = False
                    break
            if not valid:
                break
    if not valid:
        raise ValueError(f"Existing v2 audio changed or incomplete: {path}; use --force to regenerate")
    return manifest


def build_audio_v2(*, limit: int | None = None, force: bool = False) -> dict[str, Any]:
    write_corpus(TEXT_OUTPUT_DIR)
    cases = [
        json.loads(line) for line in (TEXT_OUTPUT_DIR / "regression.jsonl").read_text(encoding="utf-8").splitlines()
    ]
    selected = select_cases(cases, "extended")
    if limit is not None:
        if limit < 1:
            raise ValueError("Limit must be positive")
        selected = selected[:limit]
    scripts = [make_audio_script(case) for case in selected]
    directory = AUDIO_OUTPUT_DIR / (MODE if limit is None else f"{MODE}-smoke-{limit}")
    directory.mkdir(parents=True, exist_ok=True)
    manifest_path = directory / "manifest.json"
    regression_hash = file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl")
    if not force:
        existing = _existing_manifest(manifest_path, selected, scripts, regression_hash)
        if existing is not None:
            return existing

    jobs = []
    for case in selected:
        segments = make_audio_segments(case)
        for part, field_segments in enumerate((segments[:4], segments[4:])):
            jobs.append(
                {
                    "id": f"{case['id']}/{part}",
                    "locale": case["locale"],
                    "spokenText": " ".join(field_segments),
                    "outputPath": str((directory / "segments" / f"{case['id']}-{part}.wav").resolve()),
                }
            )
    jobs_path = directory / "jobs.json"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    executable = AUDIO_OUTPUT_DIR / "voice-audio-synth"
    subprocess.run(
        [
            "swiftc",
            "-O",
            "-module-cache-path",
            str(AUDIO_OUTPUT_DIR / "swift-module-cache"),
            str(SWIFT_SOURCE),
            "-o",
            str(executable),
        ],
        check=True,
    )
    results_path = directory / "synthesis-results.jsonl"
    subprocess.run([str(executable), str(jobs_path), str(results_path)], check=True)
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [item["id"] for item in results] != [job["id"] for job in jobs]:
        raise ValueError("Synthesizer results do not match requested cases")
    by_id = {result["id"]: result for result in results}

    entries: list[dict[str, Any]] = []
    for case, script in zip(selected, scripts, strict=True):
        parts = [by_id[f"{case['id']}/{part}"] for part in (0, 1)]
        entry: dict[str, Any] = {
            "caseId": case["id"],
            "locale": case["locale"],
            "examinationTypeId": case["examinationTypeId"],
            "scenario": case["scenario"],
            "ttsText": script,
            "werReference": script,
            "status": "ok" if all(part["status"] == "ok" for part in parts) else "failed",
            "voiceIdentifier": parts[0]["voiceIdentifier"],
        }
        if entry["status"] == "ok":
            clean = directory / "clean" / f"{case['id']}.wav"
            try:
                if parts[0]["voiceIdentifier"] != parts[1]["voiceIdentifier"]:
                    raise ValueError("Segment voices differ")
                merge_segments([directory / "segments" / f"{case['id']}-{part}.wav" for part in (0, 1)], clean)
                entry["clean"] = {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)}
                noisy = directory / "noisy" / clean.name
                add_reproducible_noise(clean, noisy, case["id"])
                entry["noisy"] = {"path": str(noisy.relative_to(ROOT)), **wav_metadata(noisy)}
            except (OSError, ValueError) as error:
                entry["status"] = "failed"
                entry["reason"] = f"Invalid synthesized WAV: {error}"
                entry.pop("clean", None)
                entry.pop("noisy", None)
        else:
            entry["reason"] = "; ".join(
                part.get("reason") or part["status"] for part in parts if part["status"] != "ok"
            )
        entries.append(entry)

    manifest = {
        "schemaVersion": 2,
        "mode": MODE,
        "requestedCases": len(selected),
        "synthesizedCases": sum(entry["status"] == "ok" for entry in entries),
        "regressionSha256": regression_hash,
        "scriptSourceSha256": file_sha256(SCRIPT_SOURCE),
        "synthesizerSourceSha256": file_sha256(SWIFT_SOURCE),
        "noiseSourceSha256": file_sha256(NOISE_SOURCE),
        "generatorSourceSha256": file_sha256(GENERATOR_SOURCE),
        "fieldPauseMs": FIELD_PAUSE_MS,
        "ttsRate": 0.5,
        "noiseProfile": NOISE_PROFILE,
        "referenceKind": "intended-tts-words-not-audited-human-transcription",
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Synthesize complete spoken dictations for v2 voice evaluation")
    parser.add_argument("--limit", type=int, help="Create a separate local smoke-test snapshot")
    parser.add_argument("--force", action="store_true", help="Replace the existing v2 audio snapshot")
    args = parser.parse_args()
    manifest = build_audio_v2(limit=args.limit, force=args.force)
    directory = AUDIO_OUTPUT_DIR / (MODE if args.limit is None else f"{MODE}-smoke-{args.limit}")
    print(f"Synthesized {manifest['synthesizedCases']}/{manifest['requestedCases']} cases")
    print(f"Manifest: {directory / 'manifest.json'}")
    if manifest["synthesizedCases"] != manifest["requestedCases"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
