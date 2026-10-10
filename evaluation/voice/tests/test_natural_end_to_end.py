from __future__ import annotations

import json

from evaluation.voice.common import ROOT
from evaluation.voice.natural_end_to_end import formatted, spoken_date, spoken_script
from datetime import date


def test_natural_script_preserves_fraction_and_birth_date() -> None:
    fields = {"examinationNumber": "7482", "patientDateOfBirth": "1982-10-18"}
    result = spoken_script("Номер исследования 7482. Родился 18 октября 1982 года. Вес 81.3 кг.", fields, "ru")
    assert "семь четыре восемь два" in result
    assert "восемнадцатого октября тысяча девятьсот восемьдесят второго года" in result
    assert "восемьдесят один целых три десятых килограммов" in result
    assert "81.3" not in result


def test_dates_are_calendar_dates_not_groups_of_digits() -> None:
    assert spoken_date(date(2000, 1, 1), "ru") == "первого января двухтысячного года"
    assert spoken_date(date(1994, 3, 28), "en") == "March twenty eight, one thousand nine hundred ninety four"


def test_frozen_control_has_three_styles_and_partial_values() -> None:
    rows = json.loads((ROOT / "evaluation/voice/fixtures/natural_voice_control_v1.json").read_text())
    assert len(rows) == 8
    assert {row["locale"] for row in rows} == {"ru", "en"}
    assert any(len(row["expectedFields"]) < 8 for row in rows)
    for row in rows:
        rendered = spoken_script(row["inputText"], row["expectedFields"], row["locale"])
        assert rendered
        assert row["expectedFields"]
        assert all(isinstance(value, (str, int, float)) for value in row["expectedFields"].values())


def test_new_holdout_is_disjoint_and_has_complete_partial_and_profile_cases() -> None:
    fixture_dir = ROOT / "evaluation/voice/fixtures"
    rows = json.loads((fixture_dir / "natural_voice_holdout_v1.json").read_text())
    previous = json.loads((fixture_dir / "natural_voice_control_v1.json").read_text())
    assert len(rows) == 12
    assert not {row["id"] for row in rows} & {row["id"] for row in previous}
    assert not {row["inputText"] for row in rows} & {row["inputText"] for row in previous}
    catalogs = {
        locale: json.loads(
            (
                ROOT / f"backend/main/config/development/{locale}/l10n_ultrasound_examination_contextual_strings.json"
            ).read_text()
        )
        for locale in ("ru", "en")
    }
    for locale in ("ru", "en"):
        subset = [row for row in rows if row["locale"] == locale]
        assert len(subset) == 6
        assert sum(row["category"] == "complete" for row in subset) == 3
        assert sum(len(row["expectedFields"]) for row in subset) == 33
    for row in rows:
        assert row["examinationTypeId"] in catalogs[row["locale"]]
        variants = [
            row["inputText"],
            *(formatted(row["expectedFields"], row["locale"], order) for order in (False, True)),
        ]
        assert len(set(variants)) == 3
        for variant in variants:
            assert spoken_script(variant, row["expectedFields"], row["locale"])
