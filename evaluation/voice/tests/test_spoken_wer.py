from __future__ import annotations

from evaluation.voice.spoken_wer import spoken_normalized_wer


def test_numeric_display_and_unit_abbreviation_do_not_count_as_word_errors() -> None:
    reference = "Examination number zero four eight. Date of birth one nine seven four, one zero, two three. Height one hundred eighty eight centimeters. Right ventricle forty nine millimeters."
    transcript = "Examination number 048. Date of birth 19741023. Height 188 cm. Right ventricle 49 mm."
    assert spoken_normalized_wer(reference, transcript, "en") == 0


def test_changed_number_side_and_negation_remain_errors() -> None:
    reference = "Правая почка сорок шесть миллиметров. Дополнительных изменений не выявлено."
    correct = "Правая почка 46 мм. Дополнительных изменений не выявлено."
    assert spoken_normalized_wer(reference, correct, "ru") == 0
    assert spoken_normalized_wer(reference, "Левая почка 46 мм. Дополнительных изменений выявлено.", "ru") > 0
    assert spoken_normalized_wer(reference, "Правая почка 47 мм. Дополнительных изменений не выявлено.", "ru") > 0


def test_leading_zero_digit_sequence_is_not_a_cardinal_number() -> None:
    assert spoken_normalized_wer("номер ноль четыре три", "номер 043", "ru") == 0
    assert spoken_normalized_wer("номер ноль четыре три", "номер 43", "ru") > 0


def test_description_spelling_and_unit_style_are_equivalent_but_negation_is_not() -> None:
    reference = "Left ventricle: fifty four mm. No additional abnormality."
    assert spoken_normalized_wer(reference, "left ventricle 54 millimeters no additional abnormality", "en") == 0
    assert spoken_normalized_wer(reference, "left ventricle 54 millimeters additional abnormality", "en") > 0


def test_speed_unit_spellings_are_equivalent_but_missing_unit_is_not() -> None:
    assert spoken_normalized_wer("скорость сорок сантиметров в секунду", "скорость 40 см/с", "ru") == 0
    assert spoken_normalized_wer("velocity forty centimeters per second", "velocity 40 cm/s", "en") == 0
    assert spoken_normalized_wer("скорость сорок сантиметров в секунду", "скорость 40 см", "ru") > 0
