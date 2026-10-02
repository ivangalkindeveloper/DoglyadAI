from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice import field_diagnostic
from evaluation.voice.generate import file_sha256


def test_diagnostic_separates_wrong_fields_from_missing_and_reviewed_fields(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(field_diagnostic, "TEXT_OUTPUT_DIR", tmp_path)
    corpus_path = tmp_path / "control.jsonl"
    corpus_path.write_text(
        json.dumps(
            {
                "id": "test-1",
                "locale": "en",
                "examinationTypeId": "eye",
                "expectedFields": {"examinationNumber": "007", "patientName": "Jane Smith", "patientWeightKG": 70},
            }
        )
        + "\n",
        encoding="utf-8",
    )
    summary_path = tmp_path / "summary.json"
    summary_path.write_text(
        json.dumps(
            {
                "split": "control",
                "controlSha256": file_sha256(corpus_path),
                "inputSource": "asrReplay",
                "requestedCases": 1,
                "audioMode": "phrase-holdout",
                "audioVariant": "clean",
                "asrRecognizer": "test",
                "scoredCases": [
                    {
                        "id": "test-1",
                        "locale": "en",
                        "examinationTypeId": "eye",
                        "goldTextStatus": "ok",
                        "goldText": {
                            "proposedFields": ["examinationNumber", "patientName", "patientGender"],
                            "warnedFields": ["examinationNumber"],
                            "equivalentWrongFields": [
                                "examinationNumber",
                                "patientName",
                                "patientWeightKG",
                                "patientGender",
                            ],
                        },
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    result = field_diagnostic.diagnose(summary_path)["byLocale"]["en"]
    assert result["fields"]["examinationNumber"]["warnedWrong"] == 1
    assert result["fields"]["patientName"]["unwarnedWrong"] == 1
    assert result["fields"]["patientWeightKG"]["missing"] == 1
    assert result["fields"]["patientGender"]["falseFill"] == 1
    assert result["potentiallyAutomaticWrongWithoutConfidence"] == 0
