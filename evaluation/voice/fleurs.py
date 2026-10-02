from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
import tarfile
from pathlib import Path
from typing import Any

from evaluation.voice.common import ROOT
from evaluation.voice.generate import file_sha256

REVISION = "70bb2e84b976b7e960aa89f1c648e09c59f894dd"
DATASET_URL = f"https://huggingface.co/datasets/google/fleurs/resolve/{REVISION}/data"
OUTPUT_DIR = ROOT / "build/voice-eval/fleurs"
LANGUAGES = {"en": "en_us", "ru": "ru_ru"}
SAMPLE_COUNT = 100


def _download_tsv(code: str, directory: Path) -> Path:
    path = directory / "test.tsv"
    if path.exists():
        return path
    subprocess.run(["curl", "-fLsS", f"{DATASET_URL}/{code}/test.tsv", "-o", str(path)], check=True)
    return path


def _selected_rows(path: Path) -> list[dict[str, str]]:
    selected: list[dict[str, str]] = []
    seen: set[str] = set()
    with path.open(encoding="utf-8") as input_file:
        for columns in csv.reader(input_file, delimiter="\t"):
            if len(columns) < 4:
                raise ValueError("Unexpected FLEURS TSV format")
            filename = columns[1]
            if filename in seen:
                continue
            seen.add(filename)
            selected.append(
                {
                    "utteranceId": columns[0],
                    "fileName": filename,
                    "transcription": columns[2],
                    "normalizedTranscription": columns[3],
                }
            )
            if len(selected) == SAMPLE_COUNT:
                break
    if len(selected) != SAMPLE_COUNT:
        raise ValueError("FLEURS test split has fewer than 100 distinct audio files")
    return selected


def _extract_selected(code: str, rows: list[dict[str, str]], directory: Path) -> None:
    remaining = {row["fileName"] for row in rows if not (directory / row["fileName"]).exists()}
    if not remaining:
        return
    download = subprocess.Popen(["curl", "-fLsS", f"{DATASET_URL}/{code}/audio/test.tar.gz"], stdout=subprocess.PIPE)
    try:
        assert download.stdout is not None
        with download.stdout, tarfile.open(fileobj=download.stdout, mode="r|gz") as archive:
            for member in archive:
                if not member.isfile():
                    continue
                name = Path(member.name).name
                if name not in remaining:
                    continue
                source = archive.extractfile(member)
                if source is None:
                    raise ValueError(f"Unable to read {member.name}")
                target = directory / name
                with source, target.open("wb") as output:
                    shutil.copyfileobj(source, output)
                remaining.remove(name)
                if not remaining:
                    break
    finally:
        download.terminate()
        download.wait(timeout=10)
    if remaining:
        raise ValueError(f"FLEURS audio files missing from tar: {sorted(remaining)[:5]}")


def prepare_fleurs(locale: str) -> dict[str, Any]:
    code = LANGUAGES[locale]
    directory = OUTPUT_DIR / code
    directory.mkdir(parents=True, exist_ok=True)
    tsv = _download_tsv(code, directory)
    rows = _selected_rows(tsv)
    _extract_selected(code, rows, directory)
    entries = []
    for row in rows:
        path = directory / row["fileName"]
        entries.append(
            {
                "id": f"{code}-{row['fileName'].removesuffix('.wav')}",
                "locale": locale,
                "utteranceId": row["utteranceId"],
                "audioPath": str(path.relative_to(ROOT)),
                "audioSha256": file_sha256(path),
                "transcription": row["transcription"],
                "normalizedTranscription": row["normalizedTranscription"],
            }
        )
    manifest = {
        "schemaVersion": 1,
        "dataset": "google/fleurs",
        "revision": REVISION,
        "config": code,
        "split": "test",
        "license": "CC BY 4.0",
        "attribution": "Conneau et al., FLEURS: Few-shot Learning Evaluation of Universal Representations of Speech (2022)",
        "sourceUrl": f"https://huggingface.co/datasets/google/fleurs/tree/{REVISION}/data/{code}",
        "selection": "first 100 distinct filenames in test.tsv order",
        "tsvSha256": file_sha256(tsv),
        "entries": entries,
    }
    (directory / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description="Download 100 FLEURS test recordings per locale outside Git")
    parser.add_argument("--locale", choices=("en", "ru", "both"), default="both")
    args = parser.parse_args()
    for locale in LANGUAGES if args.locale == "both" else (args.locale,):
        result = prepare_fleurs(locale)
        print(f"{result['config']}: {len(result['entries'])} recordings")


if __name__ == "__main__":
    main()
