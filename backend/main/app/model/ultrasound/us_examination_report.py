from __future__ import annotations

import json
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator


class USExaminationReport(BaseModel):
    model_config = ConfigDict(extra="forbid")

    description: str = Field(description="Detailed examination findings")
    conclusion: str = Field(description="Concise interpretation of the findings")
    recommendations: str | None = Field(
        default=None,
        description="Recommended treatment or follow-up actions when requested",
    )

    @field_validator("description", "conclusion")
    @classmethod
    def reject_blank_sections(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Report sections must not be blank")
        return stripped

    @field_validator("recommendations")
    @classmethod
    def normalize_optional_recommendations(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class USExaminationModelReport(USExaminationReport):
    date: datetime
    modelId: str


def us_examination_report_structured_output(include_recommendations: bool) -> str:
    schema = USExaminationReport.model_json_schema()
    if not include_recommendations:
        schema["properties"].pop("recommendations", None)
    return json.dumps(schema, ensure_ascii=False, separators=(",", ":"))
