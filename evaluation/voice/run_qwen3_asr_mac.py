from __future__ import annotations

import argparse
import json
import math
import time
from pathlib import Path
from typing import Any

import sherpa_onnx
import soundfile as sf
from scipy.signal import resample_poly

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.common import ROOT
from evaluation.voice.generate import file_sha256
from evaluation.voice.spoken_wer import spoken_normalized_wer

MODES = ("guided-format", "reordered-format", "freeform-development")
VARIANTS = ("clean", "noisy")


def run(
    *,
    model_dir: Path,
    mode: str,
    variant: str,
    output: Path,
    locale: str | None = None,
    limit: int | None = None,
    sample_count: int | None = None,
) -> dict[str, Any]:
    if limit is not None and sample_count is not None:
        raise ValueError("Choose either the first cases or a spread sample")
    manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    model = sherpa_onnx.OfflineRecognizer.from_qwen3_asr(
        conv_frontend=str(model_dir / "conv_frontend.onnx"),
        encoder=str(model_dir / "encoder.int8.onnx"),
        decoder=str(model_dir / "decoder.int8.onnx"),
        tokenizer=str(model_dir / "tokenizer"),
        num_threads=4,
        max_new_tokens=256,
    )
    entries = [entry for entry in manifest["entries"] if locale is None or entry["locale"] == locale]
    if limit is not None:
        entries = entries[:limit]
    if sample_count is not None:
        if sample_count < 1 or sample_count > len(entries):
            raise ValueError("Sample count must fit the selected audio set")
        entries = [
            entries[round(index * (len(entries) - 1) / max(sample_count - 1, 1))] for index in range(sample_count)
        ]
    report: dict[str, Any] = {
        "schemaVersion": 1,
        "platform": "macOS",
        "recognizer": "sherpa-onnx Qwen3-ASR 0.6B int8 on Mac",
        "modelDir": model_dir.name,
        "audioMode": mode,
        "audioVariant": variant,
        "audioManifestSha256": file_sha256(manifest_path),
        "results": [],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    for index, entry in enumerate(entries, start=1):
        wav = ROOT / entry[variant]["path"]
        if file_sha256(wav) != entry[variant]["sha256"]:
            raise ValueError(f"WAV differs from manifest: {entry['caseId']}")
        audio, sample_rate = sf.read(wav, dtype="float32")
        if audio.ndim != 1:
            raise ValueError(f"Expected mono PCM: {wav}")
        if sample_rate != 16000:
            divisor = math.gcd(sample_rate, 16000)
            audio = resample_poly(audio, 16000 // divisor, sample_rate // divisor).astype("float32")
            sample_rate = 16000
        started = time.monotonic()
        stream = model.create_stream()
        stream.accept_waveform(sample_rate, audio)
        model.decode_stream(stream)
        transcript = stream.result.text.strip()
        elapsed = time.monotonic() - started
        row = {
            "caseId": entry["caseId"],
            "locale": entry["locale"],
            "variant": variant,
            "status": "ok" if transcript else "failed",
            "rawText": transcript,
            "correctedText": transcript,
            "seconds": elapsed,
        }
        if transcript:
            row["rawWER"] = spoken_normalized_wer(entry["ttsText"], transcript, entry["locale"])
            row["correctedWER"] = row["rawWER"]
        report["results"].append(row)
        temporary = output.with_suffix(output.suffix + ".tmp")
        temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(output)
        print(f"Qwen3-ASR {mode}/{variant}: {index}/{len(entries)} ({elapsed:.1f}s)", flush=True)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Screen cross-platform Qwen3-ASR on the voice WAV corpus")
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--mode", choices=MODES, required=True)
    parser.add_argument("--variant", choices=VARIANTS, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--locale", choices=("en", "ru"))
    parser.add_argument("--sample-count", type=int)
    args = parser.parse_args()
    run(
        model_dir=args.model_dir,
        mode=args.mode,
        variant=args.variant,
        output=args.output,
        locale=args.locale,
        limit=args.limit,
        sample_count=args.sample_count,
    )


if __name__ == "__main__":
    main()
