from __future__ import annotations

import json

from evaluation.voice.freeform_model import score_output


def test_mac_model_diagnostic_rejects_nonliteral_quotes_and_wrong_units() -> None:
    case = {
        "inputText": "This is study 007. The patient weighs 70 kilograms.",
        "expectedFields": {"examinationNumber": "007", "patientWeightKG": 70},
        "locale": "en",
    }
    output = json.dumps(
        [
            {"field_id": "examination_number", "value": "007", "evidence": "This is study 007", "accuracy": "full"},
            {"field_id": "patient_weight_kg", "value": 70, "evidence": "patient weighs 70 kg", "accuracy": "full"},
        ]
    )

    score = score_output(case, output)

    assert score["rawScore"]["equivalentExactCase"]
    assert not score["quotedScore"]["equivalentExactCase"]
    assert score["quoteRejected"] == ["patientWeightKG"]
