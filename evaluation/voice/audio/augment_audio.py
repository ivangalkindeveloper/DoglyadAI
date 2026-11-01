from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import random
import sys
import wave
from pathlib import Path
from typing import Any

from evaluation.voice.datasets.generate import file_sha256


def augment_audio(
    source: Path, destination: Path, *, factor: str, value: float, family_id: str, seed: int = 20261025
) -> dict[str, Any]:
    """One isolated acoustic change per file; preserve the parent family/split."""
    if destination.exists():
        raise FileExistsError(destination)
    if not family_id or not math.isfinite(value):
        raise ValueError("A family ID and finite parameter are required")
    with wave.open(str(source), "rb") as audio:
        if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or audio.getcomptype() != "NONE":
            raise ValueError("Expected mono PCM16 WAV")
        rate = audio.getframerate()
        samples = array.array("h", audio.readframes(audio.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        raise ValueError("Empty WAV")
    signal = list(samples)
    metadata: dict[str, Any] = {
        "schemaVersion": 2,
        "parentAudioSha256": file_sha256(source),
        "familyId": family_id,
        "factor": factor,
        "value": value,
        "seed": seed,
    }
    if factor == "whiteNoiseSNR":
        if not -10 <= value <= 60:
            raise ValueError("SNR outside the supported diagnostic range")
        rms = math.sqrt(sum(sample * sample for sample in signal) / len(signal))
        if rms == 0:
            raise ValueError("SNR is undefined for a silent source")
        rng = random.Random(int.from_bytes(hashlib.sha256(f"{seed}:{family_id}".encode()).digest()[:8], "big"))
        noise = [rng.gauss(0, 1) for _ in signal]
        noise_rms = math.sqrt(sum(sample * sample for sample in noise) / len(noise))
        scale = rms / (10 ** (value / 20)) / noise_rms
        transformed = [round(sample + noise[index] * scale) for index, sample in enumerate(signal)]
        actual_noise_rms = math.sqrt(sum((a - b) ** 2 for a, b in zip(transformed, signal, strict=True)) / len(signal))
        metadata["measuredSNRDb"] = 20 * math.log10(rms / actual_noise_rms) if actual_noise_rms else None
    elif factor == "gainDb":
        if not -40 <= value <= 12:
            raise ValueError("Gain outside the supported range")
        transformed = [round(sample * 10 ** (value / 20)) for sample in signal]
    elif factor == "paddingMs":
        if not 0 <= value <= 10000:
            raise ValueError("Padding outside the supported range")
        padding = [0] * round(rate * value / 1000)
        transformed = padding + signal + padding
    elif factor == "echoDelayMs":
        if not 1 <= value <= 1000:
            raise ValueError("Echo delay outside the supported range")
        delay = max(1, round(rate * value / 1000))
        transformed = [
            round(
                (signal[index] if index < len(signal) else 0)
                + 0.15 * (signal[index - delay] if 0 <= index - delay < len(signal) else 0)
            )
            for index in range(len(signal) + delay)
        ]
        metadata["echoGain"] = 0.15
    else:
        raise ValueError("Unknown acoustic factor")
    if any(not -32768 <= sample <= 32767 for sample in transformed):
        raise ValueError("Augmentation would clip; choose another source/parameter, do not silently change gain")
    encoded = array.array("h", transformed)
    if sys.byteorder != "little":
        encoded.byteswap()
    # Exclusive creation prevents accidental replacement of frozen recordings.
    with destination.open("xb") as target:
        with wave.open(target, "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(rate)
            audio.writeframes(encoded.tobytes())
    metadata.update(
        audioSha256=file_sha256(destination),
        durationSeconds=len(transformed) / rate,
        sampleRate=rate,
        isSyntheticAcousticCondition=True,
    )
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(description="Create one reproducible isolated acoustic diagnostic")
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--factor", choices=("whiteNoiseSNR", "gainDb", "paddingMs", "echoDelayMs"), required=True)
    parser.add_argument("--value", type=float, required=True)
    parser.add_argument("--family-id", required=True)
    args = parser.parse_args()
    metadata_path = args.destination.with_suffix(".augmentation.json")
    if metadata_path.exists():
        raise FileExistsError(metadata_path)
    metadata = augment_audio(
        args.source, args.destination, factor=args.factor, value=args.value, family_id=args.family_id
    )
    with metadata_path.open("x", encoding="utf-8") as destination:
        destination.write(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
