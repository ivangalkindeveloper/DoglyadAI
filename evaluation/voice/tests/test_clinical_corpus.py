from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest

from evaluation.voice.datasets.clinical_corpus import content_sha256, review_payload, validate_corpus
from evaluation.voice.common import ROOT
from evaluation.voice.datasets.prepare_clinical_pilot import clinical_pilot
from evaluation.voice.doctor.prepare_medical_review import prepare_medical_review


def test_pilot_is_explicitly_unreviewed_and_covers_types_without_fake_holdout() -> None:
    corpus = clinical_pilot()
    report = validate_corpus(corpus)
    assert not report["isClinicalEvidenceReady"]
    assert report["reviewedGoldCases"] == report["doctorRecordings"] == 0
    assert len(report["byExaminationType"]) == 31
    assert report["uncoveredExaminationTypes"] == []
    assert set(report["bySplit"]) == {"development"}
    frozen = json.loads((ROOT / "evaluation/voice/datasets/fixtures/clinical_pilot_v2.json").read_text())
    # Validation metadata evolves; the previously published medical texts and
    # labels remain byte-for-byte equivalent as Python data.
    assert {key: value for key, value in corpus.items() if key != "validation"} == {
        key: value for key, value in frozen.items() if key != "validation"
    }
    with pytest.raises(ValueError, match="real recordings"):
        validate_corpus(corpus, is_require_clinical_ready=True)


@pytest.mark.parametrize("change", ["translation", "speaker", "exposure", "evidence", "fakeReview", "duplicateAudio"])
def test_leakage_and_false_review_are_rejected(change: str) -> None:
    corpus = clinical_pilot()
    first, second = corpus["cases"][:2]
    if change == "translation":
        second.update(split="validation")
    elif change == "speaker":
        for index, row in enumerate((first, second)):
            row.update(
                sourceKind="doctorRecording",
                speakerId="doctor-1",
                sessionId=f"session-{index}",
                audioPath=f"{index}.wav",
                audioSha256=str(index),
                durationSeconds=1,
                familyId=str(index),
                clusterId=str(index),
            )
    elif change == "exposure":
        first["split"] = "test"
    elif change == "evidence":
        first["fieldEvidence"]["examinationDescription"] = ["invented fact"]
    elif change == "fakeReview":
        first["clinicalGold"]["examinationDescription"]["reviewStatus"] = "adjudicated"
    else:
        for row in (first, second):
            row.update(audioPath="a.wav", audioSha256="same", durationSeconds=1)
    with pytest.raises(ValueError):
        validate_corpus(corpus)


def test_review_hash_is_invalidated_when_gold_is_changed() -> None:
    corpus = clinical_pilot()
    first = corpus["cases"][0]
    first["goldReview"] = {
        "status": "adjudicated",
        "reviewerIds": ["expert-a", "expert-b"],
        "reviewedAt": "2026-10-25",
        "adjudicationNote": "Independent review resolved",
        "contentSha256": content_sha256(review_payload(first)),
    }
    assert validate_corpus(corpus)["reviewedGoldCases"] == 1
    first["clinicalContext"]["ageYears"] = 5
    with pytest.raises(ValueError, match="stale"):
        validate_corpus(corpus)


def test_review_packet_groups_audio_variants_and_hides_model_names(tmp_path: Path) -> None:
    case = clinical_pilot()["cases"][0]
    variant = {**copy.deepcopy(case), "id": "noisy", "recognizer": "secret-model"}
    terminology = {**copy.deepcopy(case), "id": "term", "mode": "terminology"}
    manifest = tmp_path / "source.json"
    manifest.write_text(json.dumps({"cases": [case, variant, terminology]}))
    output = tmp_path / "review"
    report = prepare_medical_review(manifest, output)
    assert report["reviewItems"] == 1 and report["excludedTerminologyCases"] == 1
    assert "secret-model" not in (output / "review.jsonl").read_text()
    assert "secret-model" not in (output / "review.html").read_text()
    with pytest.raises(FileExistsError):
        prepare_medical_review(manifest, output)
