from __future__ import annotations

import wave
from pathlib import Path

import pytest

from evaluation.voice.datasets.clinical_corpus import content_sha256, review_payload, validate_corpus
from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.datasets.prepare_clinical_pilot import clinical_pilot
from evaluation.voice.scoring.score_clinical_content import score_clinical_content
from evaluation.voice.datasets.validate_gold import validate_expected_fields


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("patientWeightKG", "not a number"),
        ("patientWeightKG", "79"),
        ("patientWeightKG", True),
        ("patientWeightKG", float("nan")),
        ("patientHeightCM", float("inf")),
        ("patientHeightCM", -1),
        ("patientWeightKG", 0),
        ("patientDateOfBirth", "2025-02-29"),
        ("patientDateOfBirth", "19900102"),
        ("patientDateOfBirth", "1990-01-02T00:00:00Z"),
        ("patientGender", "unknown"),
        ("patientName", []),
        ("patientComplaints", 5),
        ("examinationNumber", 184),
        ("examinationDescription", "  "),
        ("unknown", "value"),
    ],
)
def test_invalid_gold_transport_values_are_rejected(field: str, value: object) -> None:
    with pytest.raises(ValueError):
        validate_expected_fields({field: value})


def test_valid_zero_prefixed_id_and_calendar_values_are_preserved() -> None:
    fields = {
        "examinationNumber": "00184",
        "patientDateOfBirth": "2000-02-29",
        "patientWeightKG": 79.5,
        "patientHeightCM": 181,
        "patientGender": "female",
    }
    validate_expected_fields(fields)
    assert fields["examinationNumber"] == "00184"


@pytest.mark.parametrize(
    "mutation",
    [
        "quotesAsString",
        "acceptAbsent",
        "omitPresent",
        "unknownAction",
        "booleanString",
        "emptyFacts",
        "badVerdict",
        "fakeSingleReview",
    ],
)
def test_annotation_contract_cannot_silently_certify_malformed_gold(mutation: str) -> None:
    corpus = clinical_pilot()
    case = corpus["cases"][0]
    annotation = case["clinicalGold"]["examinationDescription"]
    if mutation == "quotesAsString":
        case["fieldEvidence"]["examinationDescription"] = case["referenceText"]
    elif mutation == "acceptAbsent":
        case["expectedActions"]["patientName"] = {"action": "accept"}
    elif mutation == "omitPresent":
        case["expectedActions"]["examinationDescription"] = {"action": "omit"}
    elif mutation == "unknownAction":
        case["expectedActions"]["examinationDescription"] = {"action": "accpet"}
    elif mutation == "booleanString":
        annotation["isComplete"] = "false"
    elif mutation == "emptyFacts":
        annotation["facts"] = []
    elif mutation == "badVerdict":
        annotation["candidateJudgments"] = [
            {"candidateText": "x", "verdict": "equivalent", "errorTypes": ["wrongSide"]}
        ]
    else:
        annotation["reviewStatus"] = "singleReviewed"
    with pytest.raises(ValueError):
        validate_corpus(corpus)


def _review(payload: dict, ids: list[str], status: str = "adjudicated") -> dict:
    return {
        "status": status,
        "reviewerIds": ids,
        "reviewedAt": "2026-10-25",
        "adjudicationNote": "Test fixture review",
        "contentSha256": content_sha256(payload),
    }


def test_single_review_is_counted_without_becoming_independent_confirmation() -> None:
    corpus = clinical_pilot()
    case = corpus["cases"][0]
    case["clinicalGold"]["examinationDescription"].update(reviewStatus="singleReviewed", isComplete=True)
    case["goldReview"] = _review(review_payload(case), ["expert-a"], "singleReviewed")
    report = validate_corpus(corpus)
    assert report["singleReviewedGoldCases"] == 1 and report["reviewedGoldCases"] == 0
    score = score_clinical_content(
        case["expectedFields"]["examinationDescription"],
        case["expectedFields"]["examinationDescription"],
        "ru",
        case["clinicalGold"]["examinationDescription"],
    )
    assert score["isClinicallyEquivalent"] is None and score["reviewStatus"] == "singleReviewed"
    case["locale"] = "en"
    with pytest.raises(ValueError, match="stale"):
        validate_corpus(corpus)


@pytest.mark.parametrize("reviewers", ["ab", ["a", "a"], ["a", " a"], ["a"], ["a", " "]])
def test_bad_review_identity_does_not_count_as_two_experts(reviewers: object) -> None:
    corpus = clinical_pilot()
    case = corpus["cases"][0]
    case["goldReview"] = _review(review_payload(case), reviewers)
    with pytest.raises(ValueError):
        validate_corpus(corpus)


def test_audio_gate_verifies_bytes_and_distinguishes_simulation(tmp_path: Path) -> None:
    corpus = clinical_pilot()
    corpus["cases"] = corpus["cases"][:1]
    case = corpus["cases"][0]
    path = tmp_path / "test-only.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(8000)
        wav.writeframes(b"\0\0" * 80)
    case.update(
        sourceKind="doctorRecording",
        recordingMode="scenarioDictation",
        speakerId="test-speaker",
        sessionId="test-session",
        audioPath=str(path),
        audioSha256=file_sha256(path),
        durationSeconds=0.01,
    )
    case["clinicalGold"]["examinationDescription"].update(reviewStatus="adjudicated", isComplete=True)
    case["goldReview"] = _review(review_payload(case), ["a", "b"])
    case["audioReview"] = _review(
        {"audioSha256": case["audioSha256"], "referenceText": case["referenceText"]}, ["a", "b"]
    )
    assert not validate_corpus(corpus, is_verify_audio=True)["isClinicalEvidenceReady"]
    case["recordingMode"] = "liveExamination"
    with pytest.raises(ValueError, match="stale"):
        validate_corpus(corpus)
    case["goldReview"] = _review(review_payload(case), ["a", "b"])
    assert not validate_corpus(corpus)["isClinicalEvidenceReady"]
    assert validate_corpus(corpus, is_require_clinical_ready=True)["isClinicalEvidenceReady"]
    path.write_bytes(b"corrupted")
    with pytest.raises((ValueError, wave.Error, EOFError)):
        validate_corpus(corpus, is_require_clinical_ready=True)
