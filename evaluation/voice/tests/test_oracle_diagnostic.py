from __future__ import annotations

import pytest

from evaluation.voice.oracle_diagnostic import compare
from evaluation.voice.score_candidate import FIELDS


def _summary(*, oracle: bool, matches: dict[str, bool], manifest: str = "audio") -> dict:
    row = {
        "id": "case-1",
        "locale": "en",
        "examinationTypeId": "heart",
        "goldTextStatus": "ok" if oracle else "skipped",
        "speechAnalyzerParseStatus": "skipped" if oracle else "ok",
    }
    if oracle:
        row["goldText"] = {"equivalentExactCase": all(matches.values()), "equivalentMatches": matches}
    else:
        row["speechAnalyzer"] = {"equivalentExactCase": all(matches.values()), "equivalentMatches": matches}
    return {
        "inputSource": "originalText",
        "audioMode": "extended-v2",
        "audioVariant": "clean",
        "regressionSha256": "corpus",
        "audioManifestSha256": manifest,
        "scoredCases": [row],
    }


def test_compare_classifies_field_contributions() -> None:
    oracle = _summary(oracle=True, matches={field: field != "patientName" for field in FIELDS})
    candidate = _summary(oracle=False, matches={field: field != "patientDateOfBirth" for field in FIELDS})

    result = compare(oracle, candidate)["byLocale"]["en"]

    assert result["oracleEquivalentExactCases"] == 0
    assert result["candidateEquivalentExactCases"] == 0
    assert result["fields"]["patientName"]["asrOnly"] == 1
    assert result["fields"]["patientDateOfBirth"]["oracleOnly"] == 1
    assert result["fields"]["patientGender"]["bothCorrect"] == 1


def test_compare_rejects_different_audio_manifests() -> None:
    matches = dict.fromkeys(FIELDS, True)
    oracle = _summary(oracle=True, matches=matches)
    candidate = _summary(oracle=False, matches=matches, manifest="another")

    with pytest.raises(ValueError, match="audioManifestSha256"):
        compare(oracle, candidate)


def test_compare_accepts_fixed_asr_replay_from_same_parser() -> None:
    matches = dict.fromkeys(FIELDS, True)
    oracle = _summary(oracle=True, matches=matches)
    candidate = _summary(oracle=False, matches=matches)
    candidate["inputSource"] = "asrReplay"
    candidate["asrReportSha256"] = "transcripts"
    candidate["scoredCases"][0]["goldTextStatus"] = "ok"
    candidate["scoredCases"][0]["goldText"] = {
        "equivalentExactCase": True,
        "equivalentMatches": matches,
    }

    result = compare(oracle, candidate)

    assert result["byLocale"]["en"]["candidateEquivalentExactCases"] == 1
    assert result["candidateASRReportSha256"] == "transcripts"
