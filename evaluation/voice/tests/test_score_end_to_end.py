from __future__ import annotations

import json
from pathlib import Path

from evaluation.voice.scoring.score_end_to_end import score


def test_parser_failure_does_not_remove_successful_asr(tmp_path: Path) -> None:
    source = tmp_path / "report.json"
    report = {
        "fixtureSha256": "fixture",
        "results": [
            {
                "id": "a",
                "pack": "test",
                "locale": "en",
                "status": "failed",
                "inputText": "left kidney",
                "rawText": "left kidney",
                "correctedText": "left kidney",
                "asrSeconds": 1.0,
                "expectedFields": {"examinationDescription": "left kidney"},
                "foundationCalls": 0,
                "serverAttempts": 1,
            }
        ],
    }
    source.write_text(json.dumps(report))
    result = score(source, tmp_path / "score.json")["groups"]["test/en"]
    assert result["asrMeasuredCases"] == 1 and result["completed"] == 0
    assert result["meanWER"] == 0 and result["exactForms"] == 0
    report["inputMode"] = "ideal-text"
    source.write_text(json.dumps(report))
    result = score(source, tmp_path / "text-score.json")["groups"]["test/en"]
    assert result["asrMeasuredCases"] == 0 and result["meanWER"] is None
