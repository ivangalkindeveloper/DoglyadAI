from __future__ import annotations

import json

from app.core.configuration import Configuration
from app.core.language_code import LanguageCode
from app.model.settings_ai import SettingsAI
from app.model.ultrasound.us_examination_data import USExaminationData
from app.service.split_dictated_report_sections import split_dictated_report_sections


class PromptFactory:
    def __init__(self, language_code: LanguageCode, configuration: Configuration) -> None:
        self._configuration = configuration
        self._language_code: LanguageCode = language_code

    def system_prompt(
        self,
        settings: SettingsAI,
        is_recommendations_included: bool,
        is_photo_remarks: bool,
        is_description_remarks: bool,
    ) -> str:
        prompt = self._configuration.text(self._language_code, "reportSystemPrompt")
        prompt += self._configuration.text(self._language_code, "medicalTermCorrectionPrompt")
        prompt += self._configuration.text(
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
                prompt += self._configuration.text(self._language_code, key)
        if settings.maxTokens is not None:
            prompt += self._configuration.text(self._language_code, "reportTokenLimitPrompt").format(
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
            conclusion_pattern=self._configuration.text(self._language_code, "reportConclusionSectionPattern"),
        )
        prompt = self._configuration.text(self._language_code, "reportExaminationPrompt").format(
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
                prompt += self._configuration.text(self._language_code, key).format(value=value)
        if examination.photos:
            prompt += self._configuration.text(self._language_code, "reportPhotoIdentityPrompt")
            prompt += (
                "\n".join(f"{index}: {photo.id}" for index, photo in enumerate(examination.photos, start=1)) + "\n"
            )
        prompt += (
            json.dumps(
                {
                    "contextualStrings": self._configuration.resolve_examination_contextual_strings(
                        examination.usExaminationTypeId, self._language_code
                    )
                },
                ensure_ascii=False,
            )
            + "\n"
        )
        return prompt

    def voice_system_prompt(self) -> str:
        return (
            self._configuration.text(self._language_code, "voiceFormSystemPrompt")
            + " "
            + self._configuration.text(self._language_code, "medicalTermCorrectionPrompt")
        )

    def voice_prompt(self, examination_title: str, transcript: str, contextual_strings: list[str]) -> str:
        return json.dumps(
            {"examinationType": examination_title, "contextualStrings": contextual_strings, "transcript": transcript},
            ensure_ascii=False,
        )
