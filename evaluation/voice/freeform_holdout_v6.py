from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from evaluation.voice.common import FIELD_IDS, ROOT, load_catalog, make_source
from evaluation.voice.generate import OUTPUT_DIR, file_sha256, jsonl_bytes, write_corpus

SPLIT = "freeformHoldoutV6"
SOURCE = ROOT / "evaluation/voice/freeform_holdout_v6.py"
PARTIAL_FIELDS = ("examinationNumber", "patientWeightKG", "patientComplaints", "examinationDescription")
NAMES = {
    "en": {"male": "Thomas Bennett", "female": "Olivia Carter"},
    "ru": {"male": "Андрей Кузнецов", "female": "Наталья Соколова"},
}


def _render(locale: str, index: int, ordinal: int, spoken: dict[str, str]) -> str:
    number = spoken["examinationNumber"]
    name = spoken["patientName"]
    gender = spoken["patientGender"]
    birth = spoken["patientDateOfBirth"]
    height = spoken["patientHeightCM"]
    weight = spoken["patientWeightKG"]
    complaint = spoken["patientComplaints"]
    description = spoken["examinationDescription"]
    if locale == "en":
        if index == 0 and ordinal % 2 == 0:
            return (
                f"File reference {number} is for {name}, {gender}, born on {birth}. "
                f"Their height is {height}, with a body weight of {weight}. "
                f"The presenting concern is {complaint}. Sonographic observations: {description}"
            )
        if index == 0:
            return (
                f"We examined {name}, a {gender} patient whose birth date is {birth}. "
                f"The record carries number {number}. At {height} tall and {weight} in weight, "
                f"the patient describes {complaint}. The scan documented {description}"
            )
        if ordinal % 2 == 0:
            return (
                f"For the record marked {number}, the patient reports {complaint}. "
                f"Sonography documented {description} Their measured weight is {weight}."
            )
        return (
            f"The reason for this visit is {complaint}; body weight measures {weight}. "
            f"On imaging, {description} This was filed as study {number}."
        )
    if index == 0 and ordinal % 2 == 0:
        return (
            f"Протокол под номером {number} относится к пациенту {name}, {gender}, "
            f"дата рождения {birth}. Рост составляет {height}, масса тела {weight}. "
            f"Повод для обращения: {complaint}. При сонографии отмечено {description}"
        )
    if index == 0:
        return (
            f"Осмотрен пациент {name}, {gender}, родился {birth}. Исследование зарегистрировано "
            f"за номером {number}. Его рост {height}, весит {weight}; беспокоит {complaint}. "
            f"Ультразвуковое исследование показало {description}"
        )
    if ordinal % 2 == 0:
        return (
            f"По протоколу {number} пациент отмечает {complaint}. "
            f"Сонография показала {description} Измеренная масса тела {weight}."
        )
    return (
        f"Причина визита — {complaint}, текущий вес {weight}. "
        f"При визуализации отмечено {description} Запись оформлена под номером {number}."
    )


def make_cases() -> list[dict[str, Any]]:
    type_ids, terms = load_catalog()
    cases: list[dict[str, Any]] = []
    for locale in ("en", "ru"):
        for ordinal, type_id in enumerate(type_ids):
            for index in (0, 1):
                values, spoken, facts = make_source(
                    "freeform-holdout-v6",
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
                text = _render(locale, index, ordinal, spoken)
                expected = {field: values[field] for field in included}
                sources = {field: spoken[field] for field in included}
                if any(source not in text for source in sources.values()):
                    raise ValueError(f"Expected field lacks a source in {locale}/{type_id}/{index}")
                cases.append(
                    {
                        "id": f"holdoutV6-{locale}-{type_id}-{index:02d}",
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
    (output / "freeform-holdout-v6-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    manifest = write_cases()
    print(f"Generated {manifest['cases']} untouched text holdout cases; SHA-256 {manifest['corpusSha256']}")


if __name__ == "__main__":
    main()
