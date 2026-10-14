from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.get_voice_source_localization import get_voice_source_localization
from app.core.language_code import LanguageCode
from app.core.load_configs import load_configs
from app.model.ultrasound.us_voice_field_id import USVoiceFieldId
from app.model.ultrasound.us_voice_source_localization import USVoiceSourceLocalization
from app.service.labeled_measurement import labeled_measurement


@pytest.mark.parametrize(
    "language,text,foreign_text",
    [
        (LanguageCode.EN, "weight seventy two kilograms", "вес семьдесят два килограмма"),
        (LanguageCode.RU, "вес семьдесят два килограмма", "weight seventy two kilograms"),
    ],
)
def test_source_rules_use_only_selected_catalog(language: LanguageCode, text: str, foreign_text: str) -> None:
    load_configs()
    localization = get_voice_source_localization(language)
    measurement = labeled_measurement(text, USVoiceFieldId.PATIENT_WEIGHT_KG, localization=localization)
    assert measurement is not None and measurement[0] == 72
    assert labeled_measurement(foreign_text, USVoiceFieldId.PATIENT_WEIGHT_KG, localization=localization) is None


@pytest.mark.parametrize("defect", ["missing_pattern", "invalid_pattern", "missing_month", "invalid_gender"])
def test_invalid_source_catalog_fails_validation(defect: str) -> None:
    load_configs()
    data = get_voice_source_localization(LanguageCode.EN).model_dump()
    if defect == "missing_pattern":
        del data["patterns"]["weight"]
    elif defect == "invalid_pattern":
        data["patterns"]["weight"] = "["
    elif defect == "missing_month":
        data["monthWords"] = {}
    else:
        data["genderWords"]["male"] = "unexpected"
    with pytest.raises(ValidationError):
        USVoiceSourceLocalization.model_validate(data)
