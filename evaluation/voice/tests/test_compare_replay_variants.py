from __future__ import annotations

import pytest

from evaluation.voice.compare_replay_variants import compare
from evaluation.voice.score_candidate import FIELDS


def _summary(*, name_correct: bool, manifest: str = "audio") -> dict:
    matches = {field: field != "patientName" or name_correct for field in FIELDS}
    return {
        "inputSource": "asrReplay",
        "audioMode": "extended-v2",
        "audioVariant": "clean",
        "regressionSha256": "corpus",
        "audioManifestSha256": manifest,
        "asrReportSha256": "transcript",
        "scoredCases": [
            {
                "id": "case-1",
                "locale": "en",
                "examinationTypeId": "heart",
                "goldTextStatus": "ok",
                "goldText": {
                    "equivalentExactCase": all(matches.values()),
                    "equivalentMatches": matches,
                    "equivalentUnnoticedWrongFields": [] if name_correct else ["patientName"],
                },
            }
        ],
    }


def test_compare_reports_field_win_without_changing_denominator() -> None:
    result = compare(_summary(name_correct=False), _summary(name_correct=True))["byLocale"]["en"]

    assert result["cases"] == 1
    assert result["leftEquivalentExact"] == 0
    assert result["rightEquivalentExact"] == 1
    assert result["fields"]["patientName"]["rightOnly"] == 1
    assert result["leftEquivalentUnnoticedWrongFields"] == 1


def test_compare_rejects_different_manifests() -> None:
    with pytest.raises(ValueError, match="audioManifestSha256"):
        compare(_summary(name_correct=False), _summary(name_correct=True, manifest="other"))
