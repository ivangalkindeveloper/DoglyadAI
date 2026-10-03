from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice.server_parse import load_cases, score_response, summarize


def test_load_cases_replays_only_matching_iphone_transcripts(tmp_path: Path) -> None:
    corpus = tmp_path / "cases.jsonl"
    corpus.write_text(
        json.dumps(
            {
                "id": "case-1",
                "locale": "ru",
                "scenario": "complete",
                "examinationTypeId": "echocardiography",
                "spokenText": "вес семьдесят два килограмма",
                "expectedFields": {"patientWeightKG": 72},
            }
        )
        + "\n",
        encoding="utf-8",
    )
    asr = tmp_path / "asr.json"
    asr.write_text(
        json.dumps({"results": [{"caseId": "case-1", "locale": "ru", "status": "ok", "correctedText": "вес 72 кг"}]}),
        encoding="utf-8",
    )

    cases = load_cases(corpus, asr)

    assert len(cases) == 1
    assert cases[0]["inputText"] == "вес 72 кг"


def test_load_cases_uses_the_audio_script_as_oracle_text(tmp_path: Path) -> None:
    corpus = tmp_path / "cases.jsonl"
    corpus.write_text(
        json.dumps(
            {
                "id": "case-1",
                "locale": "en",
                "scenario": "complete",
                "examinationTypeId": "echocardiography",
                "spokenText": "old source text",
                "expectedFields": {"patientWeightKG": 72},
            }
        )
        + "\n",
        encoding="utf-8",
    )
    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "entries": [
                    {
                        "caseId": "case-1",
                        "locale": "en",
                        "examinationTypeId": "echocardiography",
                        "ttsText": "Weight: seventy two kilograms",
                        "status": "ok",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    cases = load_cases(corpus, None, manifest)
    assert cases[0]["inputText"] == "Weight: seventy two kilograms"


def test_score_counts_wrong_and_unspoken_values() -> None:
    score = score_response(
        {"patientWeightKG": 72},
        {
            "proposals": [
                {"fieldId": "patientWeightKG", "value": "73", "sourceQuote": "вес 73 кг"},
                {"fieldId": "patientGender", "value": "male", "sourceQuote": "male"},
            ],
            "rejectedFieldIds": [],
            "unmappedFindings": [],
        },
        "en",
    )
    assert not score["equivalentExactCase"]
    assert score["falseFilledFields"] == ["patientGender"]
    assert set(score["equivalentUnnoticedWrongFields"]) == {"patientWeightKG", "patientGender"}


def test_duplicate_server_field_fails_scoring() -> None:
    response = {
        "proposals": [
            {"fieldId": "patientGender", "value": "male"},
            {"fieldId": "patientGender", "value": "female"},
        ],
        "rejectedFieldIds": [],
    }
    with pytest.raises(ValueError, match="duplicate"):
        score_response({}, response, "en")


def test_summary_keeps_missing_parse_in_denominator() -> None:
    summary = summarize(
        [
            {
                "id": "case-1",
                "locale": "en",
                "scenario": "complete",
                "status": "httpError",
                "expectedFieldIds": ["patientName"],
            },
        ]
    )
    assert summary["en/complete"]["cases"] == 1
    assert summary["en/complete"]["parsed"] == 0
    assert summary["en/complete"]["expectedPresentFields"] == 1
