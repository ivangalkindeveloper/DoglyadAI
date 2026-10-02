from __future__ import annotations

import json
import re
import wave
from pathlib import Path

import pytest

from evaluation.voice.audio import select_cases
from evaluation.voice.audio_script_v2 import make_audio_script, make_audio_segments
from evaluation.voice.audio_v2 import FIELD_PAUSE_MS, merge_segments
from evaluation.voice.generate import file_sha256, make_corpus
import evaluation.voice.audio_reference as audio_reference


def test_v2_scripts_are_complete_dictations_without_spoken_semicolons() -> None:
    cases = select_cases(make_corpus()[0], "extended")
    scripts = [make_audio_script(case) for case in cases]
    assert len(scripts) == 248
    assert all(";" not in script and not re.search(r"\d{4}-\d{2}-\d{2}", script) for script in scripts)
    for case, script in zip(cases, scripts, strict=True):
        assert script.count(". ") >= 7
        assert len(make_audio_segments(case)) == 8
        assert case["expectedFields"]["patientName"] in script
        assert case["expectedFields"]["patientComplaints"] in script


def test_v2_keeps_leading_zeros_correction_and_negation() -> None:
    cases = select_cases(make_corpus()[0], "extended")
    by_id = {case["id"]: case for case in cases}
    english = make_audio_script(by_id["regression-en-echocardiography-06"])
    russian = make_audio_script(by_id["regression-ru-echocardiography-00"])
    assert "Examination number: zero three nine" in english
    assert "fifty four, no, fifty one millimeters" in english
    assert "No additional abnormality" in english
    assert "Номер исследования: ноль четыре три" in russian
    assert "Дата рождения: один девять восемь один, ноль четыре, два шесть" in russian
    assert "Дополнительных изменений не выявлено" in russian


def test_v2_merges_two_spoken_halves_into_one_pcm_file(tmp_path: Path) -> None:
    sources = [tmp_path / "first.wav", tmp_path / "second.wav"]
    for path, sample in zip(sources, (b"\x01\x00", b"\x02\x00"), strict=True):
        with wave.open(str(path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(1000)
            wav.writeframes(sample * 100)
    output = tmp_path / "complete.wav"
    merge_segments(sources, output)
    with wave.open(str(output), "rb") as wav:
        assert wav.getnframes() == 200 + FIELD_PAUSE_MS
        audio = wav.readframes(wav.getnframes())
    assert audio[:2] == b"\x01\x00"
    assert audio[-2:] == b"\x02\x00"


def test_v2_word_reference_requires_matching_audio_manifest(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(audio_reference, "AUDIO_OUTPUT_DIR", tmp_path)
    directory = tmp_path / "extended-v2"
    directory.mkdir()
    manifest_path = directory / "manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "schemaVersion": 2,
                "mode": "extended-v2",
                "regressionSha256": "text-hash",
                "entries": [{"caseId": "case-1", "status": "ok", "werReference": "spoken words"}],
            }
        ),
        encoding="utf-8",
    )
    report = {
        "fixtureAudioMode": "extended-v2",
        "fixtureAudioManifestSha256": file_sha256(manifest_path),
        "fixtureRegressionSha256": "text-hash",
        "results": [{"id": "case-1"}],
    }
    assert audio_reference.report_word_references(report) == {"case-1": "spoken words"}
    report["fixtureAudioManifestSha256"] = "other"
    with pytest.raises(ValueError, match="another v2 audio manifest"):
        audio_reference.report_word_references(report)
