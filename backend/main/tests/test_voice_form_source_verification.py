from __future__ import annotations

# ruff: noqa: RUF001
import pytest

from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
from app.service.voice_form_birth_date import source_birth_date
from app.service.voice_form_numbers import source_number
from app.service.voice_form_validation import validate_voice_form_generation


@pytest.mark.parametrize(
    "text,expected",
    [
        ("one hundred and seventy-eight", 178),
        ("сто семьдесят восемь", 178),
        ("seventy two point five", 72.5),
        ("семьдесят два запятая пять", 72.5),
        ("1,78", 1.78),
        ("two thousand two", 2002),
        ("двухтысячного", 2000),
        ("two three", None),
        ("сто сто", None),
        ("seventy cats", None),
    ],
)
def test_number_grammar_requires_the_whole_phrase(text: str, expected: float | None) -> None:
    assert source_number(text) == expected


@pytest.mark.parametrize(
    "text,expected",
    [
        ("девятнадцатое июня тысяча девятьсот восемьдесят восьмого года", "1988-06-19"),
        ("первое сентября двухтысячного года рождения", "2000-09-01"),
        ("born the twenty eighth of December two thousand two", "2002-12-28"),
        ("Date of birth: April 9, 1956", "1956-04-09"),
        ("DOB: the ninth of April nineteen fifty six", "1956-04-09"),
        ("четвертого марта тысяча девятьсот девяностого года", "1990-03-04"),
        ("родился 29 февраля 2000 года", "2000-02-29"),
        ("родился 29 февраля 2001 года", None),
        ("31 April 1980", None),
        ("August 1978", None),
        ("43 years old", None),
        ("12/03/1980", None),
        ("12 марта 1980 или 1981 года", None),
        ("born 12 March 1980, no, 13 March 1980", None),
        ("Дата рождения: возможно 1 августа 1978 года", None),
    ],
)
def test_birth_date_components_are_independently_checked(text: str, expected: str | None) -> None:
    assert source_birth_date(text) == expected


def test_wrong_model_year_is_corrected_from_source() -> None:
    text = "Дата рождения: девятнадцатое июня тысяча девятьсот восемьдесят восьмого года."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_date_of_birth", "value": "1968-06-19", "evidence": text, "accuracy": "full"},
        ]
    )
    proposal = validate_voice_form_generation(generated, text).proposals[0]
    assert proposal.value == "1988-06-19"
    assert proposal.accuracy.value == "full"
    assert proposal.evidence in text


def test_examination_date_is_not_a_birth_date() -> None:
    text = "Исследование выполнено 12 марта 1980 года."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_date_of_birth", "value": "1980-03-12", "evidence": text, "accuracy": "full"},
        ]
    )
    assert validate_voice_form_generation(generated, text).proposals == []


@pytest.mark.parametrize(
    "text,expected",
    [
        ("Height: 1.78 m. Weight: 72.5 kg.", {"patient_height_cm": 178, "patient_weight_kg": 72.5}),
        (
            "Рост: 178 см. Вес: семьдесят два запятая пять килограмма.",
            {"patient_height_cm": 178, "patient_weight_kg": 72.5},
        ),
        ("Height: 180, no, 178 cm.", {}),
        ("Weight: 72 or 82 kg.", {}),
        ("Left ventricle: 38 mm.", {}),
        ("Height: 178 cm. Height: 182 cm.", {}),
        ("Weight: 180 pounds.", {}),
    ],
)
def test_source_measurements_have_correct_field_and_unit(text: str, expected: dict[str, float]) -> None:
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), text)
    assert {item.field_id.value: item.value for item in response.proposals} == expected


def test_clinical_copy_preserves_duration_and_all_negative_sentences() -> None:
    text = (
        "They report right flank pain for three days. On ultrasound, liver: 140 mm. "
        "No focal lesion. Portal vein is patent. Weight: 82 kg."
    )
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), text)
    fields = {item.field_id.value: item for item in response.proposals}
    assert fields["patient_complaints"].value == "right flank pain for three days."
    assert fields["examination_description"].value == "liver: 140 mm. No focal lesion. Portal vein is patent."
    assert all(item.evidence in text for item in fields.values())


def test_repeated_sections_and_unlabelled_text_keep_model_review() -> None:
    text = "Liver not enlarged. No focal lesions."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "examination_description", "value": text, "evidence": text, "accuracy": "full"},
        ]
    )
    assert validate_voice_form_generation(generated, text).proposals[0].accuracy.value == "questionable"


def test_corrected_numeric_finding_retains_all_surrounding_text_and_source() -> None:
    text = "On ultrasound, cyst: twenty five, no, twenty two millimeters. No vascularity. No free fluid."
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), text)
    proposal = response.proposals[0]
    assert proposal.value == "cyst: twenty two millimeters. No vascularity. No free fluid."
    assert proposal.evidence == text
    assert proposal.accuracy.value == "questionable"


def test_alternative_study_numbers_are_not_automatically_selected() -> None:
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), "Study number: 007 or 008.")
    assert response.proposals == []


@pytest.mark.parametrize("metadata", ["Номер исследования 00429. Вес составляет 68.5 кг.", "Вес составляет 68.5 кг."])
def test_natural_clinical_section_stops_before_numeric_metadata_without_colon(metadata: str) -> None:
    description = "Жёлчный пузырь 74 на 26 мм. Стенка 2 мм. Протоки не расширены."
    transcript = f"Жалуется на Горечь во рту. При УЗИ {description} {metadata}"
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), transcript)
    proposal = next(item for item in response.proposals if item.field_id.value == "examination_description")
    assert proposal.value == description
    assert proposal.evidence == f"При УЗИ {description}"


@pytest.mark.parametrize("text", ["Пол: женщина.", "Patient sex is female."])
def test_explicit_patient_sex_is_recovered_without_model_guessing(text: str) -> None:
    response = validate_voice_form_generation(USVoiceFormGeneration.model_validate([]), text)
    assert response.proposals[0].value == "female"
    assert response.proposals[0].evidence in text


@pytest.mark.parametrize("text", ["Complaints: No complaints.", "No pleural fluid.", "Fetal sex: male."])
def test_patient_sex_requires_source_support_and_is_not_fetal_sex(text: str) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_gender", "value": "male", "evidence": text, "accuracy": "full"},
        ]
    )
    assert all(
        item.field_id is not USVoiceFieldId.PATIENT_GENDER
        for item in validate_voice_form_generation(generated, text).proposals
    )


@pytest.mark.parametrize(
    "intro,complaints",
    [
        ("Complaints:", "Dry cough. No hemoptysis."),
        ("Жалобы:", "Сухой кашель. Кровохарканья нет."),
        ("The patient reports", "Dry cough. No hemoptysis."),
        ("Пациентка жалуется на", "Сухой кашель. Кровохарканья нет."),
    ],
)
def test_final_complaint_section_preserves_continuation(intro: str, complaints: str) -> None:
    description = "No pleural fluid. Diaphragm moves on both sides."
    text = f"{description} {intro} {complaints}"
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "examination_description",
                "value": description,
                "evidence": description,
                "accuracy": "full",
            },
            {
                "field_id": "patient_complaints",
                "value": "Dry cough",
                "evidence": f"{intro} {complaints}",
                "accuracy": "full",
            },
        ]
    )
    fields = {item.field_id: item for item in validate_voice_form_generation(generated, text).proposals}
    assert fields[USVoiceFieldId.PATIENT_COMPLAINTS].value == complaints
    assert fields[USVoiceFieldId.PATIENT_COMPLAINTS].accuracy.value == "questionable"
    assert fields[USVoiceFieldId.EXAMINATION_DESCRIPTION].value == description


@pytest.mark.parametrize("value", ["Ultrasound examination", "Height 170 cm. Weight 60 kg. Patient: Lucy Shaw."])
def test_patient_metadata_is_not_an_examination_description(value: str) -> None:
    text = "Height 170 cm. Weight 60 kg. Patient: Lucy Shaw."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_name", "value": "Lucy Shaw", "evidence": text, "accuracy": "full"},
            {"field_id": "examination_description", "value": value, "evidence": text, "accuracy": "full"},
        ]
    )
    fields = {item.field_id for item in validate_voice_form_generation(generated, text).proposals}
    assert fields == {USVoiceFieldId.PATIENT_NAME, USVoiceFieldId.PATIENT_HEIGHT_CM, USVoiceFieldId.PATIENT_WEIGHT_KG}


@pytest.mark.parametrize(
    "text,name",
    [
        ("Сегодня обследуем пациента Кирилл Павлов. Рост 185 см.", "Кирилл Павлов"),
        ("Today's patient is Oscar Mills. Height 186 cm.", "Oscar Mills"),
    ],
)
def test_patient_introduction_is_metadata_and_not_a_clinical_finding(text: str, name: str) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_name", "value": name, "evidence": name, "accuracy": "full"},
            {"field_id": "examination_description", "value": text, "evidence": text, "accuracy": "questionable"},
        ]
    )
    fields = {item.field_id for item in validate_voice_form_generation(generated, text).proposals}
    assert USVoiceFieldId.EXAMINATION_DESCRIPTION not in fields
    assert USVoiceFieldId.PATIENT_NAME in fields


def test_whole_transcript_quote_does_not_hide_findings_as_complaints() -> None:
    description = "Aorta is 20 mm. No aneurysm."
    text = f"No complaints. {description}"
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_complaints", "value": "No complaints.", "evidence": text, "accuracy": "full"},
            {"field_id": "examination_description", "value": description, "evidence": text, "accuracy": "full"},
        ]
    )
    fields = {item.field_id: item.value for item in validate_voice_form_generation(generated, text).proposals}
    assert fields[USVoiceFieldId.EXAMINATION_DESCRIPTION] == description


def test_final_complaint_label_stops_at_unlabelled_model_findings() -> None:
    complaints = "Dry cough. No hemoptysis."
    description = "No pleural fluid. Diaphragm moves on both sides."
    text = f"Complaints: {complaints} {description}"
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_complaints", "value": "Dry cough", "evidence": "Dry cough", "accuracy": "full"},
            {"field_id": "examination_description", "value": description, "evidence": description, "accuracy": "full"},
        ]
    )
    fields = {item.field_id: item.value for item in validate_voice_form_generation(generated, text).proposals}
    assert fields[USVoiceFieldId.PATIENT_COMPLAINTS] == complaints
    assert fields[USVoiceFieldId.EXAMINATION_DESCRIPTION] == description


def test_complaint_only_recording_cannot_duplicate_the_text_as_findings() -> None:
    text = "Complaints: Left calf pain after exercise. No redness or fever."
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_complaints", "value": text, "evidence": text, "accuracy": "full"},
            {"field_id": "examination_description", "value": text, "evidence": text, "accuracy": "full"},
        ]
    )
    response = validate_voice_form_generation(generated, text)
    assert len(response.proposals) == 1
    assert response.proposals[0].field_id is USVoiceFieldId.PATIENT_COMPLAINTS
    assert response.proposals[0].value == "Left calf pain after exercise. No redness or fever."


def test_name_quote_is_repaired_only_from_a_literal_labelled_name() -> None:
    text = "Сегодня обследуем пациента Валентина Фролова. Пол: женщина."
    generated = USVoiceFormGeneration.model_validate(
        [
            {
                "field_id": "patient_name",
                "value": "Валентина Фролова",
                "evidence": "Пациент, ФИО Валентина Фролова.",
                "accuracy": "full",
            },
        ]
    )
    proposal = next(
        item
        for item in validate_voice_form_generation(generated, text).proposals
        if item.field_id.value == "patient_name"
    )
    assert proposal.evidence == "пациента Валентина Фролова"
    assert proposal.evidence in text


@pytest.mark.parametrize(
    "text,value",
    [
        ("The patient reports Swelling.", "Swelling"),
        ("Patient: Rebecca Ellis.", "Rebecca"),
        ("Patient: Patient#0.", "Patient#0"),
        ("Patient: Adrian Scott. Patient: Adrian Scott.", "Adrian Scott"),
    ],
)
def test_invalid_name_quote_is_not_repaired_without_unique_full_name(text: str, value: str) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "patient_name", "value": value, "evidence": "a rewritten quote", "accuracy": "full"},
        ]
    )
    assert not any(
        item.field_id.value == "patient_name" for item in validate_voice_form_generation(generated, text).proposals
    )


@pytest.mark.parametrize(
    "text,number",
    [
        ("Номер исследования RX-019, вес 88.2 кг.", "RX-019"),
        ("Study ID 007, weight 79 kg, liver 158 mm.", "007"),
    ],
)
def test_identifier_is_not_rejected_because_other_fields_have_units(text: str, number: str) -> None:
    generated = USVoiceFormGeneration.model_validate(
        [
            {"field_id": "examination_number", "value": number, "evidence": text, "accuracy": "full"},
        ]
    )
    proposals = validate_voice_form_generation(generated, text).proposals
    assert next(item for item in proposals if item.field_id.value == "examination_number").value == number
