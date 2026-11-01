from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from evaluation.voice.datasets.clinical_corpus import validate_corpus
from evaluation.voice.datasets.clinical_profiles import PROFILES


def clinical_pilot() -> dict[str, Any]:
    cases = []
    for type_id, context, russian, english in PROFILES:
        for locale, text in (("ru", russian), ("en", english)):
            family = "clinical-pilot-v2-" + type_id
            cases.append(
                {
                    "id": family + "-" + locale,
                    "familyId": family,
                    "clusterId": family,
                    "locale": locale,
                    "examinationTypeId": type_id,
                    "clinicalContext": context,
                    "sourceKind": "synthetic",
                    "split": "development",
                    "isPreviouslyExposed": True,
                    "mode": "clinical-pilot-v2",
                    "variant": "text",
                    "referenceText": text,
                    "inputText": text,
                    "expectedFields": {"examinationDescription": text},
                    "fieldEvidence": {"examinationDescription": [text]},
                    "clinicalGold": {
                        "examinationDescription": {
                            "reviewStatus": "draft",
                            "isComplete": False,
                            "facts": [{"id": "description", "sourceQuote": text, "acceptedTexts": []}],
                        }
                    },
                    "goldReview": {"status": "pending", "reviewerIds": []},
                    "expectedActions": {"examinationDescription": {"action": "accept"}},
                }
            )
    # Explicit correction keeps reliable data. Ambiguity affects only its field.
    for locale, text, description, number_quote in (
        (
            "ru",
            "Номер исследования 0184. Левая почка 112 мм, поправка: правая почка 112 мм. Левую ещё не измерял.",
            "Правая почка 112 мм. Левую ещё не измерял.",
            "0184",
        ),
        (
            "en",
            "Study number 0184. Left kidney 112 mm, correction: right kidney 112 mm. The left has not yet been measured.",
            "right kidney 112 mm. The left has not yet been measured.",
            "0184",
        ),
    ):
        family = "clinical-pilot-v2-explicit-correction"
        cases.append(
            {
                "id": family + "-" + locale,
                "familyId": family,
                "clusterId": family,
                "locale": locale,
                "examinationTypeId": "kidneysAdrenalGlandsAndRetroperitonealSpace",
                "clinicalContext": {"ageYears": 45},
                "sourceKind": "synthetic",
                "split": "development",
                "isPreviouslyExposed": True,
                "mode": "clinical-pilot-v2",
                "variant": "text",
                "referenceText": text,
                "inputText": text,
                "expectedFields": {"examinationNumber": "0184", "examinationDescription": description},
                "fieldEvidence": {
                    "examinationNumber": [number_quote],
                    "examinationDescription": [text[text.index("112") :]],
                },
                "clinicalGold": {
                    "examinationDescription": {
                        "reviewStatus": "draft",
                        "isComplete": False,
                        "facts": [{"id": "corrected-description", "sourceQuote": description}],
                    }
                },
                "goldReview": {"status": "pending", "reviewerIds": []},
                "expectedActions": {
                    "examinationNumber": {"action": "accept"},
                    "examinationDescription": {"action": "accept"},
                },
            }
        )
    corpus = {
        "schemaVersion": 2,
        "corpusVersion": "clinical-pilot-v2-draft-1",
        "purpose": "Medical-review starting points for 31 examination types, not a representative test or a blind holdout. No audio has been generated. Facts and clinical actions remain provisional until independent review.",
        "cases": cases,
    }
    corpus["validation"] = validate_corpus(corpus)
    return corpus


def main() -> None:
    parser = argparse.ArgumentParser(description="Create explicit draft clinical profiles for physician review")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    with args.output.open("x", encoding="utf-8") as destination:
        destination.write(json.dumps(clinical_pilot(), ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
