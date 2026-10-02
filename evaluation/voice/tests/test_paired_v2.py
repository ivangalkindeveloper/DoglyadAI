from __future__ import annotations

import json
from pathlib import Path

import pytest

import evaluation.voice.paired_v2 as paired_v2
from evaluation.voice.paired_v2 import compare_v2
from evaluation.voice.generate import file_sha256


def _summary(*, candidate: bool, audio_hash: str = "same") -> dict[str, object]:
    row = {"id": "case-1", "locale": "ru", "examinationTypeId": "echocardiography"}
    if candidate:
        row.update(
            speechAnalyzerASRStatus="ok",
            speechAnalyzerParseStatus="ok",
            speechAnalyzerCorrectedWER=0.1,
            speechAnalyzerCorrectedLiteralWER=0.4,
            speechAnalyzer={
                "exactCase": True,
                "equivalentExactCase": True,
                "matches": {
                    "patientName": True,
                    "patientGender": True,
                    "patientDateOfBirth": True,
                    "patientHeightCM": True,
                    "patientWeightKG": True,
                    "patientComplaints": True,
                    "examinationDescription": True,
                },
                "unnoticedWrongFields": [],
                "equivalentUnnoticedWrongFields": [],
            },
        )
    else:
        row.update(
            asrStatus="ok",
            recognizedTextStatus="ok",
            correctedWER=0.2,
            correctedLiteralWER=0.5,
            recognizedText={"exactCase": False},
        )
    return {
        "audioMode": "extended-v2",
        "audioVariant": "clean",
        "audioManifestSha256": audio_hash,
        "regressionSha256": "text-hash",
        "platform": "iOS",
        "scoredCases": [row],
    }


def test_paired_v2_reports_only_identical_audio_and_case_ids(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    audio = tmp_path / "extended-v2"
    audio.mkdir()
    manifest = audio / "manifest.json"
    manifest.write_text("frozen audio manifest", encoding="utf-8")
    monkeypatch.setattr(paired_v2, "AUDIO_OUTPUT_DIR", tmp_path)
    audio_hash = file_sha256(manifest)
    baseline = tmp_path / "baseline.json"
    candidate = tmp_path / "candidate.json"
    baseline.write_text(json.dumps(_summary(candidate=False, audio_hash=audio_hash)), encoding="utf-8")
    candidate.write_text(json.dumps(_summary(candidate=True, audio_hash=audio_hash)), encoding="utf-8")
    result = compare_v2(baseline, candidate, tmp_path / "paired.json")
    assert result["byLocale"]["ru"]["baselineCommonFieldsExact"] == 0
    assert result["byLocale"]["ru"]["candidateCommonFieldsExact"] == 1
    assert result["byLocale"]["ru"]["candidateFullFormExact"] == 1
    assert result["byLocale"]["ru"]["candidateEquivalentFullFormExact"] == 1
    assert result["byLocale"]["ru"]["candidateEquivalentUnnoticedWrongFields"] == 0
    assert result["releaseGate"] is None  # one case is not a 124-case release measurement

    candidate.write_text(json.dumps(_summary(candidate=True, audio_hash="different")), encoding="utf-8")
    with pytest.raises(ValueError, match="different audioManifestSha256"):
        compare_v2(baseline, candidate, tmp_path / "paired.json")

    candidate.write_text(json.dumps(_summary(candidate=True, audio_hash=audio_hash)), encoding="utf-8")
    manifest.write_text("changed audio manifest", encoding="utf-8")
    with pytest.raises(ValueError, match="stale v2 audio manifest"):
        compare_v2(baseline, candidate, tmp_path / "paired.json")
