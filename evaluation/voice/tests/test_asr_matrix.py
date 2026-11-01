from __future__ import annotations

import json
from pathlib import Path

import pytest

from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.scoring.score_asr_matrix import (
    RECOGNIZERS,
    _extraction_score,
    _summarize_asr,
    _summarize_extraction,
    score_asr_matrix,
)


def _case() -> dict:
    return {
        "id": "case",
        "locale": "en",
        "referenceText": "Left kidney",
        "durationSeconds": 2.0,
        "terms": ["left kidney"],
        "expectedFacts": [{"kind": "side", "value": "left"}],
        "expectedFields": {"examinationDescription": "Left kidney"},
    }


def test_failed_asr_remains_in_word_and_term_denominators() -> None:
    result = _summarize_asr([_case()], {"case": {"status": "failed", "seconds": 0.2}})
    assert result["cases"] == result["failed"] == 1
    assert result["completed"] == result["missing"] == 0
    assert result["meanWER"] == result["meanNormalizedWER"] == result["meanCER"] == 1
    assert result["terms"] == 1
    assert result["retainedTerms"] == 0


def test_unmeasured_asr_is_distinguished_from_a_failed_attempt() -> None:
    result = _summarize_asr([_case()], {})
    assert result["missing"] == 1
    assert result["failed"] == 0


def test_wrong_warned_description_and_invented_name_do_not_become_a_correct_form() -> None:
    rows = {
        "case": {
            "methods": {
                "explicitRules": {
                    "status": "ok",
                    "fields": {"examinationDescription": "Right kidney", "patientName": "Invented patient"},
                    "warnings": {"examinationDescription": ["sideMismatch"]},
                    "accuracies": {"examinationDescription": "questionable", "patientName": "full"},
                }
            }
        }
    }
    result = _summarize_extraction([_case()], rows, "explicitRules")
    assert result["expectedFields"] == result["completed"] == 1
    assert result["correctFields"] == result["exactForms"] == 0
    assert result["falseFields"] == result["wrongFullFields"] == 1


def test_failed_extraction_keeps_expected_fields_in_denominator() -> None:
    rows = {"case": {"methods": {"medgemma": {"status": "failed"}}}}
    result = _summarize_extraction([_case()], rows, "medgemma")
    assert result["cases"] == result["expectedFields"] == 1
    assert result["completed"] == result["correctFields"] == result["exactForms"] == 0


def test_requested_method_scope_does_not_claim_unmeasured_methods_complete(tmp_path: Path) -> None:
    case = {**_case(), "audioSha256": "audio", "mode": "guided-format", "variant": "clean"}
    manifest = tmp_path / "manifest.json"
    manifest.write_text(json.dumps({"cases": [case]}))
    asr = tmp_path / "asr.jsonl"
    asr.write_text(
        "".join(
            json.dumps(
                {
                    "id": "case",
                    "recognizer": name,
                    "locale": "en",
                    "audioSha256": "audio",
                    "status": "ok",
                    "rawText": "Left kidney",
                    "seconds": 1.0,
                }
            )
            + "\n"
            for name in RECOGNIZERS
        )
    )
    extraction = tmp_path / "extraction.jsonl"
    extraction.write_text(
        "".join(
            json.dumps(
                {
                    "matrixCaseId": "case",
                    "recognizer": name,
                    "locale": "en",
                    "audioSha256": "audio",
                    "asrResultSha256": file_sha256(asr),
                    "rawText": "Left kidney",
                    "text": "Left kidney",
                    "expectedFields": case["expectedFields"],
                    "methods": {"exactLabels": {"status": "ok", "fields": case["expectedFields"]}},
                }
            )
            + "\n"
            for name in RECOGNIZERS
        )
    )
    selected = score_asr_matrix(
        manifest_path=manifest,
        asr_paths=[asr],
        extraction_paths=[extraction],
        output=tmp_path / "selected",
        methods=("exactLabels",),
    )
    assert selected["isASRComplete"] and selected["isExtractionComplete"]
    assert selected["methods"] == ["exactLabels"]
    assert all(key.endswith("/exactLabels") for key in selected["extraction"])
    complete_scope = score_asr_matrix(
        manifest_path=manifest, asr_paths=[asr], extraction_paths=[extraction], output=tmp_path / "all"
    )
    assert not complete_scope["isExtractionComplete"]
    assert any(key.endswith("/foundationModels") for key in complete_scope["unmeasuredExtractionPaths"])
    with pytest.raises(FileExistsError):
        score_asr_matrix(
            manifest_path=manifest, asr_paths=[asr], extraction_paths=[extraction], output=tmp_path / "selected"
        )
    altered = [json.loads(line) for line in extraction.read_text().splitlines()]
    altered[0]["rawText"] = "Other patient's text"
    extraction.write_text("\n".join(map(json.dumps, altered)))
    with pytest.raises(ValueError, match="frozen ASR source"):
        score_asr_matrix(
            manifest_path=manifest, asr_paths=[asr], extraction_paths=[extraction], output=tmp_path / "tampered"
        )


def test_failed_empty_gold_is_not_a_correct_form_and_unknown_policy_is_not_safe() -> None:
    case = {**_case(), "expectedFields": {}}
    failed = _summarize_extraction([case], {"case": {"methods": {"medgemma": {"status": "failed"}}}}, "medgemma")
    assert failed["exactForms"] == failed["equivalentExactForms"] == 0
    assert failed["automaticFields"] is None and failed["wrongAutomaticFields"] is None


def test_proposal_correctness_does_not_hide_failed_form_application() -> None:
    result = {
        "status": "ok",
        "fields": _case()["expectedFields"],
        "formAfterConfirmation": {"examinationDescription": "stale"},
        "automaticFieldIds": [],
    }
    score = _extraction_score(_case(), result)
    assert score["exactCase"]
    assert score["confirmationPatchErrors"] == ["examinationDescription"]
    assert score["automaticPatchErrors"] is None


def test_micro_wer_uses_word_counts_and_silence_is_separate() -> None:
    cases = [
        {**_case(), "id": "short", "referenceText": "a"},
        {**_case(), "id": "long", "referenceText": "a b c d"},
        {**_case(), "id": "silence", "referenceText": ""},
    ]
    rows = {
        "short": {"status": "ok", "rawText": "z"},
        "long": {"status": "ok", "rawText": "a b c d"},
        "silence": {"status": "ok", "rawText": "invented"},
    }
    result = _summarize_asr(cases, rows)
    assert result["meanWER"] == 0.5
    assert result["rawMicroWER"] == 2 / 5
    assert result["hallucinatedWordsOnEmptyReference"] == 1
    assert result["medianSeconds"] is None
