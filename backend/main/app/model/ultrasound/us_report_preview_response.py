from __future__ import annotations

from pydantic import BaseModel, ConfigDict, field_validator
from pydantic_core import from_json


class USReportPreviewResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )
    description: str | None = None
    conclusion: str | None = None
    recommendations: str | None = None
    descriptionRemarks: str | None = None

    @field_validator(
        "description",
        "conclusion",
        "recommendations",
        "descriptionRemarks",
    )
    @classmethod
    def normalize(
        cls,
        value: str | None,
    ) -> str | None:
        return value if value and value.strip() else None

    @classmethod
    def parse_partial(
        cls,
        text: str,
    ) -> USReportPreviewResponse:
        try:
            value = from_json(
                text,
                allow_partial="trailing-strings",
            )
        except ValueError:
            return cls()
        if not isinstance(
            value,
            dict,
        ):
            return cls()
        return cls.model_validate(
            {
                key: value[key]
                for key in cls.model_fields
                if isinstance(
                    value.get(
                        key,
                    ),
                    str,
                )
            },
        )
