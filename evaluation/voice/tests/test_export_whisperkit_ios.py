from __future__ import annotations

import json
from pathlib import Path

from pytest import MonkeyPatch

from evaluation.voice import export_whisperkit_ios
from evaluation.voice.generate import file_sha256


def test_export_preserves_model_identity(tmp_path: Path, monkeypatch: MonkeyPatch) -> None:
    audio_root = tmp_path / "audio"
    mode = "freeform-development"
    folder = audio_root / mode
    folder.mkdir(parents=True)
    manifest = folder / "manifest.json"
    manifest.write_text(
        json.dumps({"entries": [{"caseId": "case-1", "locale": "ru", "ttsText": "печень"}]}),
        encoding="utf-8",
    )
    source = tmp_path / "results.json"
    source.write_text(
        json.dumps(
            {
                "runId": "test-run",
                "modelLabel": "large-v3_947MB",
                "promptMode": "type-context",
                "modelLoadSeconds": 3.0,
                "fixtureAudioMode": mode,
                "fixtureAudioVariant": "clean",
                "fixtureAudioManifestSha256": file_sha256(manifest),
                "results": [
                    {
                        "id": "case-1",
                        "locale": "ru",
                        "status": "ok",
                        "correctedText": "печень",
                        "elapsedSeconds": 1.0,
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(export_whisperkit_ios, "AUDIO_OUTPUT_DIR", audio_root)

    result = export_whisperkit_ios.export_whisperkit_report(source, tmp_path / "asr-report.json")

    assert result["recognizer"] == "WhisperKit Core ML large-v3_947MB on physical iPhone with type context"
    assert result["promptMode"] == "type-context"
    assert result["results"][0]["correctedWER"] == 0
