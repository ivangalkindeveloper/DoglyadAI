from __future__ import annotations

import argparse
import json
import math
import os
import platform
import time
from datetime import datetime, timezone
from importlib.metadata import version
from pathlib import Path
from typing import Any, Callable

from evaluation.voice.common import ROOT
from evaluation.voice.datasets.generate import file_sha256

MODEL_IDS = {
    "gigaam": "ai-sage/GigaAM-v3",
    "medasr": "google/medasr",
    "nemotron": "nvidia/nemotron-3.5-asr-streaming-0.6b",
    "canary": "nvidia/canary-1b-v2",
}


def _load_model(name: str, revision: str, cache: Path, device: str) -> tuple[Callable[..., str], dict[str, Any]]:
    import torch
    from transformers import AutoModel, AutoProcessor

    model_id = MODEL_IDS[name]
    arguments = {"revision": revision, "cache_dir": str(cache)}
    if name == "gigaam":
        import imageio_ffmpeg

        tools_directory = cache.resolve() / "tools"
        tools_directory.mkdir(parents=True, exist_ok=True)
        ffmpeg = tools_directory / "ffmpeg"
        if not ffmpeg.exists():
            ffmpeg.symlink_to(imageio_ffmpeg.get_ffmpeg_exe())
        os.environ["PATH"] = str(tools_directory) + os.pathsep + os.environ["PATH"]
        model = AutoModel.from_pretrained(model_id, trust_remote_code=True, **arguments).to(device).eval()

        def transcribe(audio: Any, locale: str, audio_path: str) -> str:
            # V3's short-form API is limited to 25 seconds. Split only longer
            # files at the quietest 200 ms window between 15 and 20 seconds.
            # The segmentation is acoustic-only and never sees the reference.
            import numpy as np
            import soundfile as sf
            import tempfile

            parts: list[str] = []
            remaining = audio
            with tempfile.TemporaryDirectory(prefix="gigaam-") as directory:
                while len(remaining) > 25 * 16000:
                    candidates = range(15 * 16000, 20 * 16000, 1600)
                    cut = min(candidates, key=lambda p: float(np.mean(remaining[p : p + 3200] ** 2))) + 1600
                    path = str(Path(directory) / f"{len(parts)}.wav")
                    sf.write(path, remaining[:cut], 16000, subtype="PCM_16")
                    parts.append(model.transcribe(path))
                    remaining = remaining[cut:]
                path = str(Path(directory) / "last.wav")
                sf.write(path, remaining, 16000, subtype="PCM_16")
                parts.append(model.transcribe(path))
            return " ".join(parts)

        return transcribe, {"longAudio": "quietest 200ms between 15-20s; no overlap; only files over 25s"}

    processor = AutoProcessor.from_pretrained(model_id, **arguments)
    import transformers

    model_type = getattr(
        transformers,
        {"medasr": "AutoModelForCTC", "nemotron": "AutoModelForRNNT", "canary": "AutoModelForSpeechSeq2Seq"}[name],
    )
    model = model_type.from_pretrained(model_id, **arguments).to(device).eval()

    def transcribe(audio: Any, locale: str, audio_path: str) -> str:
        if name == "canary":
            inputs = processor.apply_transcription_request(audio=audio, source_language=locale)
        elif name == "nemotron":
            inputs = processor(
                audio, sampling_rate=16000, language={"en": "en-US", "ru": "ru-RU"}[locale], return_tensors="pt"
            )
        else:
            inputs = processor(audio, sampling_rate=16000, return_tensors="pt")
        inputs = inputs.to(device)
        with torch.inference_mode():
            if name == "medasr":
                outputs = model(**inputs).logits.argmax(dim=-1)
                return processor.batch_decode(outputs)[0]
            outputs = model.generate(**inputs, max_new_tokens=512) if name == "canary" else model.generate(**inputs)
            decoded = processor.batch_decode(getattr(outputs, "sequences", outputs), skip_special_tokens=True)
            return decoded[0]

    return transcribe, {
        "decoding": "greedy",
        "audioMode": "complete file",
        "language": "explicit, except English-only MedASR",
        "maxNewTokens": 512 if name == "canary" else None,
    }


def run_server_asr(
    *,
    manifest_path: Path,
    output: Path,
    model: str,
    cache: Path,
    device: str,
    revision: str | None = None,
    limit: int | None = None,
    locale: str | None = None,
    threads: int = 4,
    is_retry_failed: bool = False,
) -> dict[str, Any]:
    import numpy as np
    import psutil
    import soundfile as sf
    import torch
    from huggingface_hub import HfApi
    from scipy.signal import resample_poly

    torch.set_num_threads(threads)
    os.environ.setdefault("HF_MODULES_CACHE", str(cache / "modules"))
    cases = json.loads(manifest_path.read_text(encoding="utf-8"))["cases"]
    if locale:
        cases = [row for row in cases if row["locale"] == locale]
    if limit is not None:
        # Spread the pilot over both languages, styles, durations and variants.
        cases = [cases[round(i * (len(cases) - 1) / max(limit - 1, 1))] for i in range(min(limit, len(cases)))]
    output.parent.mkdir(parents=True, exist_ok=True)
    settings_path = output.with_suffix(".settings.json")
    settings: dict[str, Any] = {
        "model": model,
        "modelId": MODEL_IDS[model],
        "manifestSha256": file_sha256(manifest_path),
        "sourceSha256": file_sha256(Path(__file__)),
        "device": device,
        "threads": threads,
        "platform": platform.platform(),
        "packages": {name: version(name) for name in ("torch", "transformers", "numpy", "soundfile")},
        "caseIds": [case["id"] for case in cases],
    }
    if settings_path.exists():
        previous = json.loads(settings_path.read_text(encoding="utf-8"))
        if any(previous[key] != settings[key] for key in settings):
            raise ValueError("Resume settings differ; choose a new output file")
        revision = previous["revision"]
    else:
        info = HfApi().model_info(MODEL_IDS[model], revision=revision or ("e2e_rnnt" if model == "gigaam" else "main"))
        revision = info.sha
        settings["revision"] = revision
        settings["startedAt"] = datetime.now(timezone.utc).isoformat()
        settings_path.write_text(json.dumps(settings, indent=2) + "\n", encoding="utf-8")
    previous_rows = (
        [json.loads(line) for line in output.read_text(encoding="utf-8").splitlines()] if output.exists() else []
    )
    complete = {row["id"] for row in previous_rows if row["status"] == "ok" or not is_retry_failed}
    if len(complete) == len(cases):
        return {"cases": len(cases), "alreadyComplete": True}
    started = time.monotonic()
    transcribe, configuration = _load_model(model, revision, cache, device)
    load_seconds = time.monotonic() - started
    process = psutil.Process()
    for index, case in enumerate(cases, start=1):
        if case["id"] in complete:
            continue
        path = ROOT / case["audioPath"]
        if file_sha256(path) != case["audioSha256"]:
            raise ValueError(f"Audio changed: {case['id']}")
        audio, sample_rate = sf.read(path, dtype="float32", always_2d=False)
        if audio.ndim != 1:
            raise ValueError("Expected mono audio")
        if sample_rate != 16000:
            divisor = math.gcd(sample_rate, 16000)
            audio = resample_poly(audio, 16000 // divisor, sample_rate // divisor).astype(np.float32)
        row: dict[str, Any] = {
            "id": case["id"],
            "caseId": case["caseId"],
            "mode": case["mode"],
            "variant": case["variant"],
            "locale": case["locale"],
            "audioSha256": case["audioSha256"],
            "durationSeconds": case["durationSeconds"],
            "model": model,
        }
        started = time.monotonic()
        try:
            with torch.inference_mode():
                text = transcribe(audio, case["locale"], str(path)).strip()
            if not text:
                raise ValueError("Empty transcript")
            row.update(status="ok", rawText=text, correctedText=text)
        except Exception as error:
            row.update(status="failed", errorType=type(error).__name__, reason=str(error)[:1000])
        row.update(seconds=time.monotonic() - started, processRSSBytes=process.memory_info().rss)
        with output.open("a", encoding="utf-8") as destination:
            destination.write(json.dumps(row, ensure_ascii=False) + "\n")
            destination.flush()
            os.fsync(destination.fileno())
        print(f"{model}: {index}/{len(cases)} {case['locale']} {row['status']} {row['seconds']:.2f}s", flush=True)
    summary = {"cases": len(cases), "modelLoadSeconds": load_seconds, "configuration": configuration}
    output.with_suffix(".execution.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Run native ASR checkpoints against the frozen paired voice matrix")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--model", choices=tuple(MODEL_IDS), required=True)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--device", choices=("cpu", "mps", "cuda"), default="cpu")
    parser.add_argument("--locale", choices=("ru", "en"))
    parser.add_argument("--revision")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--retry-failed", action="store_true")
    args = parser.parse_args()
    print(
        json.dumps(
            run_server_asr(
                manifest_path=args.manifest,
                output=args.output,
                model=args.model,
                cache=args.cache,
                device=args.device,
                revision=args.revision,
                limit=args.limit,
                locale=args.locale,
                threads=args.threads,
                is_retry_failed=args.retry_failed,
            )
        )
    )


if __name__ == "__main__":
    main()
