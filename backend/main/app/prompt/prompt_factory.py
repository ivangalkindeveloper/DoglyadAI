from __future__ import annotations

import json

from app.core.configuration.configuration import Configuration
from app.core.localization.language_code import LanguageCode
from app.model.settings_ai import SettingsAI
from app.model.ultrasound.us_examination_data import USExaminationData
from app.service.dictation.split_dictated_report_sections import split_dictated_report_sections


class PromptFactory:
    def __init__(
        self,
        language_code: LanguageCode,
        configuration: Configuration,
    ) -> None:
        self._configuration = configuration
        self._language_code: LanguageCode = language_code

    def system_prompt(
        self,
        settings: SettingsAI,
        is_recommendations_included: bool,
        is_photo_remarks: bool,
        is_description_remarks: bool,
        structured_output: str,
    ) -> str:
        prompt = self._configuration.text(
            self._language_code,
            "reportSystemPrompt",
        )
        prompt += self._configuration.text(
            self._language_code,
            "reportRecommendationsPrompt" if is_recommendations_included else "reportNoRecommendationsPrompt",
        )
        if is_description_remarks:
            prompt += self._configuration.text(
                self._language_code,
                "reportDescriptionRemarksPrompt",
            )
        sections = (
            (is_photo_remarks, "reportPhotoRemarksPrompt"),
            (not settings.isMarkdown, "reportPlainTextPrompt"),
        )
        for is_enabled, key in sections:
            if is_enabled:
                prompt += self._configuration.text(
                    self._language_code,
                    key,
                )
        if settings.maxTokens is not None:
            prompt += self._configuration.text(
                self._language_code,
                "reportTokenLimitPrompt",
            ).format(
                maxTokens=settings.maxTokens,
            )
        prompt += self._configuration.text(
            self._language_code,
            "reportStructuredOutputPrompt",
        ).format(
            schema=structured_output,
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
            conclusion_pattern=self._configuration.text(
                self._language_code,
                "reportConclusionSectionPattern",
            ),
        )
        prompt = ""
        if template is not None:
            prompt = self._configuration.text(
                self._language_code,
                "reportTemplatePrompt",
            ).format(
                value=template,
            )
        prompt += self._configuration.text(
            self._language_code,
            "reportExaminationPrompt",
        ).format(
            examinationTitle=examination_title,
            examinationNumber=examination.examinationNumber,
            patientName=examination.patientName,
            patientGender=examination.patientGender,
            patientDateOfBirth=examination.patientDateOfBirth.date().isoformat(),
        )
        prompt += self._configuration.text(
            self._language_code,
            "reportPatientPreparedPrompt"
            if examination.isPatientPreparedForExamination
            else "reportPatientUnpreparedPrompt",
        )
        sections = (
            ("reportPatientHeightPrompt", examination.patientHeight),
            ("reportPatientWeightPrompt", examination.patientWeight),
            ("reportPatientComplaintsPrompt", examination.patientComplaints),
            ("reportExaminationDescriptionPrompt", dictated.description or None),
            ("reportDictatedConclusionPrompt", dictated.conclusion),
        )
        for key, value in sections:
            if value is not None:
                prompt += self._configuration.text(
                    self._language_code,
                    key,
                ).format(
                    value=value,
                )
        if examination.photos:
            prompt += self._configuration.text(
                self._language_code,
                "reportPhotoIdentityPrompt",
            )
            prompt += (
                "\n".join(
                    (
                        f"{index}: {photo.id}"
                        for index, photo in enumerate(
                            examination.photos,
                            start=1,
                        )
                    ),
                )
                + "\n"
            )
        return prompt

    def voice_system_prompt(
        self,
    ) -> str:
        return (
            self._configuration.text(
                self._language_code,
                "voiceFormSystemPrompt",
            )
            + " "
            + self._configuration.text(
                self._language_code,
                "medicalTermCorrectionPrompt",
            )
        )

    def voice_prompt(
        self,
        examination_title: str,
        transcript: str,
        contextual_strings: list[str],
    ) -> str:
        return json.dumps(
            {"examinationType": examination_title, "contextualStrings": contextual_strings, "transcript": transcript},
            ensure_ascii=False,
        )
