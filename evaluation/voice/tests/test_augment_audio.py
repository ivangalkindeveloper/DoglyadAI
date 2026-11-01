from __future__ import annotations

import array
import wave
from pathlib import Path

import pytest

from evaluation.voice.audio.augment_audio import augment_audio


def _wav(path: Path, values: list[int]) -> None:
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(16000)
        output.writeframes(array.array("h", values).tobytes())


def test_noise_is_reproducible_and_isolated_at_measured_snr(tmp_path: Path) -> None:
    source = tmp_path / "source.wav"
    _wav(source, [1000, -1000] * 8000)
    a = augment_audio(source, tmp_path / "a.wav", factor="whiteNoiseSNR", value=20, family_id="story")
    b = augment_audio(source, tmp_path / "b.wav", factor="whiteNoiseSNR", value=20, family_id="story")
    assert a == b and a["durationSeconds"] == 1
    assert abs(a["measuredSNRDb"] - 20) < 0.02
    assert a["familyId"] == "story"


def test_clipping_and_invalid_factor_do_not_publish_audio(tmp_path: Path) -> None:
    source, output = tmp_path / "source.wav", tmp_path / "output.wav"
    _wav(source, [30000] * 16)
    with pytest.raises(ValueError, match="clip"):
        augment_audio(source, output, factor="gainDb", value=6, family_id="story")
    assert not output.exists()
    with pytest.raises(ValueError, match="Unknown"):
        augment_audio(source, output, factor="combinedNoise", value=25, family_id="story")
