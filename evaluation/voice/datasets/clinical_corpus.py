from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Any

from evaluation.voice.audio.audio import wav_metadata
from evaluation.voice.common import ROOT
from evaluation.voice.datasets.generate import file_sha256
from evaluation.voice.datasets.validate_gold import validate_expected_fields, validate_gold_annotations


def content_sha256(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


def review_payload(case: dict[str, Any]) -> dict[str, Any]:
    return {
        key: case.get(key)
        for key in (
            "locale",
            "sourceKind",
            "recordingMode",
            "referenceText",
            "examinationTypeId",
            "clinicalContext",
            "expectedFields",
            "fieldEvidence",
            "clinicalGold",
            "expectedActions",
        )
    }


def _review_level(review: dict[str, Any], payload: Any) -> int:
    if not isinstance(review, dict) or review.get("status", "pending") not in (
        "pending",
        "singleReviewed",
        "adjudicated",
    ):
        raise ValueError("Unknown review status")
    if review.get("status", "pending") == "pending":
        return 0
    reviewers = review.get("reviewerIds", [])
    if (
        not isinstance(reviewers, list)
        or any(not isinstance(value, str) or not value.strip() or value != value.strip() for value in reviewers)
        or len(set(reviewers)) != len(reviewers)
    ):
        raise ValueError("Reviewers must be distinct nonblank IDs in a list")
    level = 1 if review["status"] == "singleReviewed" else 2
    if len(reviewers) < level or (level == 1 and len(reviewers) != 1):
        raise ValueError("Review status does not match the number of reviewers")
    if not isinstance(review.get("adjudicationNote"), str) or not review["adjudicationNote"].strip():
        raise ValueError("Adjudicated gold needs a date and decision record")
    if not isinstance(review.get("reviewedAt"), str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", review["reviewedAt"]):
        raise ValueError("Review date must be YYYY-MM-DD")
    date.fromisoformat(review["reviewedAt"])
    if review.get("contentSha256") != content_sha256(payload):
        raise ValueError("Review is stale: content hash differs")
    return level


def validate_corpus(
    corpus: dict[str, Any], *, is_require_clinical_ready: bool = False, is_verify_audio: bool = False
) -> dict[str, Any]:
    """Validate provenance and leakage, not medical truth or population representativeness."""
    if corpus.get("schemaVersion") != 2 or not isinstance(corpus.get("cases"), list) or not corpus["cases"]:
        raise ValueError("A nonempty version 2 corpus is required")
    known_types = json.loads(
        (ROOT / "backend/main/config/development/ru/l10n_ultrasound_examination_contextual_strings.json").read_text()
    )
    ids: set[str] = set()
    memberships: dict[tuple[str, str], tuple[str, str]] = {}
    audio_hashes: dict[str, str] = {}
    reviewed = 0
    single_reviewed = 0
    audio_reviewed = 0
    recordings = 0
    for case in corpus["cases"]:
        if not isinstance(case, dict):
            raise ValueError("Each case must be an object")
        if not isinstance(case.get("id"), str) or not case["id"].strip():
            raise ValueError("Nonblank case ID is required")
        if case["id"] in ids:
            raise ValueError("Duplicate case ID")
        ids.add(case["id"])
        if case.get("split") not in ("development", "validation", "test") or case.get("locale") not in ("ru", "en"):
            raise ValueError("Unknown split or locale")
        if not isinstance(case.get("isPreviouslyExposed"), bool):
            raise ValueError("Exposure must be recorded explicitly")
        if case["split"] == "test" and case["isPreviouslyExposed"]:
            raise ValueError("Previously exposed examples cannot become a new independent test")
        if (
            case.get("sourceKind") not in ("synthetic", "doctorRecording")
            or case["examinationTypeId"] not in known_types
        ):
            raise ValueError("Unknown source or examination type")
        for key in ("familyId", "clusterId"):
            if not isinstance(case.get(key), str) or not case[key].strip():
                raise ValueError("Explicit familyId and clusterId are required")
        if not isinstance(case.get("referenceText"), str):
            raise ValueError("A verbatim reference (possibly empty for silence) is required")
        recording_mode = case.get("recordingMode", "unspecified")
        allowed_modes = (
            ("unspecified", "textOnly", "tts")
            if case["sourceKind"] == "synthetic"
            else ("unspecified", "readScript", "scenarioDictation", "liveExamination")
        )
        if recording_mode not in allowed_modes:
            raise ValueError("recordingMode is inconsistent with sourceKind")
        if recording_mode == "textOnly" and case.get("audioPath"):
            raise ValueError("textOnly cases cannot contain audio")
        group_keys = [("family", case["familyId"]), ("cluster", case["clusterId"])]
        if case["referenceText"].strip():
            group_keys.append(("reference", content_sha256(case["referenceText"].strip().casefold())))
        if case["sourceKind"] == "doctorRecording":
            recordings += 1
            if any(
                not isinstance(case.get(key), str) or not case[key].strip()
                for key in ("speakerId", "sessionId", "audioPath")
            ):
                raise ValueError("Real recordings need audio and anonymous speaker/session IDs")
            group_keys += [("speaker", case["speakerId"]), ("session", case["sessionId"])]
        # Human speakers, sessions, stories, translations and acoustic variants
        # form connected clusters. Synthetic TTS voices are a separate stratum.
        for key in group_keys:
            membership = (case["split"], case["clusterId"])
            if key in memberships and memberships[key] != membership:
                raise ValueError(f"Split/cluster leakage: {key}")
            memberships[key] = membership
        validate_expected_fields(case["expectedFields"])
        validate_gold_annotations(case)
        gold_level = _review_level(case.get("goldReview", {}), review_payload(case))
        if (
            any(annotation.get("reviewStatus") == "adjudicated" for annotation in case.get("clinicalGold", {}).values())
            and gold_level < 2
        ):
            raise ValueError("Clinical equivalence cannot be enabled without an independent gold review")
        if (
            any(
                annotation.get("reviewStatus") == "singleReviewed"
                for annotation in case.get("clinicalGold", {}).values()
            )
            and gold_level < 1
        ):
            raise ValueError("Clinical annotation has no matching expert review")
        reviewed += gold_level == 2
        single_reviewed += gold_level == 1
        if case.get("audioPath"):
            duration = case.get("durationSeconds")
            if (
                not isinstance(case.get("audioSha256"), str)
                or not re.fullmatch(r"[0-9a-f]{64}", case["audioSha256"])
                or isinstance(duration, bool)
                or not isinstance(duration, (int, float))
                or not math.isfinite(duration)
                or duration <= 0
            ):
                raise ValueError("Audio hash and positive duration are required")
            previous = audio_hashes.get(case["audioSha256"])
            if previous is not None:
                raise ValueError(f"Duplicate audio content: {previous}/{case['id']}")
            audio_hashes[case["audioSha256"]] = case["id"]
            if is_verify_audio or is_require_clinical_ready:
                path = Path(case["audioPath"])
                metadata = wav_metadata(path if path.is_absolute() else ROOT / path)
                if (
                    metadata["sha256"] != case["audioSha256"]
                    or abs(metadata["durationSeconds"] - case["durationSeconds"]) > 0.002
                ):
                    raise ValueError("Frozen audio differs from manifest")
            audio_reviewed += (
                _review_level(
                    case.get("audioReview", {}),
                    {"audioSha256": case["audioSha256"], "referenceText": case["referenceText"]},
                )
                == 2
            )
    cases = corpus["cases"]
    is_ready = (
        recordings == reviewed == audio_reviewed == len(cases)
        and all(case.get("recordingMode") == "liveExamination" for case in cases)
        and (is_verify_audio or is_require_clinical_ready)
        and all(
            case.get("clinicalGold", {}).get(field, {}).get("isComplete") is True
            and case["clinicalGold"][field].get("reviewStatus") == "adjudicated"
            for case in cases
            for field in ("examinationDescription", "patientComplaints")
            if field in case["expectedFields"]
        )
    )
    if is_require_clinical_ready and not is_ready:
        raise ValueError(
            "Clinical evaluation requires real recordings of live examinations, verified audio and independently reviewed audible references and gold for every case"
        )
    return {
        "cases": len(cases),
        "families": len({case["familyId"] for case in cases}),
        "clusters": len({case["clusterId"] for case in cases}),
        "doctorRecordings": recordings,
        "reviewedGoldCases": reviewed,
        "singleReviewedGoldCases": single_reviewed,
        "reviewedAudioCases": audio_reviewed,
        "isClinicalEvidenceReady": is_ready,
        "isPopulationRepresentativenessEstablished": False,
        "byLocale": dict(Counter(case["locale"] for case in cases)),
        "bySource": dict(Counter(case["sourceKind"] for case in cases)),
        "byRecordingMode": dict(Counter(case.get("recordingMode", "unspecified") for case in cases)),
        "bySplit": dict(Counter(case["split"] for case in cases)),
        "byExaminationType": dict(Counter(case["examinationTypeId"] for case in cases)),
        "uncoveredExaminationTypes": sorted(set(known_types) - {case["examinationTypeId"] for case in cases}),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate/freeze annotated medical speech data without fabricating reviews"
    )
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--require-clinical-ready", action="store_true")
    parser.add_argument("--verify-audio", action="store_true")
    parser.add_argument("--freeze", type=Path, help="Write an immutable copy after validation")
    args = parser.parse_args()
    corpus = json.loads(args.manifest.read_text(encoding="utf-8"))
    report = validate_corpus(
        corpus, is_require_clinical_ready=args.require_clinical_ready, is_verify_audio=args.verify_audio
    )
    if args.freeze:
        if any(case.get("audioPath") for case in corpus["cases"]):
            validate_corpus(corpus, is_verify_audio=True)
        with args.freeze.open("x", encoding="utf-8") as destination:
            destination.write(
                json.dumps(
                    {**corpus, "importSourceSha256": file_sha256(args.manifest), "validation": report},
                    ensure_ascii=False,
                    indent=2,
                )
                + "\n"
            )
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
