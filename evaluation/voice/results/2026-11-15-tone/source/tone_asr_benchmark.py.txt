from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import time
from datetime import datetime, timezone
from importlib.metadata import distribution, distributions
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT

TONE_COMMIT = "3c5b6c015038173840e62cea99e10cdb1c759116"


def _file_sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def _resolve_audio(cases: list[dict[str, Any]], audio_directory: Path | None) -> dict[str, Path]:
    paths: dict[str, Path] = {}
    alternatives: dict[str, Path] = {}
    if audio_directory is not None:
        for path in sorted(audio_directory.rglob("*.wav")):
            alternatives.setdefault(_file_sha256(path), path)
    for case in cases:
        path = ROOT / case["audioPath"]
        if not path.is_file():
            path = alternatives.get(case["audioSha256"])
        if path is None or not path.is_file() or _file_sha256(path) != case["audioSha256"]:
            raise ValueError(f"Frozen audio is absent or changed: {case['id']}")
        paths[case["id"]] = path
    return paths


def _pipeline(model_directory: Path, threads: int) -> Any:
    import onnxruntime as ort
    from tone.decoder import BeamSearchCTCDecoder
    from tone.logprob_splitter import StreamingLogprobSplitter
    from tone.onnx_wrapper import StreamingCTCModel
    from tone.pipeline import StreamingCTCPipeline

    options = ort.SessionOptions()
    options.intra_op_num_threads = threads
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(
        str(model_directory / "model.onnx"), sess_options=options, providers=["CPUExecutionProvider"]
    )
    return StreamingCTCPipeline(
        StreamingCTCModel(session),
        StreamingLogprobSplitter(),
        BeamSearchCTCDecoder.from_local(model_directory / "kenlm.bin"),
    )


def run_tone_asr(
    *,
    manifest_path: Path,
    model_directory: Path,
    model_revision: str,
    output: Path,
    audio_directory: Path | None = None,
    threads: int = 4,
    limit: int | None = None,
) -> dict[str, Any]:
    """Run the upstream CPU/KenLM pipeline on unchanged Russian matrix WAVs."""
    import psutil
    from tone import read_audio

    if threads < 1 or (limit is not None and limit < 1):
        raise ValueError("Threads and optional limit must be positive")
    if len(model_revision) != 40 or any(char not in "0123456789abcdef" for char in model_revision):
        raise ValueError("Pin the Hugging Face model revision to a commit SHA")
    package_source = json.loads(distribution("tone").read_text("direct_url.json") or "{}")
    if package_source.get("vcs_info", {}).get("commit_id") != TONE_COMMIT:
        raise ValueError(f"Install upstream T-one at the pinned commit {TONE_COMMIT}")
    cases = [case for case in json.loads(manifest_path.read_text())["cases"] if case["locale"] == "ru"]
    if not cases or len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Expected nonempty Russian cases with unique IDs")
    if limit is not None:
        count = min(limit, len(cases))
        cases = [cases[round(i * (len(cases) - 1) / max(count - 1, 1))] for i in range(count)]
    paths = _resolve_audio(cases, audio_directory)
    settings = {
        "model": "tone",
        "modelId": "t-tech/T-one",
        "modelRevision": model_revision,
        "modelHashes": {name: _file_sha256(model_directory / name) for name in ("model.onnx", "kenlm.bin")},
        "packageSource": package_source,
        "manifestSha256": _file_sha256(manifest_path),
        "sourceSha256": _file_sha256(Path(__file__)),
        "caseIds": [case["id"] for case in cases],
        "audioPaths": {key: str(path.resolve()) for key, path in paths.items()},
        "device": "cpu",
        "platform": platform.platform(),
        "python": platform.python_version(),
        "packages": dict(sorted((item.metadata["Name"], item.version) for item in distributions())),
        "configuration": {
            "decoder": "beam_search",
            "beamWidth": 200,
            "alpha": 0.4,
            "beta": 0.9,
            "hotwords": [],
            "audioReader": "tone.read_audio / miniaudio",
            "sampleRate": 8000,
            "chunkSamples": 2400,
            "audioMode": "forward_offline with upstream padding, splitter and state",
            "onnxIntraOpThreads": threads,
            "onnxInterOpThreads": 1,
            "providers": ["CPUExecutionProvider"],
        },
    }
    output.mkdir(parents=True, exist_ok=True)
    settings_path, results_path = output / "settings.json", output / "results.jsonl"
    if settings_path.exists():
        previous = json.loads(settings_path.read_text())
        if any(previous.get(key) != value for key, value in settings.items()):
            raise ValueError("Resume settings differ; choose a new output directory")
    else:
        if results_path.exists():
            raise ValueError("Cannot resume results without their settings")
        settings_path.write_text(
            json.dumps({**settings, "startedAt": datetime.now(timezone.utc).isoformat()}, indent=2) + "\n"
        )
    previous_rows = (
        [json.loads(line) for line in results_path.read_text().splitlines()] if results_path.exists() else []
    )
    originals = {case["id"]: case for case in cases}
    completed: set[str] = set()
    for row in previous_rows:
        case = originals.get(row["id"])
        if (
            case is None
            or row["id"] in completed
            or row.get("audioSha256") != case["audioSha256"]
            or row.get("model") != "tone"
            or row.get("locale") != "ru"
            or row.get("status") not in ("ok", "failed")
        ):
            raise ValueError("Existing results differ from the frozen run")
        completed.add(row["id"])
    if len(completed) == len(cases):
        return {"cases": len(cases), "alreadyComplete": True}
    started = time.monotonic()
    pipeline = _pipeline(model_directory, threads)
    load_seconds = time.monotonic() - started
    print(f"T-one loaded in {load_seconds:.2f}s; {len(cases)} cases", flush=True)
    process = psutil.Process()
    for index, case in enumerate(cases, 1):
        if case["id"] in completed:
            continue
        if _file_sha256(paths[case["id"]]) != case["audioSha256"]:
            raise ValueError(f"Audio changed during the run: {case['id']}")
        row = {
            key: case[key] for key in ("id", "caseId", "mode", "variant", "locale", "audioSha256", "durationSeconds")
        }
        row["model"] = "tone"
        started = time.monotonic()
        try:
            audio = read_audio(paths[case["id"]])
            phrases = pipeline.forward_offline(audio)
            text = " ".join(phrase.text for phrase in phrases).strip()
            row.update(
                status="ok",
                rawText=text,
                correctedText=text,
                phrases=[{"text": p.text, "startTime": p.start_time, "endTime": p.end_time} for p in phrases],
            )
        except Exception as error:
            row.update(status="failed", errorType=type(error).__name__, reason=str(error)[:1000])
        row.update(seconds=time.monotonic() - started, processRSSBytes=process.memory_info().rss)
        with results_path.open("a", encoding="utf-8") as destination:
            destination.write(json.dumps(row, ensure_ascii=False) + "\n")
            destination.flush()
            os.fsync(destination.fileno())
        print(f"tone: {index}/{len(cases)} {row['status']} {row['seconds']:.2f}s {case['mode']}", flush=True)
    summary = {
        "cases": len(cases),
        "modelLoadSeconds": load_seconds,
        "finishedAt": datetime.now(timezone.utc).isoformat(),
    }
    (output / "execution.json").write_text(json.dumps(summary, indent=2) + "\n")
    return summary


def _main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate pinned T-one CPU/KenLM on Russian frozen audio")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--model-revision", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--audio-dir", type=Path)
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--limit", type=int)
    args = parser.parse_args()
    print(
        json.dumps(
            run_tone_asr(
                manifest_path=args.manifest,
                model_directory=args.model_dir,
                model_revision=args.model_revision,
                output=args.output,
                audio_directory=args.audio_dir,
                threads=args.threads,
                limit=args.limit,
            )
        )
    )


if __name__ == "__main__":
    _main()
