from __future__ import annotations

import argparse
import asyncio
from pathlib import Path

from evaluation.voice.common import ROOT
from evaluation.voice.server_parse import load_cases, run

PACKS = (
    ("guided", "regression", "guided-format"),
    ("reordered", "voiceBlind", "reordered-format"),
    ("freeform", "freeformDevelopment", "freeform-development"),
)
SOURCE_NAMES = ("ideal-text", "whisperkit-clean")


def source_path(folder: str, source: str) -> Path:
    if source == "ideal-text":
        return ROOT / "build/voice-eval/audio" / folder / "manifest.json"
    if source == "whisperkit-clean":
        return ROOT / "build/voice-eval" / f"ios-whisperkit-device-{folder}-clean" / "asr-report.json"
    raise ValueError(f"Unknown source: {source}")


def validate_inputs(source: str) -> None:
    for name, corpus_name, folder in PACKS:
        corpus = ROOT / "build/voice-eval/text" / f"{corpus_name}.jsonl"
        input_path = source_path(folder, source)
        cases = load_cases(
            corpus,
            asr_report_path=input_path if source == "whisperkit-clean" else None,
            audio_manifest_path=input_path if source == "ideal-text" else None,
        )
        ids = [case["id"] for case in cases]
        if (
            len(ids) != 124
            or len(set(ids)) != 124
            or sum(case["locale"] == "en" for case in cases) != 62
            or sum(case["locale"] == "ru" for case in cases) != 62
            or any(case["inputText"] is None for case in cases)
        ):
            raise ValueError(f"Incomplete {source} input for {name}")


async def run_benchmark(
    *, source: str, base_url: str, token_file: Path, output_dir: Path, limit: int | None = None
) -> None:
    if limit is not None and limit < 1:
        raise ValueError("The case limit must be positive")
    if not token_file.is_file() or not token_file.read_text(encoding="utf-8").strip():
        raise ValueError("A non-empty App Check token file is required")
    sources = SOURCE_NAMES if source == "both" else (source,)
    for selected_source in sources:
        validate_inputs(selected_source)
    for selected_source in sources:
        for name, corpus_name, folder in PACKS:
            input_path = source_path(folder, selected_source)
            output_name = f"medgemma-{selected_source}-{name}-v3"
            if limit is not None:
                output_name += f"-pilot{limit}"
            output_path = output_dir / f"{output_name}.json"
            print(f"Running {selected_source}/{name} -> {output_path}", flush=True)
            await run(
                corpus_path=ROOT / "build/voice-eval/text" / f"{corpus_name}.jsonl",
                asr_report_path=input_path if selected_source == "whisperkit-clean" else None,
                audio_manifest_path=input_path if selected_source == "ideal-text" else None,
                output_path=output_path,
                base_url=base_url,
                token_file=token_file,
                limit=limit,
                max_attempts=3,
            )


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark MedGemma on all three voice form packs")
    parser.add_argument("--source", choices=(*SOURCE_NAMES, "both"), default="ideal-text")
    parser.add_argument("--base-url", default="https://dev.api.doglyad.ru")
    parser.add_argument("--token-file", required=True, type=Path)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/voice-eval/server")
    parser.add_argument("--limit", type=int, help="Pilot case count per pack; outputs use separate pilot filenames")
    args = parser.parse_args()
    asyncio.run(
        run_benchmark(
            source=args.source,
            base_url=args.base_url,
            token_file=args.token_file,
            output_dir=args.output_dir,
            limit=args.limit,
        )
    )


if __name__ == "__main__":
    main()
