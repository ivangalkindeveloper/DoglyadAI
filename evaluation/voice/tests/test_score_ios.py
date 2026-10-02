from __future__ import annotations

import json
from pathlib import Path

from evaluation.voice.generate import OUTPUT_DIR as TEXT_OUTPUT_DIR
from evaluation.voice.generate import file_sha256, write_corpus
from evaluation.voice.score_ios import _equal, _score_fields, score_ios_report


def test_missing_field_is_not_counted_as_a_correct_proposal() -> None:
    result = _score_fields({"patientComplaints": "pain"}, {"patientName": "Invented", "patientComplaints": "pain"})
    assert result["exactCase"] is False
    assert result["falseFilledFields"] == ["patientName"]


def test_russian_yo_is_optional_for_findings_but_not_patient_names() -> None:
    assert _equal("patientComplaints", "отёчность", "отечность")
    assert _equal("examinationDescription", "жёлчный пузырь", "желчный пузырь")
    assert not _equal("patientName", "Семён", "Семен")


def test_unavailable_stages_have_no_accuracy_denominator(tmp_path: Path) -> None:
    write_corpus(TEXT_OUTPUT_DIR)
    case = json.loads((TEXT_OUTPUT_DIR / "regression.jsonl").read_text(encoding="utf-8").splitlines()[0])
    report_path = tmp_path / "results.json"
    report_path.write_text(
        json.dumps(
            {
                "platform": "iOS Simulator",
                "systemVersion": "26.5",
                "deviceModel": "iPhone",
                "fixtureRegressionSha256": file_sha256(TEXT_OUTPUT_DIR / "regression.jsonl"),
                "fixtureAudioManifestSha256": "audio-hash",
                "fixturePromptSha256": {},
                "fixtureContextualStringsSha256": {},
                "fixtureApplicationSha256": "application-hash",
                "fixtureSourceFilesSha256": {},
                "results": [
                    {
                        "id": case["id"],
                        "locale": case["locale"],
                        "examinationTypeId": case["examinationTypeId"],
                        "asr": {"status": "failed", "reason": "Speech asset missing"},
                        "goldTextParse": {"status": "skipped", "reason": "Model unavailable"},
                        "recognizedTextParse": {"status": "skipped", "reason": "No transcript"},
                    }
                ],
            }
        ),
        encoding="utf-8",
    )
    summary = score_ios_report(report_path, tmp_path / "scored")
    metrics = summary["byLocale"]["en"]
    assert metrics["cases"] == 1
    assert metrics["meanRawWER"] is None
    assert metrics["goldTextScoredCases"] == 0
    assert metrics["recognizedTextScoredCases"] == 0
    assert metrics["recognizedTextExactCases"] == 0
