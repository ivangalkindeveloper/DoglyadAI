from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice import audit_replay
from evaluation.voice.generate import file_sha256


def _write(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value) + "\n", encoding="utf-8")


def test_audit_joins_same_audio_and_detects_lost_label(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(audit_replay, "TEXT_OUTPUT_DIR", tmp_path / "text")
    monkeypatch.setattr(audit_replay, "AUDIO_OUTPUT_DIR", tmp_path / "audio")
    corpus = tmp_path / "text/voiceBlind.jsonl"
    _write(
        corpus,
        {
            "id": "case-1",
            "locale": "en",
            "scenario": "partial",
            "examinationTypeId": "eye",
            "expectedFields": {"patientComplaints": "pain"},
        },
    )
    manifest = tmp_path / "audio/voice-blind-v3/manifest.json"
    _write(manifest, {"entries": [{"caseId": "case-1", "ttsText": "Complaints: pain."}]})
    asr_path = tmp_path / "asr.json"
    _write(
        asr_path,
        {
            "audioManifestSha256": file_sha256(manifest),
            "audioVariant": "clean",
            "recognizer": "test",
            "results": [{"caseId": "case-1", "status": "ok", "correctedText": "Compleints. Pain."}],
        },
    )
    replay = tmp_path / "replay"
    _write(
        replay / "results.json",
        {
            "fixtureASRReportSha256": file_sha256(asr_path),
            "results": [{"id": "case-1", "goldTextParse": {"status": "ok", "fields": {}}}],
        },
    )
    summary = replay / "summary.json"
    _write(
        summary,
        {
            "inputSource": "asrReplay",
            "split": "voiceBlind",
            "voiceBlindSha256": file_sha256(corpus),
            "audioManifestSha256": file_sha256(manifest),
            "asrReportSha256": file_sha256(asr_path),
            "audioMode": "voice-blind-v3",
            "audioVariant": "clean",
            "scoredCases": [
                {
                    "id": "case-1",
                    "locale": "en",
                    "examinationTypeId": "eye",
                    "goldTextStatus": "ok",
                    "goldText": {
                        "equivalentWrongFields": ["patientComplaints"],
                        "warnedFields": [],
                    },
                }
            ],
        },
    )

    result = audit_replay.audit(summary, asr_path)
    assert result["cases"] == 1
    assert result["byLocale"]["en"]["patientComplaints"]["missing"] == 1
    assert result["failures"][0]["errors"][0]["exactLabelAnywhereInASR"] is False

    _write(asr_path, {"audioManifestSha256": "wrong", "audioVariant": "clean"})
    with pytest.raises(ValueError, match="ASR report uses another audio manifest"):
        audit_replay.audit(summary, asr_path)
