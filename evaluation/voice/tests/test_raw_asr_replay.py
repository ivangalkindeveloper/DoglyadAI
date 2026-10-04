from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice.generate import file_sha256
from evaluation.voice.raw_asr_replay import export_raw_replay


def test_raw_replay_uses_uncorrected_text_and_retains_confidence_spans(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    output = tmp_path / "raw.json"
    original = {
        "recognizer": "speechAnalyzer on physical iPhone",
        "results": [
            {
                "caseId": "case-1",
                "status": "ok",
                "rawText": "Biparital diameter. 67 mm.",
                "correctedText": "Biparietal diameter 67 mm.",
                "rawWER": 0.1,
                "correctedWER": 0.0,
                "confidenceSpans": [{"utf16Start": 0, "utf16Length": 9, "confidence": 0.8}],
            }
        ],
    }
    source.write_text(json.dumps(original), encoding="utf-8")

    result = export_raw_replay(source, output)

    assert result["rawReplayOfSha256"] == file_sha256(source)
    assert result["results"][0]["correctedText"] == "Biparital diameter. 67 mm."
    assert result["results"][0]["correctedWER"] == 0.1
    assert result["results"][0]["confidenceSpans"] == original["results"][0]["confidenceSpans"]
    assert json.loads(source.read_text(encoding="utf-8")) == original


def test_raw_replay_rejects_other_recognizers(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    source.write_text(json.dumps({"recognizer": "WhisperKit", "results": []}), encoding="utf-8")
    with pytest.raises(ValueError, match="SpeechAnalyzer"):
        export_raw_replay(source, tmp_path / "raw.json")
