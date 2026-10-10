from __future__ import annotations

import argparse
import json
import re
from datetime import date
from typing import Any

from evaluation.voice.audio_script_v2 import DIGIT_WORDS
from evaluation.voice.common import ROOT, _number_words
from evaluation.voice.end_to_end import sha256, synthesize_rows

MONTHS = (
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
)
ORDINAL = (
    "",
    "первого",
    "второго",
    "третьего",
    "четвёртого",
    "пятого",
    "шестого",
    "седьмого",
    "восьмого",
    "девятого",
    "десятого",
    "одиннадцатого",
    "двенадцатого",
    "тринадцатого",
    "четырнадцатого",
    "пятнадцатого",
    "шестнадцатого",
    "семнадцатого",
    "восемнадцатого",
    "девятнадцатого",
)
ORDINAL_TENS = {
    20: "двадцатого",
    30: "тридцатого",
    40: "сорокового",
    50: "пятидесятого",
    60: "шестидесятого",
    70: "семидесятого",
    80: "восьмидесятого",
    90: "девяностого",
}


def cardinal(value: int, locale: str) -> str:
    if value == 0:
        return DIGIT_WORDS[locale][0]
    if value < 200:
        return _number_words(value, locale)
    if value >= 1000:
        thousands, rest = divmod(value, 1000)
        head = (
            (
                "одна тысяча"
                if thousands == 1
                else "две тысячи"
                if thousands == 2
                else cardinal(thousands, locale) + (" тысячи" if thousands < 5 else " тысяч")
            )
            if locale == "ru"
            else cardinal(thousands, locale) + " thousand"
        )
        return head + (" " + cardinal(rest, locale) if rest else "")
    hundreds, rest = divmod(value, 100)
    head = (
        ("", "сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот")[
            hundreds
        ]
        if locale == "ru"
        else cardinal(hundreds, locale) + " hundred"
    )
    return head + (" " + cardinal(rest, locale) if rest else "")


def ordinal(value: int) -> str:
    if value < 20:
        return ORDINAL[value]
    tens, ones = divmod(value, 10)
    return cardinal(tens * 10, "ru") + " " + ORDINAL[ones] if ones else ORDINAL_TENS[value]


def spoken_date(value: date, locale: str) -> str:
    if locale == "en":
        # Cardinal day and a full year are natural English date readings.
        return f"{value.strftime('%B')} {cardinal(value.day, locale)}, {cardinal(value.year, locale)}"
    if not 1901 <= value.year <= 2099:
        raise ValueError("Natural-date renderer supports birth years 1901–2099")
    prefix = "тысяча девятьсот" if value.year < 2000 else "две тысячи"
    year = "двухтысячного" if value.year == 2000 else prefix + " " + ordinal(value.year % 100)
    return f"{ordinal(value.day)} {MONTHS[value.month - 1]} {year} года"


def spoken_script(text: str, fields: dict[str, Any], locale: str) -> str:
    if "patientDateOfBirth" in fields:
        birthday = date.fromisoformat(fields["patientDateOfBirth"])
        if locale == "ru":
            pattern = rf"\b{birthday.day}\s+{MONTHS[birthday.month - 1]}\s+{birthday.year}(?:\s+года)?\b"
        else:
            pattern = rf"\b{birthday.strftime('%B')}\s+{birthday.day},?\s+{birthday.year}\b"
        text = re.sub(pattern, spoken_date(birthday, locale), text, flags=re.IGNORECASE)
    if identifier := fields.get("examinationNumber"):
        if not str(identifier).isascii() or not str(identifier).isdigit():
            raise ValueError(
                "The main natural corpus uses numeric identifiers; letter IDs remain in the old stress corpus"
            )
        text = text.replace(str(identifier), " ".join(DIGIT_WORDS[locale][int(digit)] for digit in str(identifier)))

    def decimal(match: re.Match[str]) -> str:
        whole, fraction = re.split("[.,]", match.group())
        if locale == "en":
            return cardinal(int(whole), locale) + " point " + " ".join(DIGIT_WORDS[locale][int(d)] for d in fraction)
        if len(fraction) != 1:
            raise ValueError("Unexpected decimal precision")
        numerator = {"1": "одна", "2": "две"}.get(fraction, cardinal(int(fraction), locale))
        return cardinal(int(whole), locale) + " целых " + numerator + (" десятая" if fraction == "1" else " десятых")

    text = re.sub(r"(?<![\w.])\d+[.,]\d+(?!\w)", decimal, text)
    units = (
        {"mm2": "square millimeters", "mm": "millimeters", "ml": "milliliters", "cm": "centimeters", "kg": "kilograms"}
        if locale == "en"
        else {
            "мм2": "квадратных миллиметров",
            "мм": "миллиметров",
            "мл": "миллилитров",
            "см": "сантиметров",
            "кг": "килограммов",
        }
    )
    for literal, pronunciation in units.items():
        text = re.sub(rf"\b{literal}\b", pronunciation, text, flags=re.IGNORECASE)
    text = re.sub(r"(?<![\w.])\d+(?![\w.])", lambda match: cardinal(int(match.group()), locale), text)
    return text


def formatted(fields: dict[str, Any], locale: str, reordered: bool) -> str:
    parts: dict[str, str] = {}
    if "examinationNumber" in fields:
        parts["examinationNumber"] = (
            ("Номер исследования" if locale == "ru" else "Examination number")
            + ": "
            + fields["examinationNumber"]
            + "."
        )
    if "patientName" in fields:
        parts["patientName"] = ("Пациент" if locale == "ru" else "Patient") + ": " + fields["patientName"] + "."
    if "patientGender" in fields:
        gender = (
            fields["patientGender"]
            if locale == "en"
            else ("мужчина" if fields["patientGender"] == "male" else "женщина")
        )
        parts["patientGender"] = ("Пол" if locale == "ru" else "Gender") + ": " + gender + "."
    if "patientDateOfBirth" in fields:
        birthday = date.fromisoformat(fields["patientDateOfBirth"])
        literal = (
            f"{birthday.day} {MONTHS[birthday.month - 1]} {birthday.year} года"
            if locale == "ru"
            else birthday.strftime("%B") + f" {birthday.day}, {birthday.year}"
        )
        parts["patientDateOfBirth"] = ("Дата рождения" if locale == "ru" else "Date of birth") + ": " + literal + "."
    for field, ru_label, en_label, ru_unit, en_unit in (
        ("patientHeightCM", "Рост", "Height", "сантиметров", "centimeters"),
        ("patientWeightKG", "Вес", "Weight", "килограммов", "kilograms"),
    ):
        if field in fields:
            parts[field] = (
                f"{ru_label if locale == 'ru' else en_label}: {fields[field]} {ru_unit if locale == 'ru' else en_unit}."
            )
    for field, ru_label, en_label in (
        ("patientComplaints", "Жалобы", "Complaints"),
        ("examinationDescription", "Описание исследования", "Examination description"),
    ):
        if field in fields:
            parts[field] = f"{ru_label if locale == 'ru' else en_label}: {fields[field]}"
    order = (
        (
            "examinationDescription",
            "patientWeightKG",
            "patientName",
            "patientComplaints",
            "patientDateOfBirth",
            "examinationNumber",
            "patientHeightCM",
            "patientGender",
        )
        if reordered
        else parts
    )
    return " ".join(parts[field] for field in order if field in parts)


def prepare(split: str) -> None:
    fixture = ROOT / (
        "build/voice-eval/device-end-to-end/cases.json"
        if split == "regression"
        else f"evaluation/voice/fixtures/natural_voice_{split}_v1.json"
    )
    data = json.loads(fixture.read_text())
    original = data["cases"] if split == "regression" else data
    rows = []
    for index, case in enumerate(original):
        fields = dict(case["expectedFields"])
        text = case["inputText"]
        if split == "regression" and "examinationNumber" in fields:
            replacement = str(4101 + int(case["id"].rsplit("-", 1)[1]) + (100 if case["locale"] == "en" else 0))
            text = text.replace(fields["examinationNumber"], replacement)
            fields["examinationNumber"] = replacement
        variants = [(case["pack"], text)] if split == "regression" else [("free-speech", text)]
        if split != "regression":
            variants += [
                ("guided-format", formatted(fields, case["locale"], False)),
                ("reordered-format", formatted(fields, case["locale"], True)),
            ]
        for pack, variant in variants:
            row = {
                **case,
                "id": f"natural-{split}-{index + 1:02d}-{pack}",
                "pack": pack,
                "inputText": variant,
                "expectedFields": fields,
                "spokenText": spoken_script(variant, fields, case["locale"]),
                "referenceKind": "intended-tts-words-not-human-transcription",
            }
            rows.append(row)
    output = ROOT / f"build/voice-eval/natural-{split}-v1"
    output.mkdir(parents=True, exist_ok=True)
    # Freeze gold and pronunciation scripts before inference or audio evaluation.
    frozen = output / "source-frozen.json"
    content = json.dumps({"fixtureSha256": sha256(fixture), "cases": rows}, ensure_ascii=False, indent=2) + "\n"
    if frozen.exists() and frozen.read_text() != content:
        raise ValueError("Frozen inputs differ")
    frozen.write_text(content)
    synthesize_rows(rows, output=output, fixture=fixture, manifest_name=f"natural-{split}-v1")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("split", choices=("regression", "control", "holdout"))
    args = parser.parse_args()
    prepare(args.split)


if __name__ == "__main__":
    main()
