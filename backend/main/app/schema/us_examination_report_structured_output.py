from __future__ import annotations

import json
from typing import Any
from uuid import UUID

from app.core.language_code import LanguageCode
from app.core.resolve_localized_text import resolve_localized_text
from app.model.ultrasound.us_examination_report import USExaminationReport

_REPORT_DESCRIPTIONS: dict[str, str] = {
    "description": "reportDescriptionSchemaDescription",
    "conclusion": "reportConclusionSchemaDescription",
    "recommendations": "reportRecommendationsSchemaDescription",
    "descriptionRemarks": "reportDescriptionRemarksSchemaDescription",
    "photoRemarks": "reportPhotoRemarksSchemaDescription",
}
_PHOTO_DESCRIPTIONS: dict[str, str] = {
    "photoId": "reportPhotoRemarksPhotoIdSchemaDescription",
    "points": "reportPhotoRemarksPointsSchemaDescription",
}
_POINT_DESCRIPTIONS: dict[str, str] = {
    "x": "reportPhotoRemarkPointXSchemaDescription",
    "y": "reportPhotoRemarkPointYSchemaDescription",
    "title": "reportPhotoRemarkPointTitleSchemaDescription",
    "description": "reportPhotoRemarkPointDescriptionSchemaDescription",
}


def us_examination_report_structured_output(
    is_recommendations_included: bool,
    *,
    is_photo_remarks: bool,
    is_description_remarks: bool,
    photo_ids: list[UUID],
    language_code: LanguageCode,
) -> str:
    schema = USExaminationReport.model_json_schema()
    properties = schema["properties"]
    optional_fields = {
        "recommendations": is_recommendations_included,
        "descriptionRemarks": is_description_remarks,
        "photoRemarks": is_photo_remarks and bool(photo_ids),
    }
    for field, is_enabled in optional_fields.items():
        if not is_enabled:
            properties.pop(field)
    schema["required"] += [field for field in ("descriptionRemarks", "photoRemarks") if field in properties]
    _localize_properties(properties, _REPORT_DESCRIPTIONS, language_code)

    if "photoRemarks" in properties:
        photo_properties = schema["$defs"]["USExaminationPhotoRemarks"]["properties"]
        photo_properties["photoId"]["enum"] = [str(photo_id) for photo_id in photo_ids]
        _localize_properties(photo_properties, _PHOTO_DESCRIPTIONS, language_code)
        point_properties = schema["$defs"]["USExaminationPhotoRemarkPoint"]["properties"]
        _localize_properties(point_properties, _POINT_DESCRIPTIONS, language_code)
    else:
        schema.pop("$defs")
    return json.dumps(schema, ensure_ascii=False, separators=(",", ":"))


def _localize_properties(properties: dict[str, Any], keys: dict[str, str], language_code: LanguageCode) -> None:
    for field in properties.keys() & keys.keys():
        properties[field]["description"] = resolve_localized_text(language_code, keys[field])
