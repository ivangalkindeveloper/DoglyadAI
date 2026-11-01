from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from evaluation.voice.audio.audio import wav_metadata
from evaluation.voice.common import ROOT
from evaluation.voice.datasets.generate import file_sha256

MODES = ("guided-format", "reordered-format", "freeform-development")
VARIANTS = ("clean", "noisy")


def asr_matrix_corpus(terminology_path: Path | None = None, *, is_include_natural: bool = False) -> dict[str, Any]:
    """Freeze the same audio, intended words and form gold for every recognizer."""
    cases: list[dict[str, Any]] = []
    sources: dict[str, str] = {}
    for mode in MODES:
        manifest_path = ROOT / "build/voice-eval/audio" / mode / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        split = manifest.get("split", "regression")
        corpus_path = ROOT / "build/voice-eval/text" / f"{split}.jsonl"
        corpus = {row["id"]: row for row in map(json.loads, corpus_path.read_text(encoding="utf-8").splitlines())}
        sources[str(manifest_path.relative_to(ROOT))] = file_sha256(manifest_path)
        sources[str(corpus_path.relative_to(ROOT))] = file_sha256(corpus_path)
        for entry in manifest["entries"]:
            if entry["status"] != "ok":
                raise ValueError(f"Audio unavailable: {entry['caseId']}")
            original = corpus[entry["caseId"]]
            for variant in VARIANTS:
                audio = entry[variant]
                audio_path = ROOT / audio["path"]
                if file_sha256(audio_path) != audio["sha256"]:
                    raise ValueError(f"Audio hash mismatch: {audio_path}")
                cases.append(
                    {
                        "id": f"{mode}/{entry['caseId']}/{variant}",
                        "caseId": entry["caseId"],
                        "mode": mode,
                        "variant": variant,
                        "locale": entry["locale"],
                        "audioPath": audio["path"],
                        "audioSha256": audio["sha256"],
                        "durationSeconds": audio["durationSeconds"],
                        "referenceText": entry.get("werReference", entry["ttsText"]),
                        "inputText": entry["ttsText"],
                        "examinationTypeId": entry["examinationTypeId"],
                        "expectedFields": original["expectedFields"],
                        "expectedFacts": original["expectedFacts"],
                        "scenario": original["scenario"],
                    }
                )
    if terminology_path is not None:
        terminology = json.loads(terminology_path.read_text(encoding="utf-8"))
        cases.extend(terminology["cases"])
        sources.update(terminology["sources"])
        sources[str(terminology_path.resolve().relative_to(ROOT))] = file_sha256(terminology_path)
    if is_include_natural:
        for name in ("natural-regression-v1", "natural-control-v1", "natural-holdout-v1"):
            directory = ROOT / "build/voice-eval" / name
            path = directory / "cases.json"
            manifest = json.loads(path.read_text(encoding="utf-8"))
            sources[str(path.relative_to(ROOT))] = file_sha256(path)
            for row in manifest["cases"]:
                audio_path = directory / row["audioFile"]
                metadata = wav_metadata(audio_path)
                if metadata["sha256"] != row["audioSha256"]:
                    raise ValueError("Natural speech audio changed")
                cases.append(
                    {
                        "id": f"{name}/{row['id']}/clean",
                        "caseId": row["id"],
                        "mode": name,
                        "variant": "clean",
                        "locale": row["locale"],
                        "audioPath": str(audio_path.relative_to(ROOT)),
                        "audioSha256": metadata["sha256"],
                        "durationSeconds": metadata["durationSeconds"],
                        "referenceText": row["spokenText"],
                        "inputText": row["inputText"],
                        "examinationTypeId": row["examinationTypeId"],
                        "expectedFields": row["expectedFields"],
                        "expectedFacts": [],
                        "scenario": row["category"],
                    }
                )
    if len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Duplicate matrix case")
    return {
        "schemaVersion": 1,
        "referenceKind": "intended TTS words, not human-verified audio",
        "sources": sources,
        "cases": cases,
    }
