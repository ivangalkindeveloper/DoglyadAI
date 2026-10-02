from __future__ import annotations

import argparse
import json
import math
import time
from importlib.metadata import version
from pathlib import Path
from typing import Any

import numpy as np
import soundfile as sf  # type: ignore[import-untyped]
from scipy.signal import resample_poly  # type: ignore[import-untyped]

from evaluation.voice.asr import word_error_rate
from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import LABELS, ROOT
from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.spoken_wer import spoken_normalized_wer

MODELS = {
    "whisper-small-4bit": (
        "mlx-community/whisper-small-mlx-4bit",
        "b60eea21106598b69d5fff2d3502f1e71127c924",
        "weights.npz",
    ),
    "whisper-turbo-4bit": (
        "mlx-community/whisper-large-v3-turbo-4bit",
        "0f058d38170d183f9fdee07908f5b515d91793a8",
        "weights.safetensors",
    ),
}
SAMPLE_RATE = 16_000


def load_waveform(path: Path) -> np.ndarray:
    waveform, sample_rate = sf.read(path, dtype="float32", always_2d=False)
    if waveform.ndim != 1:
        raise ValueError(f"Expected mono audio: {path}")
    if sample_rate != SAMPLE_RATE:
        divisor = math.gcd(sample_rate, SAMPLE_RATE)
        waveform = resample_poly(waveform, SAMPLE_RATE // divisor, sample_rate // divisor)
    return np.asarray(waveform, dtype=np.float32)


def run_whisper(
    *,
    model_path: Path,
    model: str = "whisper-small-4bit",
    mode: str = "extended",
    variant: str = "clean",
    locale: str | None = None,
    limit: int | None = None,
    form_label_prompt: bool = False,
) -> dict[str, Any]:
    import mlx_whisper  # type: ignore[import-not-found]

    if mode not in (
        "quick",
        "extended",
        "extended-v2",
        "voice-holdout",
        "phrase-holdout",
        "voice-blind-v3",
        "guided-format",
        "reordered-format",
        "freeform-development",
    ) or variant not in (
        "clean",
        "noisy",
    ):
        raise ValueError("Unsupported audio mode or variant")
    if mode == "quick" and variant != "clean":
        raise ValueError("Quick corpus has no noisy variant")
    if locale not in (None, "en", "ru"):
        raise ValueError("Unsupported locale")
    if limit is not None and limit < 1:
        raise ValueError("Limit must be positive")
    model_id, model_revision, weights_filename = MODELS[model]
    for filename in ("config.json", weights_filename):
        if not (model_path / filename).is_file():
            raise FileNotFoundError(model_path / filename)

    audio_dir = AUDIO_OUTPUT_DIR / mode
    manifest_path = audio_dir / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest["mode"] != mode:
        raise ValueError("Audio manifest mode does not match requested mode")
    if manifest["regressionSha256"] != file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl"):
        raise ValueError("Audio and regression text hashes differ")
    split = manifest.get("split", "regression")
    if split not in ("regression", "control", "voiceBlind", "freeformDevelopment"):
        raise ValueError("Unsupported audio corpus split")
    if split == "control" and manifest.get("controlSha256") != file_sha256(TEXT_OUTPUT_DIR / "control.jsonl"):
        raise ValueError("Audio and control cases differ")
    if split == "voiceBlind" and manifest.get("voiceBlindSha256") != file_sha256(TEXT_OUTPUT_DIR / "voiceBlind.jsonl"):
        raise ValueError("Audio and blind cases differ")
    if split == "freeformDevelopment" and manifest.get("freeformDevelopmentSha256") != file_sha256(
        TEXT_OUTPUT_DIR / "freeformDevelopment.jsonl"
    ):
        raise ValueError("Audio and freeform development cases differ")
    cases = {
        case["id"]: case
        for case in (
            json.loads(line) for line in (TEXT_OUTPUT_DIR / f"{split}.jsonl").read_text(encoding="utf-8").splitlines()
        )
    }
    entries = [item for item in manifest["entries"] if locale is None or item["locale"] == locale]
    if limit is not None:
        entries = entries[:limit]

    output_dir = audio_dir / model
    if form_label_prompt:
        output_dir /= "form-label-prompt"
    if locale is not None or limit is not None:
        output_dir = output_dir / f"smoke-{locale or 'both'}-{limit or 'all'}"
    output_dir.mkdir(parents=True, exist_ok=True)
    results_path = output_dir / f"{variant}-results.jsonl"
    results: list[dict[str, Any]] = []
    started = time.monotonic()
    with results_path.open("w", encoding="utf-8") as handle:
        for index, entry in enumerate(entries, start=1):
            if entry["status"] != "ok":
                raise ValueError(f"Audio unavailable for {entry['caseId']}")
            audio = entry[variant]
            path = ROOT / audio["path"]
            if file_sha256(path) != audio["sha256"]:
                raise ValueError(f"Audio hash mismatch: {path}")
            case = cases[entry["caseId"]]
            started_case = time.monotonic()
            response = mlx_whisper.transcribe(
                load_waveform(path),
                path_or_hf_repo=str(model_path),
                language=entry["locale"],
                task="transcribe",
                temperature=0,
                condition_on_previous_text=False,
                initial_prompt=", ".join(LABELS[entry["locale"]]) if form_label_prompt else None,
                verbose=None,
            )
            transcript = response["text"].strip()
            reference = entry.get("werReference", case["spokenText"])
            wer = (
                spoken_normalized_wer(reference, transcript, entry["locale"])
                if mode
                in (
                    "extended-v2",
                    "voice-holdout",
                    "phrase-holdout",
                    "voice-blind-v3",
                    "guided-format",
                    "reordered-format",
                    "freeform-development",
                )
                else word_error_rate(reference, transcript)
            )
            item = {
                "caseId": case["id"],
                "locale": case["locale"],
                "variant": variant,
                "status": "ok",
                "rawText": transcript,
                "correctedText": transcript,
                "rawWER": wer,
                "correctedWER": wer,
                "seconds": time.monotonic() - started_case,
            }
            results.append(item)
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
            handle.flush()
            if index % 10 == 0 or index == len(entries):
                print(f"{index}/{len(entries)} WAV; elapsed {time.monotonic() - started:.1f}s", flush=True)

    report = {
        "schemaVersion": 1,
        "platform": "macOS",
        "recognizer": f"MLX {model}",
        "isIOSBaseline": False,
        "modelId": model_id,
        "modelRevision": model_revision,
        "modelConfigSha256": file_sha256(model_path / "config.json"),
        "modelWeightsSha256": file_sha256(model_path / weights_filename),
        "formLabelPrompt": form_label_prompt,
        "dependencyVersions": {name: version(name) for name in ("mlx-whisper", "mlx", "numpy", "scipy", "soundfile")},
        "audioMode": mode,
        "audioVariant": variant,
        "requestedAudioFiles": len(entries),
        "recognizedAudioFiles": len(results),
        "meanRawWER": sum(item["rawWER"] for item in results) / len(results) if results else None,
        "meanCorrectedWER": sum(item["correctedWER"] for item in results) / len(results) if results else None,
        "elapsedSeconds": time.monotonic() - started,
        "audioManifestSha256": file_sha256(manifest_path),
        "sourceSha256": file_sha256(ROOT / "evaluation/voice/whisper_asr.py"),
        "results": results,
    }
    report_path = output_dir / f"{variant}-report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Report: {report_path}")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare MLX Whisper on existing synthetic WAV")
    parser.add_argument("--model-path", type=Path, required=True)
    parser.add_argument("--model", choices=tuple(MODELS), default="whisper-small-4bit")
    parser.add_argument(
        "--mode",
        choices=(
            "quick",
            "extended",
            "extended-v2",
            "voice-holdout",
            "phrase-holdout",
            "voice-blind-v3",
            "guided-format",
            "reordered-format",
            "freeform-development",
        ),
        default="extended",
    )
    parser.add_argument("--variant", choices=("clean", "noisy"), default="clean")
    parser.add_argument("--locale", choices=("en", "ru"))
    parser.add_argument("--limit", type=int)
    parser.add_argument("--form-label-prompt", action="store_true")
    args = parser.parse_args()
    run_whisper(
        model_path=args.model_path,
        model=args.model,
        mode=args.mode,
        variant=args.variant,
        locale=args.locale,
        limit=args.limit,
        form_label_prompt=args.form_label_prompt,
    )


if __name__ == "__main__":
    main()
