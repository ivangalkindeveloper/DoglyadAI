from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from evaluation.voice.common import FIELD_IDS, ROOT, load_catalog, make_source
from evaluation.voice.generate import OUTPUT_DIR, file_sha256, jsonl_bytes, write_corpus

SPLIT = "freeformDevelopment"
SOURCE = ROOT / "evaluation/voice/freeform_development.py"
PARTIAL_FIELDS = ("examinationNumber", "patientWeightKG", "patientComplaints", "examinationDescription")


def make_cases() -> list[dict[str, Any]]:
    type_ids, terms = load_catalog()
    cases = []
    for locale in ("en", "ru"):
        for type_id in type_ids:
            for index in (0, 1):
                values, spoken, facts = make_source(
                    "freeform-development-v1",
                    locale,
                    type_id,
                    index,
                    terms,
                    side="right" if index == 0 else "left",
                    correction=index == 1,
                )
                included = FIELD_IDS if index == 0 else PARTIAL_FIELDS
                if locale == "en":
                    text = (
                        f"For {spoken['patientName']}, born {spoken['patientDateOfBirth']}, "
                        f"the recorded sex is {spoken['patientGender']}. "
                        f"They are {spoken['patientHeightCM']} tall and weigh {spoken['patientWeightKG']}. "
                        f"This is study {spoken['examinationNumber']}. "
                        f"They report {spoken['patientComplaints']}. On ultrasound, "
                        f"{spoken['examinationDescription']}"
                        if index == 0
                        else (
                            f"On ultrasound, {spoken['examinationDescription']} "
                            f"This is study {spoken['examinationNumber']}; "
                            f"they report {spoken['patientComplaints']} and weigh {spoken['patientWeightKG']}."
                        )
                    )
                else:
                    text = (
                        f"На приёме {spoken['patientName']}, {spoken['patientDateOfBirth']} года рождения, "
                        f"{spoken['patientGender']}. Рост {spoken['patientHeightCM']}, "
                        f"вес {spoken['patientWeightKG']}. Это исследование номер "
                        f"{spoken['examinationNumber']}. Сообщает: {spoken['patientComplaints']}. "
                        f"На УЗИ {spoken['examinationDescription']}"
                        if index == 0
                        else (
                            f"На УЗИ {spoken['examinationDescription']} "
                            f"Это исследование номер {spoken['examinationNumber']}; "
                            f"сообщает: {spoken['patientComplaints']}, вес {spoken['patientWeightKG']}."
                        )
                    )
                expected = {field: values[field] for field in included}
                sources = {field: spoken[field] for field in included}
                if any(source not in text for source in sources.values()):
                    raise ValueError("Every expected field must have a source quote")
                cases.append(
                    {
                        "id": f"freeformDev-{locale}-{type_id}-{index:02d}",
                        "split": SPLIT,
                        "scenario": "complete" if index == 0 else "partial",
                        "locale": locale,
                        "examinationTypeId": type_id,
                        "spokenText": text,
                        "expectedFields": expected,
                        "expectedSourceQuotes": sources,
                        "expectedFacts": facts,
                        "reviewReasons": ["numericSelfCorrection"] if index == 1 else [],
                    }
                )
    if len(cases) != 4 * len(type_ids) or len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Freeform corpus is not balanced")
    return cases


def write_cases(output: Path = OUTPUT_DIR) -> dict[str, Any]:
    write_corpus(output)
    cases = make_cases()
    corpus_path = output / f"{SPLIT}.jsonl"
    corpus_path.write_bytes(jsonl_bytes(cases))
    manifest = {
        "schemaVersion": 1,
        "split": SPLIT,
        "cases": len(cases),
        "corpusSha256": file_sha256(corpus_path),
        "generatorSourceSha256": file_sha256(SOURCE),
        "catalogSha256": file_sha256(ROOT / "backend/main/config/development/ultrasound_examination_types.json"),
    }
    (output / "freeform-development-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    manifest = write_cases()
    print(f"Generated {manifest['cases']} freeform development cases; SHA-256 {manifest['corpusSha256']}")


if __name__ == "__main__":
    main()
