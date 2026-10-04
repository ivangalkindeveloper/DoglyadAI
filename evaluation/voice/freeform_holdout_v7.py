from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from evaluation.voice.common import FIELD_IDS, ROOT, load_catalog, make_source
from evaluation.voice.generate import OUTPUT_DIR, file_sha256, jsonl_bytes, write_corpus

SPLIT = "freeformHoldoutV7"
SOURCE = ROOT / "evaluation/voice/freeform_holdout_v7.py"
PARTIAL_FIELDS = ("examinationNumber", "patientWeightKG", "patientComplaints", "examinationDescription")
NAMES = {
    "en": {"male": "Daniel Foster", "female": "Sophia Turner"},
    "ru": {"male": "Павел Морозов", "female": "Елена Федорова"},
}


def _render(locale: str, full: bool, ordinal: int, spoken: dict[str, str]) -> str:
    number = spoken["examinationNumber"]
    name = spoken["patientName"]
    gender = spoken["patientGender"]
    birth = spoken["patientDateOfBirth"]
    height = spoken["patientHeightCM"]
    weight = spoken["patientWeightKG"]
    complaint = spoken["patientComplaints"]
    description = spoken["examinationDescription"]
    variant = ordinal % 3
    if locale == "en":
        if full and variant == 0:
            return (
                f"Case {number}: {name} is the patient, sex {gender}, date of birth {birth}. "
                f"Stature {height}; body mass {weight}. The patient complains of {complaint}. "
                f"Ultrasound demonstrates {description}"
            )
        if full and variant == 1:
            return (
                f"Today's scan is numbered {number}. It concerns {name}, {gender}, born {birth}. "
                f"The chart gives a height of {height} and weight of {weight}. "
                f"Symptoms are {complaint}. Imaging revealed {description}"
            )
        if full:
            return (
                f"Regarding patient {name}: {gender}, birth date {birth}, height {height}, "
                f"weight {weight}. Indication: {complaint}. Examination {number}. "
                f"The ultrasound examination found {description}"
            )
        if variant == 0:
            return (
                f"Recorded as case {number}; the complaint is {complaint}. "
                f"The images show {description} The patient weighs {weight}."
            )
        if variant == 1:
            return (
                f"At {weight} body weight, the patient reports {complaint}. "
                f"Ultrasound demonstrates {description} Reference number {number}."
            )
        return (
            f"The scan found {description} For this visit, the concern was {complaint}, "
            f"the weight was {weight}, and the case number was {number}."
        )
    if full and variant == 0:
        return (
            f"Случай номер {number}: пациент {name}, пол {gender}, дата рождения {birth}. "
            f"Рост {height}, масса {weight}. Жалуется на {complaint}. "
            f"Ультразвук выявил {description}"
        )
    if full and variant == 1:
        return (
            f"Сегодняшнему исследованию присвоен номер {number}. Пациент {name}, {gender}, "
            f"родился {birth}. В карте указаны рост {height} и вес {weight}. "
            f"Повод обследования: {complaint}. При УЗ-исследовании обнаружено {description}"
        )
    if full:
        return (
            f"Речь о пациенте {name}: {gender}, дата рождения {birth}, рост {height}, "
            f"вес {weight}. Беспокоят {complaint}. Номер обследования {number}. "
            f"Ультразвуковая картина следующая: {description}"
        )
    if variant == 0:
        return (
            f"Карточка номер {number}; пациент жалуется на {complaint}. "
            f"На снимках видно {description} Масса пациента {weight}."
        )
    if variant == 1:
        return (
            f"Вес пациента {weight}, со слов пациента {complaint}. "
            f"Ультразвук выявил {description} Номер протокола {number}."
        )
    return f"Исследование показало {description} Жалобы: {complaint}; масса тела {weight}; номер случая {number}."


def make_cases() -> list[dict[str, Any]]:
    type_ids, terms = load_catalog()
    cases: list[dict[str, Any]] = []
    for locale in ("en", "ru"):
        for ordinal, type_id in enumerate(type_ids):
            for index in (0, 1):
                values, spoken, facts = make_source(
                    "freeform-holdout-v7",
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
                text = _render(locale, index == 0, ordinal, spoken)
                expected = {field: values[field] for field in included}
                sources = {field: spoken[field] for field in included}
                if any(source not in text for source in sources.values()):
                    raise ValueError(f"Expected field lacks a source in {locale}/{type_id}/{index}")
                cases.append(
                    {
                        "id": f"holdoutV7-{locale}-{type_id}-{index:02d}",
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
    (output / "freeform-holdout-v7-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    manifest = write_cases()
    print(f"Generated {manifest['cases']} untouched text holdout cases; SHA-256 {manifest['corpusSha256']}")


if __name__ == "__main__":
    main()
