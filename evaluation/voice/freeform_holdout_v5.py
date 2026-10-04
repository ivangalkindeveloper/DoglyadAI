from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from evaluation.voice.common import FIELD_IDS, ROOT, load_catalog, make_source
from evaluation.voice.generate import OUTPUT_DIR, file_sha256, jsonl_bytes, write_corpus

SPLIT = "freeformHoldoutV5"
SOURCE = ROOT / "evaluation/voice/freeform_holdout_v5.py"
PARTIAL_FIELDS = ("examinationNumber", "patientWeightKG", "patientComplaints", "examinationDescription")
NAMES = {
    "en": {"male": "Daniel Harris", "female": "Emma Brooks"},
    "ru": {"male": "Игорь Смирнов", "female": "Мария Белова"},
}


def _render(locale: str, index: int, ordinal: int, spoken: dict[str, str]) -> str:
    number = spoken["examinationNumber"]
    name = spoken["patientName"]
    birth = spoken["patientDateOfBirth"]
    gender = spoken["patientGender"]
    height = spoken["patientHeightCM"]
    weight = spoken["patientWeightKG"]
    complaint = spoken["patientComplaints"]
    description = spoken["examinationDescription"]
    if locale == "en":
        if index == 0 and ordinal % 2 == 0:
            return (
                f"Regarding {name}, {gender}, birth date {birth}: today's ultrasound is numbered {number}. "
                f"Height {height} and weight {weight}. The patient reports {complaint}. "
                f"Imaging findings: {description}"
            )
        if index == 0:
            return (
                f"For {name}, born {birth}, {gender}, examination {number} was performed. "
                f"At {height} and {weight}, the reason for referral was {complaint}. "
                f"Imaging demonstrated {description}"
            )
        if ordinal % 2 == 0:
            return f"Under number {number}, imaging demonstrated {description} Reported symptom: {complaint}. Current weight {weight}."
        return f"The patient weighing {weight} reports {complaint}. Examination {number}: {description}"
    if index == 0 and ordinal % 2 == 0:
        return (
            f"Сегодня обследовали {name}, {gender}, {birth} года рождения. Протокол номер {number}. "
            f"Рост {height}, вес {weight}. Причина обращения: {complaint}. "
            f"На эхограмме {description}"
        )
    if index == 0:
        return (
            f"Для {name}, дата рождения {birth}, {gender}, выполнено УЗИ номер {number}. "
            f"При росте {height} и весе {weight} беспокоит {complaint}. "
            f"УЗ-картина: {description}"
        )
    if ordinal % 2 == 0:
        return f"Протокол {number}. УЗ-картина: {description} Пациент жалуется на {complaint}, вес {weight}."
    return f"При весе {weight} пациент отмечает {complaint}. Исследование под номером {number} показало {description}"


def make_cases() -> list[dict[str, Any]]:
    type_ids, terms = load_catalog()
    cases = []
    for locale in ("en", "ru"):
        for ordinal, type_id in enumerate(type_ids):
            for index in (0, 1):
                values, spoken, facts = make_source(
                    "freeform-holdout-v5",
                    locale,
                    type_id,
                    index,
                    terms,
                    side="left" if index == 0 else "right",
                    correction=False,
                )
                name = NAMES[locale][values["patientGender"]]
                values["patientName"] = name
                spoken["patientName"] = name
                included = FIELD_IDS if index == 0 else PARTIAL_FIELDS
                text = _render(locale, index, ordinal, spoken)
                expected = {field: values[field] for field in included}
                sources = {field: spoken[field] for field in included}
                if any(source not in text for source in sources.values()):
                    raise ValueError(f"Expected field lacks a source in {locale}/{type_id}/{index}")
                cases.append(
                    {
                        "id": f"holdoutV5-{locale}-{type_id}-{index:02d}",
                        "split": SPLIT,
                        "scenario": "complete" if index == 0 else "partial",
                        "locale": locale,
                        "examinationTypeId": type_id,
                        "spokenText": text,
                        "expectedFields": expected,
                        "expectedSourceQuotes": sources,
                        "expectedFacts": facts,
                        "reviewReasons": [],
                    }
                )
    if len(cases) != 4 * len(type_ids) or len({case["id"] for case in cases}) != len(cases):
        raise ValueError("Holdout must contain one complete and one partial case per locale and type")
    return cases


def write_cases(output: Path = OUTPUT_DIR) -> dict[str, Any]:
    write_corpus(output)
    cases = make_cases()
    corpus_path = output / f"{SPLIT}.jsonl"
    contents = jsonl_bytes(cases)
    if corpus_path.exists() and corpus_path.read_bytes() != contents:
        raise ValueError("Frozen holdout differs from the generated cases")
    corpus_path.write_bytes(contents)
    manifest = {
        "schemaVersion": 1,
        "split": SPLIT,
        "cases": len(cases),
        "corpusSha256": file_sha256(corpus_path),
        "generatorSourceSha256": file_sha256(SOURCE),
        "catalogSha256": file_sha256(ROOT / "backend/main/config/development/ultrasound_examination_types.json"),
    }
    (output / "freeform-holdout-v5-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    manifest = write_cases()
    print(f"Generated {manifest['cases']} untouched text holdout cases; SHA-256 {manifest['corpusSha256']}")


if __name__ == "__main__":
    main()
