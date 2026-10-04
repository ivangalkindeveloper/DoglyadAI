from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from evaluation.voice.audio import AUDIO_OUTPUT_DIR
from evaluation.voice.generate import file_sha256
from evaluation.voice.spoken_wer import spoken_normalized_wer

MODES = ("guided-format", "reordered-format", "freeform-development")
VARIANTS = ("clean", "noisy")


def model_digest(model_dir: Path) -> str:
    digest = hashlib.sha256()
    files = sorted(path for path in model_dir.rglob("*") if path.is_file())
    if not files:
        raise ValueError(f"Parakeet model files are missing: {model_dir}")
    for path in files:
        digest.update(str(path.relative_to(model_dir)).encode())
        digest.update(file_sha256(path).encode())
    return digest.hexdigest()


def run(*, cli: Path, model_dir: Path, source_commit: str, mode: str, variant: str, output: Path) -> dict[str, Any]:
    if not cli.is_file():
        raise ValueError(f"FluidAudio CLI is missing: {cli}")
    manifest_path = AUDIO_OUTPUT_DIR / mode / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest_sha = file_sha256(manifest_path)
    model_sha = model_digest(model_dir)
    report: dict[str, Any] = {
        "schemaVersion": 1,
        "platform": "macOS",
        "recognizer": "FluidAudio Parakeet TDT v3 Core ML on Mac",
        "runnerCommit": source_commit,
        "modelFilesSha256": model_sha,
        "audioMode": mode,
        "audioVariant": variant,
        "audioManifestSha256": manifest_sha,
        "results": [],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    root = Path(__file__).resolve().parents[2]
    with tempfile.TemporaryDirectory(prefix="doglyad-parakeet-") as temporary:
        transcription = Path(temporary) / "result.json"
        for index, entry in enumerate(manifest["entries"], start=1):
            wav = root / entry[variant]["path"]
            if file_sha256(wav) != entry[variant]["sha256"]:
                raise ValueError(f"WAV differs from manifest: {entry['caseId']}")
            transcription.unlink(missing_ok=True)
            try:
                completed = subprocess.run(
                    [
                        str(cli),
                        "transcribe",
                        str(wav),
                        "--model-version",
                        "v3",
                        "--language",
                        entry["locale"],
                        "--model-dir",
                        str(model_dir),
                        "--output-json",
                        str(transcription),
                    ],
                    capture_output=True,
                    text=True,
                    check=False,
                    timeout=120,
                )
            except subprocess.TimeoutExpired:
                completed = None
            row: dict[str, Any] = {
                "caseId": entry["caseId"],
                "locale": entry["locale"],
                "variant": variant,
            }
            if completed is not None and completed.returncode == 0 and transcription.exists():
                result = json.loads(transcription.read_text(encoding="utf-8"))
                if result.get("modelVersion") != "v3":
                    raise ValueError(f"Unexpected Parakeet model for {entry['caseId']}")
                text = result["text"].strip()
                row.update(
                    status="ok",
                    rawText=text,
                    correctedText=text,
                    rawWER=spoken_normalized_wer(entry["ttsText"], text, entry["locale"]),
                    correctedWER=spoken_normalized_wer(entry["ttsText"], text, entry["locale"]),
                    seconds=result["processingTimeSeconds"],
                    confidence=result.get("confidence"),
                )
            else:
                reason = "CLI timed out" if completed is None else f"CLI exited {completed.returncode}"
                row.update(status="failed", reason=reason)
            report["results"].append(row)
            temporary_output = output.with_suffix(output.suffix + ".tmp")
            temporary_output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            temporary_output.replace(output)
            if index % 10 == 0 or index == len(manifest["entries"]):
                print(f"Parakeet {mode}/{variant}: {index}/{len(manifest['entries'])}", flush=True)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate local FluidAudio Parakeet on the voice WAV corpus")
    parser.add_argument("--cli", type=Path, required=True)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--mode", choices=MODES, required=True)
    parser.add_argument("--variant", choices=VARIANTS, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    run(
        cli=args.cli.resolve(),
        model_dir=args.model_dir.resolve(),
        source_commit=args.source_commit,
        mode=args.mode,
        variant=args.variant,
        output=args.output,
    )


if __name__ == "__main__":
    main()
