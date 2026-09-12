from __future__ import annotations

from pydantic import BaseModel

from app.model.neural_model_settings import NeuralModelSettings
from app.model.ultrasound.us_examination_data import USExaminationData


class USExaminationRequest(BaseModel):
    neuralModelSettings: NeuralModelSettings
    examinationData: USExaminationData
    template: str | None = None
    includeRecommendations: bool = True
