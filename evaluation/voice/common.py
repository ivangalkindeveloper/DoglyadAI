from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
CONFIG_DIR = ROOT / "backend/main/config/development"
FIELD_IDS = (
    "examinationNumber",
    "patientName",
    "patientGender",
    "patientDateOfBirth",
    "patientHeightCM",
    "patientWeightKG",
    "patientComplaints",
    "examinationDescription",
)

LABELS = {
    "en": (
        "Examination number",
        "Patient",
        "Gender",
        "Date of birth",
        "Height",
        "Weight",
        "Complaints",
        "Examination description",
    ),
    "ru": (
        "Номер исследования",
        "Пациент",
        "Пол",
        "Дата рождения",
        "Рост",
        "Вес",
        "Жалобы",
        "Описание исследования",
    ),
}

# Each entry is (contextual-term index, inclusive minimum, inclusive maximum).
# These are fictional test values, chosen to keep the utterances plausible.
MEASUREMENT_PROFILES: dict[str, tuple[int, int, int]] = {
    "echocardiography": (0, 35, 55),
    "abdominalVessels": (0, 15, 25),
    "brachiocephalicVessels": (0, 5, 9),
    "intracanialArteries": (1, 40, 80),
    "renalArteries": (0, 4, 8),
    "arteriesOfTheUpperExtremities": (0, 5, 10),
    "arteriesOfTheLowerExtremities": (0, 6, 12),
    "veinsOfTheUpperExtremities": (0, 5, 12),
    "veinsOfTheLowerExtremities": (0, 6, 13),
    "abdominalCavity": (0, 120, 160),
    "hollowOrgansStomachAndIntestines": (4, 2, 6),
    "kidneysAdrenalGlandsAndRetroperitonealSpace": (0, 90, 120),
    "bladder": (3, 2, 6),
    "bladderWithResidualUrineDetermination": (0, 5, 80),
    "eye": (0, 20, 26),
    "sinuses": (10, 2, 7),
    "salivaryGlands": (0, 30, 55),
    "thyroidGland": (1, 35, 55),
    "neurosonography": (5, 2, 7),
    "thymusGland": (0, 20, 50),
    "lymphNodes": (0, 5, 20),
    "joints": (6, 2, 7),
    "hipJointsInNewborns": (8, 5, 15),
    "softTissues": (2, 5, 30),
    "pelvicOrgans": (15, 25, 45),
    "scrotum": (0, 35, 55),
    "mammaryGlands": (9, 5, 30),
    "pleuralRegion": (0, 1, 4),
    "pregnancyFirstTrimester": (0, 5, 30),
    "pregnancySecondTrimester": (0, 50, 90),
    "pregnancyThirdTrimester": (5, 80, 105),
}
SIDE_TYPES = {
    "echocardiography",
    "brachiocephalicVessels",
    "intracanialArteries",
    "renalArteries",
    "arteriesOfTheUpperExtremities",
    "arteriesOfTheLowerExtremities",
    "veinsOfTheUpperExtremities",
    "veinsOfTheLowerExtremities",
    "kidneysAdrenalGlandsAndRetroperitonealSpace",
    "eye",
    "salivaryGlands",
    "thyroidGland",
    "neurosonography",
    "thymusGland",
    "pelvicOrgans",
    "scrotum",
}
UNITS = {
    "intracanialArteries": {"en": "cm/s", "ru": "см/с"},
    "bladderWithResidualUrineDetermination": {"en": "ml", "ru": "мл"},
}


def load_catalog() -> tuple[list[str], dict[str, dict[str, list[str]]]]:
    groups = json.loads((CONFIG_DIR / "ultrasound_examination_types.json").read_text(encoding="utf-8"))
    type_ids = [item["id"] for group in groups for item in group["examinationTypes"]]
    if len(type_ids) != len(set(type_ids)):
        raise ValueError("Duplicate examination type ID")
    if set(type_ids) != set(MEASUREMENT_PROFILES):
        raise ValueError("Every examination type needs a measurement profile")
    terms = {
        language: json.loads(
            (CONFIG_DIR / language / "l10n_ultrasound_examination_contextual_strings.json").read_text(encoding="utf-8")
        )
        for language in LABELS
    }
    for language, by_type in terms.items():
        if set(by_type) != set(type_ids):
            raise ValueError(f"Contextual terms differ from examination types for {language}")
        if any(not by_type[type_id] for type_id in type_ids):
            raise ValueError(f"Empty contextual terms for {language}")
        if any(MEASUREMENT_PROFILES[type_id][0] >= len(by_type[type_id]) for type_id in type_ids):
            raise ValueError(f"Measurement term is missing for {language}")
    return type_ids, terms


def load_examination_titles() -> dict[str, dict[str, str]]:
    groups = json.loads((CONFIG_DIR / "ultrasound_examination_types.json").read_text(encoding="utf-8"))
    types = [item for group in groups for item in group["examinationTypes"]]
    titles: dict[str, dict[str, str]] = {}
    for locale in LABELS:
        strings = json.loads((CONFIG_DIR / locale / "l10n.json").read_text(encoding="utf-8"))
        titles[locale] = {item["id"]: strings[item["titleLocaleKey"]] for item in types}
    return titles


def seeded_random(split: str, locale: str, type_id: str, index: int) -> random.Random:
    seed = hashlib.sha256(f"voice-v1:{split}:{locale}:{type_id}:{index}".encode()).digest()
    return random.Random(int.from_bytes(seed[:8], "big"))


SIDE_PREFIXES: dict[str, dict[str, tuple[str, ...]]] = {
    "en": {"right": ("right ",), "left": ("left ",)},
    "ru": {
        "right": ("правая ", "правый ", "правое ", "правой ", "правого "),
        "left": ("левая ", "левый ", "левое ", "левой ", "левого "),
    },
}


def _side_of(term: str, locale: str) -> str | None:
    for side, prefixes in SIDE_PREFIXES[locale].items():
        if term.startswith(prefixes):
            return side
    return None


def _term_index(type_id: str, terms: dict[str, dict[str, list[str]]], locale: str, side: str | None) -> int:
    if side is not None and type_id in SIDE_TYPES:
        by_side: dict[str, dict[str, int]] = {candidate: {} for candidate in ("right", "left")}
        for index, term in enumerate(terms[locale][type_id]):
            for candidate, prefixes in SIDE_PREFIXES[locale].items():
                for prefix in prefixes:
                    if term.startswith(prefix):
                        by_side[candidate][term.removeprefix(prefix)] = index
        paired = by_side["right"].keys() & by_side["left"].keys()
        if paired:
            suffix = min(paired, key=lambda item: (by_side["right"][item], item))
            return by_side[side][suffix]
    return MEASUREMENT_PROFILES[type_id][0]


def _russian_count(value: int, singular: str, few: str, many: str) -> str:
    if value % 100 in (11, 12, 13, 14):
        return many
    if value % 10 == 1:
        return singular
    if value % 10 in (2, 3, 4):
        return few
    return many


def _number_words(value: int, locale: str) -> str:
    ones = {
        "en": (
            "",
            "one",
            "two",
            "three",
            "four",
            "five",
            "six",
            "seven",
            "eight",
            "nine",
            "ten",
            "eleven",
            "twelve",
            "thirteen",
            "fourteen",
            "fifteen",
            "sixteen",
            "seventeen",
            "eighteen",
            "nineteen",
        ),
        "ru": (
            "",
            "один",
            "два",
            "три",
            "четыре",
            "пять",
            "шесть",
            "семь",
            "восемь",
            "девять",
            "десять",
            "одиннадцать",
            "двенадцать",
            "тринадцать",
            "четырнадцать",
            "пятнадцать",
            "шестнадцать",
            "семнадцать",
            "восемнадцать",
            "девятнадцать",
        ),
    }
    tens = {
        "en": ("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"),
        "ru": (
            "",
            "",
            "двадцать",
            "тридцать",
            "сорок",
            "пятьдесят",
            "шестьдесят",
            "семьдесят",
            "восемьдесят",
            "девяносто",
        ),
    }
    if not 1 <= value <= 199:
        raise ValueError(f"Unsupported spoken number: {value}")
    words: list[str] = []
    if value >= 100:
        words.append("one hundred" if locale == "en" else "сто")
        value %= 100
    if value >= 20:
        words.append(tens[locale][value // 10])
        value %= 10
    if value:
        words.append(ones[locale][value])
    return " ".join(words)


def make_source(
    split: str,
    locale: str,
    type_id: str,
    index: int,
    terms: dict[str, dict[str, list[str]]],
    *,
    side: str | None = None,
    correction: bool = False,
    words: bool = False,
) -> tuple[dict[str, Any], dict[str, str], list[dict[str, Any]]]:
    """Choose structured truth before rendering any dictation text."""
    rng = seeded_random(split, locale, type_id, index)
    gender = (
        "female"
        if type_id.startswith("pregnancy") or type_id == "pelvicOrgans"
        else "male"
        if type_id == "scrotum"
        else rng.choice(("male", "female"))
    )
    names = {
        "en": {
            "male": ("Alex Morgan", "Daniel Reed", "Michael Taylor"),
            "female": ("Anna Morgan", "Maria Reed", "Emily Taylor"),
        },
        "ru": {
            "male": ("Иван Петров", "Алексей Смирнов", "Дмитрий Орлов"),
            "female": ("Анна Петрова", "Мария Смирнова", "Елена Орлова"),
        },
    }
    year = rng.randrange(1986, 2006) if type_id.startswith("pregnancy") else rng.randrange(1970, 2001)
    birth_date = f"{year}-{rng.randrange(1, 13):02d}-{rng.randrange(1, 29):02d}"
    if type_id == "hipJointsInNewborns":
        birth_date = f"2026-09-{rng.randrange(1, 21):02d}"
    height = rng.randrange(155, 191)
    weight = rng.randrange(52, 111)
    if type_id == "hipJointsInNewborns":
        height, weight = 54, 4
    number = f"{rng.randrange(1, 100):03d}"
    _, minimum, maximum = MEASUREMENT_PROFILES[type_id]
    measurement = rng.randrange(minimum, maximum + 1)
    unit = UNITS.get(type_id, {}).get(locale, "mm" if locale == "en" else "мм")
    term_index = _term_index(type_id, terms, locale, side)
    term = terms[locale][type_id][term_index]
    selected_side = _side_of(term, locale)
    negative = "No additional abnormality." if locale == "en" else "Дополнительных изменений не выявлено."

    facts: list[dict[str, Any]] = [
        {"kind": "measurement", "subject": term, "value": measurement, "unit": unit},
        {"kind": "negation", "subject": "additional abnormality"},
    ]
    if selected_side is not None:
        facts.append({"kind": "side", "value": selected_side})

    spoken_measurement = str(measurement)
    if words:
        spoken_measurement = _number_words(measurement, locale)
    if correction:
        wrong = measurement + 3
        spoken_measurement = f"{wrong}, no, {measurement}" if locale == "en" else f"{wrong}, нет, {measurement}"

    description = f"{term}: {spoken_measurement} {unit}. {negative}"
    expected_description = f"{term}: {measurement} {unit}. {negative}" if correction else description
    complaints = {
        "en": ("discomfort on the right", "intermittent pain", "no complaints", "swelling", "tenderness"),
        "ru": ("дискомфорт справа", "периодическая боль", "жалоб нет", "отёчность", "болезненность"),
    }
    complaint = (
        "no complaints"
        if type_id == "hipJointsInNewborns" and locale == "en"
        else ("жалоб нет" if type_id == "hipJointsInNewborns" else rng.choice(complaints[locale]))
    )
    spoken_gender = gender if locale == "en" else ("мужчина" if gender == "male" else "женщина")
    name = rng.choice(names[locale][gender])
    values: dict[str, Any] = {
        "examinationNumber": number,
        "patientName": name,
        "patientGender": gender,
        "patientDateOfBirth": birth_date,
        "patientHeightCM": height,
        "patientWeightKG": weight,
        "patientComplaints": complaint,
        "examinationDescription": expected_description,
    }
    spoken: dict[str, str] = {
        "examinationNumber": number,
        "patientName": name,
        "patientGender": spoken_gender,
        "patientDateOfBirth": birth_date,
        "patientHeightCM": (
            f"{height} centimeters"
            if locale == "en"
            else f"{height} {_russian_count(height, 'сантиметр', 'сантиметра', 'сантиметров')}"
        ),
        "patientWeightKG": (
            f"{weight} kilograms"
            if locale == "en"
            else f"{weight} {_russian_count(weight, 'килограмм', 'килограмма', 'килограммов')}"
        ),
        "patientComplaints": complaint,
        "examinationDescription": description,
    }
    return values, spoken, facts


def render_case(
    *,
    split: str,
    locale: str,
    type_id: str,
    index: int,
    scenario: str,
    values: dict[str, Any],
    spoken: dict[str, str],
    facts: list[dict[str, Any]],
    included: tuple[str, ...],
    order: tuple[str, ...],
    separator: str,
    extra: str = "",
    review_reasons: tuple[str, ...] = (),
) -> dict[str, Any]:
    labels = dict(zip(FIELD_IDS, LABELS[locale], strict=True))
    parts = [f"{labels[field]}: {spoken[field]}" for field in order if field in included]
    if extra:
        parts.append(extra)
    text = separator.join(parts)
    if not text.endswith("."):
        text += "."
    expected = {field: values[field] for field in FIELD_IDS if field in included and field in values}
    sources = {field: spoken[field] for field in expected}
    return {
        "id": f"{split}-{locale}-{type_id}-{index:02d}",
        "split": split,
        "scenario": scenario,
        "locale": locale,
        "examinationTypeId": type_id,
        "spokenText": text,
        "expectedFields": expected,
        "expectedSourceQuotes": sources,
        "expectedFacts": facts if "examinationDescription" in expected else [],
        "reviewReasons": list(review_reasons),
    }
