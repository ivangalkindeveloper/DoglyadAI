from __future__ import annotations

from pathlib import Path

import pytest

from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.runners.tone_asr_benchmark import _resolve_audio


def test_audio_relocation_requires_identical_content(tmp_path: Path) -> None:
    relocated = tmp_path / "renamed.wav"
    relocated.write_bytes(b"frozen audio bytes")
    cases = [{"id": "case", "audioPath": str(tmp_path / "missing.wav"), "audioSha256": file_sha256(relocated)}]
    assert _resolve_audio(cases, tmp_path) == {"case": relocated}
    relocated.write_bytes(b"different audio")
    with pytest.raises(ValueError, match="absent or changed"):
        _resolve_audio(cases, tmp_path)


def test_changed_original_audio_is_not_silently_replaced(tmp_path: Path) -> None:
    original, duplicate = tmp_path / "original.wav", tmp_path / "duplicate.wav"
    original.write_bytes(b"changed audio")
    duplicate.write_bytes(b"frozen audio")
    cases = [{"id": "case", "audioPath": str(original), "audioSha256": file_sha256(duplicate)}]
    with pytest.raises(ValueError, match="absent or changed"):
        _resolve_audio(cases, tmp_path)
