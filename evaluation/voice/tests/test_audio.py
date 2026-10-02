from __future__ import annotations

import array
import math
import json
import wave
from collections import Counter
from pathlib import Path

from evaluation.voice.asr import word_error_rate
import pytest

from evaluation.voice.audio import (
    SWIFT_SOURCE,
    add_reproducible_noise,
    reuse_existing_audio,
    select_cases,
    wav_metadata,
)
from evaluation.voice.generate import file_sha256, make_corpus


def test_audio_selection_covers_every_type_and_locale() -> None:
    regression, _ = make_corpus()
    quick = select_cases(regression, "quick")
    extended = select_cases(regression, "extended")
    assert len(quick) == 62
    assert len(extended) == 248
    assert Counter(case["locale"] for case in quick) == {"en": 31, "ru": 31}
    assert set(case["id"] for case in quick) <= {case["id"] for case in extended}
    assert len({(case["locale"], case["examinationTypeId"], case["scenario"]) for case in extended}) == 248


def test_noise_is_repeatable_and_retains_valid_audio(tmp_path: Path) -> None:
    source = tmp_path / "source.wav"
    samples = array.array("h", (round(6000 * math.sin(index / 12)) for index in range(8000)))
    with wave.open(str(source), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(16000)
        wav.writeframes(samples.tobytes())

    first = tmp_path / "first.wav"
    second = tmp_path / "second.wav"
    add_reproducible_noise(source, first, "fixed-case")
    add_reproducible_noise(source, second, "fixed-case")
    assert first.read_bytes() == second.read_bytes()
    assert first.read_bytes() != source.read_bytes()
    assert wav_metadata(first)["sampleRate"] == 16000
    assert wav_metadata(first)["durationSeconds"] > wav_metadata(source)["durationSeconds"]


def test_wer_counts_substitutions_insertions_and_deletions() -> None:
    assert word_error_rate("right kidney 12 mm", "right kidney 21 mm") == 0.25
    assert word_error_rate("right kidney", "right left kidney") == 0.5
    assert word_error_rate("no lesions seen", "lesions seen") == 1 / 3


def test_existing_audio_snapshot_is_reused_only_when_unchanged(tmp_path: Path) -> None:
    audio = tmp_path / "sample.wav"
    audio.write_bytes(b"frozen-audio")
    manifest = {
        "mode": "quick",
        "requestedCases": 1,
        "regressionSha256": "fixed-regression",
        "synthesizerSourceSha256": file_sha256(SWIFT_SOURCE),
        "noiseSourceSha256": None,
        "ttsRate": 0.5,
        "entries": [{"caseId": "sample", "status": "ok", "clean": {"path": str(audio), "sha256": file_sha256(audio)}}],
    }
    manifest_path = tmp_path / "manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    assert reuse_existing_audio(manifest_path, [{"id": "sample"}], "quick", "fixed-regression") == manifest

    audio.write_bytes(b"changed-audio")
    with pytest.raises(ValueError, match="Existing audio has changed"):
        reuse_existing_audio(manifest_path, [{"id": "sample"}], "quick", "fixed-regression")
