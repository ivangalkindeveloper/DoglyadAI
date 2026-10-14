from __future__ import annotations

from pydantic import BaseModel, field_validator

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData


class USExaminationRequest(BaseModel):
    neuralModelSettings: NeuralModelSettings
    examinationData: USExaminationData
    template: str | None = None
    isRecommendationsIncluded: bool = True
    isPhotoRemarks: bool = True
    isDescriptionRemarks: bool = True

    @field_validator("template")
    @classmethod
    def normalize_optional_template(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None
