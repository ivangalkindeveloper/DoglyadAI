from __future__ import annotations

from datetime import UTC, datetime

import pytest

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.error import InvalidReportResponseError, ReportMeasurementsMismatchError, UnverifiedReportSectionError
from app.model.ultrasound.us_examination_data import USExaminationData
from app.model.ultrasound.us_examination_report import USExaminationReport
from app.model.ultrasound.us_report_preview_response import USReportPreviewResponse
from app.prompt import PromptFactory
from app.service.report.report_validator import ReportValidator


@pytest.mark.parametrize(
    "field",
    ["description", "conclusion", "recommendations", "descriptionRemarks"],
)
@pytest.mark.parametrize(
    "separated",
    [False, True],
)
def test_report_rejects_three_copies_of_a_complete_sentence(
    field: str,
    separated: bool,
) -> None:
    sentence = "Необходима консультация уролога для исключения урологических заболеваний."
    text = "\n".join(
        (
            sentence + (f" Separate finding number {index}." if separated else "")
            for index in range(
                3,
            )
        ),
    )
    report = USReportPreviewResponse.model_validate(
        {field: text},
    )
    with pytest.raises(
        InvalidReportResponseError,
    ):
        ReportValidator.validate_repetition(
            report,
        )


def test_repetition_validation_accepts_two_sentences_and_an_unfinished_third() -> None:
    sentence = "Необходима консультация уролога для исключения урологических заболеваний."
    ReportValidator.validate_repetition(
        USReportPreviewResponse(
            descriptionRemarks="\n".join(
                [sentence, sentence, sentence[:-1]],
            ),
        ),
    )


def test_repetition_validation_preserves_short_findings_and_decimal_measurements() -> None:
    report = USExaminationReport(
        description="\n".join(
            (
                f"Segment {index}: No focal lesion. The measured length is {index}.5 mm."
                for index in range(
                    1,
                    5,
                )
            ),
        ),
        conclusion="No focal lesion.",
    )
    before = report.model_dump()
    ReportValidator.validate_repetition(
        report,
    )
    assert report.model_dump() == before


@pytest.mark.parametrize(
    "field",
    ["description", "conclusion", "recommendations", "descriptionRemarks"],
)
def test_report_rejects_repeated_sentence_pair_in_each_streamed_section(
    field: str,
) -> None:
    block = (
        "В описании не указана информация о размере левой доли щитовидной железы. "  # noqa: RUF001 — Russian regression input
        "Необходимо указать размер левой доли щитовидной железы."
    )
    report = USReportPreviewResponse.model_validate(
        {
            field: "Initial text. "
            + "\n".join(
                [block] * 3,
            )
            + " Trailing text."
        },
    )
    with pytest.raises(
        InvalidReportResponseError,
    ):
        ReportValidator.validate_repetition(
            report,
        )


def test_repetition_validation_preserves_measurements_and_cross_section_findings() -> None:
    finding = "The left thyroid lobe is unchanged, with a smooth contour and homogeneous echotexture."
    measurements = " ".join(
        (
            f"The left thyroid lobe has a smooth contour and homogeneous echotexture; measured length is {value} mm."
            for value in [50, 51, 52]
        ),
    )
    report = USExaminationReport(
        description=measurements,
        conclusion=finding,
        recommendations=finding,
        descriptionRemarks=finding + " " + finding,
    )
    before = report.model_dump()
    ReportValidator.validate_repetition(
        report,
    )
    assert report.model_dump() == before


def _examination(
    description: str,
    complaints: str | None = None,
) -> USExaminationData:
    return USExaminationData(
        usExaminationTypeId="bladder",
        photos=[],
        examinationNumber="UNIT-42",
        patientName="Test Patient",
        patientGender="female",
        patientDateOfBirth=datetime(
            1991,
            1,
            1,
            tzinfo=UTC,
        ),
        isPatientConsent=True,
        patientComplaints=complaints,
        examinationDescription=description,
    )


@pytest.mark.parametrize(
    "language,description,conclusion,complaints,source",
    [
        (
            LanguageCode.RU,
            "Стенка 2,7 мм. Заключение: Эхопризнаки взвеси. Объём 180 мл. Жалобы на дискомфорт.",
            "Эхопризнаки взвеси.",
            "дискомфорт",
            "Стенка 2,7 мм. Объём 180 мл. Заключение: Эхопризнаки взвеси.",
        ),
        (
            LanguageCode.EN,
            "Wall 2.7 mm. Impression: Suspension present. Volume 180 ml. Complaints: Discomfort.",
            "Suspension present.",
            "Discomfort",
            "Wall 2.7 mm. Volume 180 ml. Impression: Suspension present.",
        ),
    ],
)
def test_proven_misplaced_sections_are_removed_without_losing_following_findings(
    configuration: Configuration,
    language: LanguageCode,
    description: str,
    conclusion: str,
    complaints: str,
    source: str,
) -> None:
    report = USExaminationReport(
        description=description,
        conclusion=conclusion,
    )
    ReportValidator(
        configuration,
    ).validate_content(
        report,
        _examination(
            source,
            complaints,
        ),
        language_code=language,
    )
    assert "180" in report.description and "2.7" in report.description.replace(
        ",",
        ".",
    )
    assert report.conclusion == conclusion
    assert "Заключение" not in report.description and "Impression" not in report.description
    assert "Жалобы" not in report.description and "Complaints" not in report.description


def test_findings_can_be_mentioned_in_description_and_conclusion(
    configuration: Configuration,
) -> None:
    report = USExaminationReport(
        description="Suspension present. Wall 2.7 mm.",
        conclusion="Suspension present.",
    )
    ReportValidator(
        configuration,
    ).validate_content(
        report,
        _examination(
            "Wall 2.7 mm. Suspension present.",
        ),
        language_code=LanguageCode.EN,
    )
    assert report.description == "Suspension present. Wall 2.7 mm."


def test_complaint_framing_is_removed_when_the_form_value_keeps_the_preposition(
    configuration: Configuration,
) -> None:
    report = USExaminationReport(
        description="Стенка 2,7 мм. Жалобы на дискомфорт.",
        conclusion="Взвесь.",
    )
    ReportValidator(
        configuration,
    ).validate_content(
        report,
        _examination(
            "Стенка 2,7 мм.",
            "на дискомфорт",
        ),
        language_code=LanguageCode.RU,
    )
    assert report.description == "Стенка 2,7 мм."


@pytest.mark.parametrize(
    "description",
    ["Wall 2.8 mm. Volume 180 ml.", "Wall 2.7 mm. Volume 181 ml.", "Wall 2.7 mm."],
)
def test_report_cannot_change_or_drop_explicit_measurements(
    configuration: Configuration,
    description: str,
) -> None:
    report = USExaminationReport(
        description=description,
        conclusion="Suspension present.",
    )
    with pytest.raises(
        ReportMeasurementsMismatchError,
    ):
        ReportValidator(
            configuration,
        ).validate_content(
            report,
            _examination(
                "Wall 2.7 mm. Volume 180 ml.",
            ),
            language_code=LanguageCode.EN,
        )


def test_unverified_conclusion_is_not_silently_deleted(
    configuration: Configuration,
) -> None:
    report = USExaminationReport(
        description="Wall 2.7 mm. Conclusion: An additional finding.",
        conclusion="Suspension.",
    )
    with pytest.raises(
        UnverifiedReportSectionError,
    ):
        ReportValidator(
            configuration,
        ).validate_content(
            report,
            _examination(
                "Wall 2.7 mm.",
            ),
            language_code=LanguageCode.EN,
        )


def test_dictated_conclusion_is_a_separate_prompt_source_and_template_is_not_evidence(
    configuration: Configuration,
) -> None:
    prompt = PromptFactory(
        LanguageCode.RU,
        configuration,
    ).build_prompt(
        _examination(
            "Стенка 2,7 мм. Заключение: Эхопризнаки взвеси.",
        ),
        "Мочевой пузырь",
    )
    assert "Стенка 2,7 мм." in prompt
    assert (
        prompt.count(
            "Эхопризнаки взвеси.",
        )
        == 1
    )
    assert "Заключение, явно продиктованное врачом" in prompt
    assert "Шаблон задаёт структуру и стиль" in configuration.text(
        LanguageCode.RU,
        "reportSystemPrompt",
    )
