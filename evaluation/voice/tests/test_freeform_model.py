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
        {
            "proposals": [
                {"fieldId": "examinationNumber", "value": "007", "sourceQuote": "This is study 007"},
                {"fieldId": "patientWeightKG", "value": "70", "sourceQuote": "patient weighs 70 kg"},
            ],
            "unmappedFindings": [],
        }
    )

    score = score_output(case, output)

    assert score["rawScore"]["equivalentExactCase"]
    assert not score["quotedScore"]["equivalentExactCase"]
    assert score["quoteRejected"] == ["patientWeightKG"]
