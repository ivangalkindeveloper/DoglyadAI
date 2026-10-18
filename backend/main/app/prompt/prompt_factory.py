from __future__ import annotations

import json

from app.core.language_code import LanguageCode
from app.core.resolve_examination_contextual_strings import resolve_examination_contextual_strings
from app.core.resolve_localized_text import resolve_localized_text
from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData
from app.service.split_dictated_report_sections import split_dictated_report_sections


class PromptFactory:
    def __init__(self, language_code: LanguageCode) -> None:
        self._language_code: LanguageCode = language_code

    def system_prompt(
        self,
        settings: NeuralModelSettings,
        is_recommendations_included: bool,
        is_photo_remarks: bool,
        is_description_remarks: bool,
    ) -> str:
        prompt = resolve_localized_text(self._language_code, "reportSystemPrompt")
        prompt += resolve_localized_text(self._language_code, "medicalTermCorrectionPrompt")
        prompt += resolve_localized_text(
            self._language_code,
            "reportRecommendationsPrompt" if is_recommendations_included else "reportNoRecommendationsPrompt",
        )
        sections = (
            (is_description_remarks, "reportDescriptionRemarksPrompt"),
            (is_photo_remarks, "reportPhotoRemarksPrompt"),
            (not settings.isMarkdown, "reportPlainTextPrompt"),
        )
        for is_enabled, key in sections:
            if is_enabled:
                prompt += resolve_localized_text(self._language_code, key)
        if settings.maxTokens is not None:
            prompt += resolve_localized_text(self._language_code, "reportTokenLimitPrompt").format(
                maxTokens=settings.maxTokens
            )
        return prompt

    def build_prompt(
        self,
        examination: USExaminationData,
        examination_title: str,
        template: str | None = None,
    ) -> str:
        dictated = split_dictated_report_sections(
            examination.examinationDescription,
            conclusion_pattern=resolve_localized_text(self._language_code, "reportConclusionSectionPattern"),
        )
        prompt = resolve_localized_text(self._language_code, "reportExaminationPrompt").format(
            examinationTitle=examination_title,
            examinationNumber=examination.examinationNumber,
            patientName=examination.patientName,
            patientGender=examination.patientGender,
            patientDateOfBirth=examination.patientDateOfBirth.date().isoformat(),
        )
        sections = (
            ("reportPatientHeightPrompt", examination.patientHeight),
            ("reportPatientWeightPrompt", examination.patientWeight),
            ("reportPatientComplaintsPrompt", examination.patientComplaints),
            ("reportExaminationDescriptionPrompt", dictated.description or None),
            ("reportDictatedConclusionPrompt", dictated.conclusion),
            ("reportTemplatePrompt", template),
        )
        for key, value in sections:
            if value is not None:
                prompt += resolve_localized_text(self._language_code, key).format(value=value)
        if examination.photos:
            prompt += resolve_localized_text(self._language_code, "reportPhotoIdentityPrompt")
            prompt += (
                "\n".join(f"{index}: {photo.id}" for index, photo in enumerate(examination.photos, start=1)) + "\n"
            )
        prompt += (
            json.dumps(
                {
                    "contextualStrings": resolve_examination_contextual_strings(
                        examination.usExaminationTypeId, self._language_code
                    )
                },
                ensure_ascii=False,
            )
            + "\n"
        )
        return prompt
