from __future__ import annotations

from pydantic import BaseModel, ConfigDict, Field

from app.model.non_blank_string import NonBlankString


class USAudioParseRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
    )

    selectedNeuralModelId: NonBlankString
    usExaminationTypeId: str = Field(
        min_length=1,
        max_length=128,
    )
