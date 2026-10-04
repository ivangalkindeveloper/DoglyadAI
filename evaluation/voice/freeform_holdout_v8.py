from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from evaluation.voice.common import FIELD_IDS, ROOT, load_catalog, make_source
from evaluation.voice.generate import OUTPUT_DIR, file_sha256, jsonl_bytes, write_corpus

SPLIT = "freeformHoldoutV8"
SOURCE = ROOT / "evaluation/voice/freeform_holdout_v8.py"
PARTIAL_FIELDS = ("examinationNumber", "patientWeightKG", "patientComplaints", "examinationDescription")
NAMES = {
    "en": {"male": "Oliver Brooks", "female": "Charlotte Hayes"},
    "ru": {"male": "Сергей Волков", "female": "Ирина Белова"},
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
                f"Protocol {number} concerns {name}. Their recorded sex is {gender}; birth date: {birth}. "
                f"Measured height {height}, measured weight {weight}. "
                f"Reason for examination: {complaint}. The sonogram describes {description}"
            )
        if full and variant == 1:
            return (
                f"I am examining {name}, {gender}, born {birth}. The registration number is {number}. "
                f"Height comes to {height} and weight comes to {weight}. "
                f"The chief complaint is {complaint}. Ultrasound assessment: {description}"
            )
        if full:
            return (
                f"Patient details: {name}, {gender}, born {birth}; height {height}; weight {weight}. "
                f"Visit number {number}. The reported problem is {complaint}. "
                f"The sonographic examination showed {description}"
            )
        if variant == 0:
            return (
                f"On the sonogram I see {description} This belongs to protocol {number}. "
                f"The symptom described was {complaint}; measured weight {weight}."
            )
        if variant == 1:
            return (
                f"The patient complains of {complaint}. They weigh {weight}. "
                f"Imaging assessment: {description} Registration number {number}."
            )
        return (
            f"Number {number}. Weight recorded at {weight}; reason for the scan: {complaint}. "
            f"The sonogram describes {description}"
        )
    if full and variant == 0:
        return (
            f"Протокол {number} составлен для {name}. Пол указан как {gender}, дата рождения {birth}. "
            f"Измеренный рост {height}, измеренный вес {weight}. Причина исследования: {complaint}. "
            f"Ультразвуковая картина показывает {description}"
        )
    if full and variant == 1:
        return (
            f"Осматриваю {name}, {gender}, дата рождения {birth}. Регистрационный номер {number}. "
            f"Рост равен {height}, вес равен {weight}. Основная жалоба — {complaint}. "
            f"На эхограмме видно {description}"
        )
    if full:
        return (
            f"Данные пациента: {name}, {gender}, родился {birth}; рост {height}; вес {weight}. "
            f"Номер визита {number}. Сообщает о {complaint}. "
            f"При ультразвуковом осмотре обнаружено {description}"
        )
    if variant == 0:
        return f"На эхограмме видно {description} Это протокол {number}. Из симптомов {complaint}, вес {weight}."
    if variant == 1:
        return (
            f"Жалуется на {complaint}. Вес составляет {weight}. "
            f"При ультразвуковом осмотре обнаружено {description} Регистрационный номер {number}."
        )
    return (
        f"Номер {number}, масса тела {weight}, повод обращения — {complaint}. "
        f"Ультразвуковая картина показывает {description}"
    )


def make_cases() -> list[dict[str, Any]]:
    type_ids, terms = load_catalog()
    cases: list[dict[str, Any]] = []
    for locale in ("en", "ru"):
        for ordinal, type_id in enumerate(type_ids):
            for index in (0, 1):
                values, spoken, facts = make_source(
                    "freeform-holdout-v8",
                    locale,
                    type_id,
                    index,
                    terms,
                    side="right" if index == 0 else "left",
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
                        "id": f"holdoutV8-{locale}-{type_id}-{index:02d}",
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
    (output / "freeform-holdout-v8-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    manifest = write_cases()
    print(f"Generated {manifest['cases']} untouched text holdout cases; SHA-256 {manifest['corpusSha256']}")


if __name__ == "__main__":
    main()
