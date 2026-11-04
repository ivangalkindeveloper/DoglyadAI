from __future__ import annotations

import re

from app.core.localization.language_code import LanguageCode
from app.model.l10n import L10n


class PromptLocalizationValidator:
    KEYS: frozenset[str] = frozenset(
        {
            "medicalTermCorrectionPrompt",
            "reportComplaintsSectionPattern",
            "reportConclusionSchemaDescription",
            "reportConclusionSectionPattern",
            "reportDescriptionRemarksPrompt",
            "reportDescriptionRemarksSchemaDescription",
            "reportDescriptionSchemaDescription",
            "reportDictatedConclusionPrompt",
            "reportExaminationDescriptionPrompt",
            "reportExaminationPrompt",
            "reportMeasurementPattern",
            "reportNoRecommendationsPrompt",
            "reportPatientComplaintsPrompt",
            "reportPatientHeightPrompt",
            "reportPatientWeightPrompt",
            "reportPhotoIdentityPrompt",
            "reportPhotoRemarkPointDescriptionSchemaDescription",
            "reportPhotoRemarkPointTitleSchemaDescription",
            "reportPhotoRemarkPointXSchemaDescription",
            "reportPhotoRemarkPointYSchemaDescription",
            "reportPhotoRemarksPhotoIdSchemaDescription",
            "reportPhotoRemarksPointsSchemaDescription",
            "reportPhotoRemarksPrompt",
            "reportPhotoRemarksSchemaDescription",
            "reportPlainTextPrompt",
            "reportRecommendationsPrompt",
            "reportRecommendationsSchemaDescription",
            "reportStructuredOutputPrompt",
            "reportSystemPrompt",
            "reportTemplatePrompt",
            "reportTokenLimitPrompt",
            "voiceFormSystemPrompt",
        },
    )

    PLACEHOLDER = re.compile(
        r"\{([A-Za-z][A-Za-z0-9]*)\}",
    )

    @classmethod
    def validate(
        cls,
        catalog: L10n,
    ) -> None:
        for language in catalog.root:
            for key in ("reportConclusionSectionPattern", "reportComplaintsSectionPattern", "reportMeasurementPattern"):
                re.compile(
                    catalog.text(
                        language,
                        key,
                    ),
                    re.IGNORECASE,
                )
            for key in cls.KEYS:
                text = catalog.text(
                    language,
                    key,
                )
                reference = catalog.text(
                    LanguageCode.EN,
                    key,
                )
                if set(
                    cls.PLACEHOLDER.findall(
                        text,
                    ),
                ) != set(
                    cls.PLACEHOLDER.findall(
                        reference,
                    ),
                ):
                    raise ValueError(
                        f"Prompt localization placeholders differ: {key} ({language.value})",
                    )
