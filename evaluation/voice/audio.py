from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import random
import subprocess
import sys
import wave
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256, write_corpus

AUDIO_OUTPUT_DIR = ROOT / "build/voice-eval/audio"
SWIFT_SOURCE = ROOT / "evaluation/voice/AudioSynth/main.swift"
QUICK_SCENARIOS = ("complete",)
EXTENDED_SCENARIOS = ("complete", "reordered", "spoken_measurement", "self_correction")
NOISE_PROFILE = {"snrDb": 25, "gain": 0.83, "echoDelayMs": 37, "echoGain": 0.08, "tempo": 0.97, "silenceMs": 200}


def select_cases(cases: list[dict[str, Any]], mode: str) -> list[dict[str, Any]]:
    scenarios = QUICK_SCENARIOS if mode == "quick" else EXTENDED_SCENARIOS
    selected = [case for case in cases if case["scenario"] in scenarios]
    keys = [(case["locale"], case["examinationTypeId"], case["scenario"]) for case in selected]
    if len(keys) != len(set(keys)) or len(selected) != 62 * len(scenarios):
        raise ValueError("Audio selection must contain each requested scenario for every type and locale")
    return selected


def add_reproducible_noise(source: Path, destination: Path, case_id: str) -> None:
    with wave.open(str(source), "rb") as wav:
        channels = wav.getnchannels()
        sample_rate = wav.getframerate()
        if wav.getsampwidth() != 2 or channels != 1 or wav.getcomptype() != "NONE":
            raise ValueError(f"Expected mono PCM16 WAV: {source}")
        samples = array.array("h", wav.readframes(wav.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        raise ValueError(f"Empty WAV: {source}")

    seed = int.from_bytes(hashlib.sha256(f"voice-noise-v1:{case_id}".encode()).digest()[:8], "big")
    rng = random.Random(seed)
    tempo = NOISE_PROFILE["tempo"]
    adjusted = [
        samples[min(int(index * tempo), len(samples) - 1)] / 32768.0 for index in range(math.ceil(len(samples) / tempo))
    ]
    delay = round(sample_rate * NOISE_PROFILE["echoDelayMs"] / 1000)
    gain = NOISE_PROFILE["gain"]
    signal = [
        gain * (value + NOISE_PROFILE["echoGain"] * (adjusted[index - delay] if index >= delay else 0.0))
        for index, value in enumerate(adjusted)
    ]
    rms = math.sqrt(sum(value * value for value in signal) / len(signal))
    noise_std = rms / (10 ** (NOISE_PROFILE["snrDb"] / 20))
    silence = [0] * round(sample_rate * NOISE_PROFILE["silenceMs"] / 1000)
    processed = array.array(
        "h",
        silence
        + [max(-32768, min(32767, round((value + rng.gauss(0, noise_std)) * 32767))) for value in signal]
        + silence,
    )
    if sys.byteorder != "little":
        processed.byteswap()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(processed.tobytes())


def wav_metadata(path: Path) -> dict[str, Any]:
    with wave.open(str(path), "rb") as wav:
        if wav.getnchannels() != 1 or wav.getsampwidth() != 2 or wav.getnframes() == 0:
            raise ValueError(f"Invalid mono PCM16 WAV: {path}")
        return {
            "sampleRate": wav.getframerate(),
            "frames": wav.getnframes(),
            "durationSeconds": round(wav.getnframes() / wav.getframerate(), 3),
            "sha256": file_sha256(path),
        }


def reuse_existing_audio(
    manifest_path: Path, selected: list[dict[str, Any]], mode: str, regression_hash: str
) -> dict[str, Any] | None:
    if not manifest_path.exists():
        return None
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    valid = (
        manifest.get("mode") == mode
        and manifest.get("requestedCases") == len(selected)
        and manifest.get("regressionSha256") == regression_hash
        and manifest.get("synthesizerSourceSha256") == file_sha256(SWIFT_SOURCE)
        and manifest.get("noiseSourceSha256") == (file_sha256(Path(__file__)) if mode == "extended" else None)
        and manifest.get("ttsRate") == 0.5
        and [entry["caseId"] for entry in manifest.get("entries", [])] == [case["id"] for case in selected]
    )
    variants = ("clean",) if mode == "quick" else ("clean", "noisy")
    if valid:
        for entry in manifest["entries"]:
            if entry["status"] != "ok":
                valid = False
                break
            for variant in variants:
                audio = entry[variant]
                if file_sha256(ROOT / audio["path"]) != audio["sha256"]:
                    valid = False
                    break
            if not valid:
                break
    if not valid:
        raise ValueError(f"Existing audio has changed or is incomplete: {manifest_path}; use --force to regenerate")
    return manifest


def build_audio(
    mode: str, output: Path = AUDIO_OUTPUT_DIR, *, limit: int | None = None, force: bool = False
) -> dict[str, Any]:
    if mode not in ("quick", "extended"):
        raise ValueError(f"Unknown audio mode: {mode}")
    write_corpus(TEXT_OUTPUT_DIR)
    cases = [
        json.loads(line) for line in (TEXT_OUTPUT_DIR / "regression.jsonl").read_text(encoding="utf-8").splitlines()
    ]
    selected = select_cases(cases, mode)
    if limit is not None:
        if limit < 1:
            raise ValueError("Limit must be positive")
        selected = selected[:limit]

    directory = output / mode if limit is None else output / f"{mode}-smoke-{limit}"
    directory.mkdir(parents=True, exist_ok=True)
    manifest_path = directory / "manifest.json"
    regression_hash = file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl")
    if not force:
        existing = reuse_existing_audio(manifest_path, selected, mode, regression_hash)
        if existing is not None:
            return existing
    jobs = [
        {
            "id": case["id"],
            "locale": case["locale"],
            "spokenText": case["spokenText"],
            "outputPath": str((directory / "clean" / f"{case['id']}.wav").resolve()),
        }
        for case in selected
    ]
    jobs_path = directory / "jobs.json"
    jobs_path.write_text(json.dumps(jobs, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    executable = output / "voice-audio-synth"
    subprocess.run(
        [
            "swiftc",
            "-O",
            "-module-cache-path",
            str(output / "swift-module-cache"),
            str(SWIFT_SOURCE),
            "-o",
            str(executable),
        ],
        check=True,
    )
    results_path = directory / "synthesis-results.jsonl"
    subprocess.run([str(executable), str(jobs_path), str(results_path)], check=True)
    results = [json.loads(line) for line in results_path.read_text(encoding="utf-8").splitlines()]
    if [item["id"] for item in results] != [case["id"] for case in selected]:
        raise ValueError("Synthesizer results do not match requested cases")

    entries: list[dict[str, Any]] = []
    for case, result, job in zip(selected, results, jobs, strict=True):
        entry: dict[str, Any] = {
            "caseId": case["id"],
            "locale": case["locale"],
            "examinationTypeId": case["examinationTypeId"],
            "scenario": case["scenario"],
            "status": result["status"],
            "voiceIdentifier": result["voiceIdentifier"],
        }
        if result["status"] == "ok":
            clean = Path(job["outputPath"])
            try:
                entry["clean"] = {"path": str(clean.relative_to(ROOT)), **wav_metadata(clean)}
                if mode == "extended":
                    noisy = directory / "noisy" / clean.name
                    add_reproducible_noise(clean, noisy, case["id"])
                    entry["noisy"] = {"path": str(noisy.relative_to(ROOT)), **wav_metadata(noisy)}
            except (OSError, ValueError) as error:
                entry["status"] = "failed"
                entry["reason"] = f"Invalid synthesized WAV: {error}"
                entry.pop("clean", None)
                entry.pop("noisy", None)
        else:
            entry["reason"] = result["reason"]
        entries.append(entry)

    manifest = {
        "schemaVersion": 1,
        "mode": mode,
        "requestedCases": len(selected),
        "synthesizedCases": sum(entry["status"] == "ok" for entry in entries),
        "regressionSha256": regression_hash,
        "synthesizerSourceSha256": file_sha256(SWIFT_SOURCE),
        "noiseSourceSha256": file_sha256(Path(__file__)) if mode == "extended" else None,
        "ttsRate": 0.5,
        "noiseProfile": NOISE_PROFILE if mode == "extended" else None,
        "entries": entries,
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Synthesize reproducible voice evaluation audio")
    parser.add_argument("--mode", choices=("quick", "extended"), default="quick")
    parser.add_argument("--limit", type=int, help="For local smoke tests; excludes remaining cases from the manifest")
    parser.add_argument("--force", action="store_true", help="Replace the existing audio snapshot")
    args = parser.parse_args()
    manifest = build_audio(args.mode, limit=args.limit, force=args.force)
    print(f"Synthesized {manifest['synthesizedCases']}/{manifest['requestedCases']} cases")
    directory = (
        AUDIO_OUTPUT_DIR / args.mode if args.limit is None else AUDIO_OUTPUT_DIR / f"{args.mode}-smoke-{args.limit}"
    )
    print(f"Manifest: {directory / 'manifest.json'}")
    if manifest["synthesizedCases"] != manifest["requestedCases"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
