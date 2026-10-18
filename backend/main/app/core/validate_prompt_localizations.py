from __future__ import annotations

import re

from app.core.language_code import LanguageCode
from app.model.l10n import L10n

PROMPT_LOCALIZATION_KEYS: frozenset[str] = frozenset(
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
        "reportSystemPrompt",
        "reportTemplatePrompt",
        "reportTokenLimitPrompt",
        "voiceFormSystemPrompt",
    }
)


_PLACEHOLDER = re.compile(r"\{([A-Za-z][A-Za-z0-9]*)\}")


def validate_prompt_localizations(catalog: L10n) -> None:
    for language in catalog.root:
        for key in ("reportConclusionSectionPattern", "reportComplaintsSectionPattern", "reportMeasurementPattern"):
            re.compile(catalog.text(language, key), re.IGNORECASE)
        for key in PROMPT_LOCALIZATION_KEYS:
            text = catalog.text(language, key)
            reference = catalog.text(LanguageCode.EN, key)
            if set(_PLACEHOLDER.findall(text)) != set(_PLACEHOLDER.findall(reference)):
                raise ValueError(f"Prompt localization placeholders differ: {key} ({language.value})")
