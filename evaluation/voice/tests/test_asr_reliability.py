from __future__ import annotations

from evaluation.voice.asr_reliability import compare_recheck, field_signals, without_outer_punctuation


def test_special_tokens_and_cross_segment_evidence_are_mapped() -> None:
    row = {
        "rawText": "Pain on walking. No fever.",
        "asrSegments": [
            {
                "text": "<|0.00|> Pain on walking.<|1.50|>",
                "avgLogprob": -0.2,
                "temperature": 0,
                "compressionRatio": 1.1,
            },
            {"text": "<|2.00|> No fever.<|3.00|>", "avgLogprob": -0.4, "temperature": 0, "compressionRatio": 1.2},
        ],
        "asrRechecks": [{"repeatedText": "Pain on walking."}, {"repeatedText": "Fever."}],
    }
    signals = field_signals(row, "Pain on walking. No fever.")
    assert signals is not None
    assert signals["minimumAverageLogProbability"] == -0.4
    assert signals["consistentOnRecheck"] is False


def test_repeated_quote_or_missing_segments_cannot_supply_a_signal() -> None:
    assert field_signals({"rawText": "No pain. No pain.", "asrSegments": []}, "No pain.") is None
    assert field_signals({"rawText": "No pain.", "asrSegments": []}, "No pain.") is None


def test_absence_gate_preserves_the_swift_unicode_punctuation_behavior() -> None:
    assert without_outer_punctuation("– жалоб нет.") == "жалоб нет"
    assert without_outer_punctuation("− жалоб нет") == "− жалоб нет"


def test_segment_gap_inside_evidence_cannot_supply_a_signal() -> None:
    row = {
        "rawText": "Weight not 82 kg.",
        "asrSegments": [
            {"text": "Weight", "avgLogprob": -0.1, "temperature": 0, "compressionRatio": 1.1},
            {"text": "82 kg.", "avgLogprob": -0.1, "temperature": 0, "compressionRatio": 1.1},
        ],
        "asrRechecks": [{"repeatedText": "Weight"}, {"repeatedText": "82 kg."}],
    }
    assert field_signals(row, row["rawText"]) is None


def test_ablation_includes_fields_excluded_by_an_unstable_repeat() -> None:
    row = {
        "id": "example",
        "pack": "guided-format",
        "locale": "en",
        "status": "ok",
        "rawText": "Weight 82 kg.",
        "automaticFieldIds": [],
        "asrRecheckSeconds": 2,
        "asrSegments": [{"text": "Weight 82 kg.", "avgLogprob": -0.1, "temperature": 0, "compressionRatio": 1.1}],
        "asrRechecks": [{"repeatedText": "Weight 182 kg."}],
        "response": {
            "proposals": [
                {"field_id": "patient_weight_kg", "value": 82, "evidence": "Weight 82 kg.", "accuracy": "full"}
            ]
        },
        "score": {"matches": {"patientWeightKG": True}},
    }
    result = compare_recheck({"results": [row]})
    assert result["withRecheck"] == {"automaticFields": 0, "wrongAutomaticFields": 0}
    assert result["withoutRecheck"] == {"automaticFields": 1, "wrongAutomaticFields": 0}
    assert result["observedPolicyMismatchFields"] == 0


def test_ablation_keeps_decoder_and_review_gates() -> None:
    row = {
        "id": "example",
        "pack": "free-speech",
        "locale": "en",
        "status": "ok",
        "rawText": "Patient Alex. Weight 82 kg.",
        "automaticFieldIds": [],
        "asrSegments": [
            {"text": "Patient Alex. Weight 82 kg.", "avgLogprob": -0.1, "temperature": 0, "compressionRatio": 1.1}
        ],
        "asrRechecks": [{"repeatedText": "Patient Alex. Weight 82 kg."}],
        "response": {
            "proposals": [
                {"field_id": "patient_name", "value": "Alex", "evidence": "Patient Alex.", "accuracy": "full"},
                {"field_id": "patient_weight_kg", "value": 82, "evidence": "Weight 82 kg.", "accuracy": "questionable"},
            ]
        },
        "score": {"matches": {"patientName": True, "patientWeightKG": True}},
    }
    result = compare_recheck({"results": [row]})
    assert result["withoutRecheck"]["automaticFields"] == 0
