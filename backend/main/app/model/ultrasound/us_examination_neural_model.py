from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)


class USExaminationNeuralModel(BaseModel):
    """Neural model stored in the backend configuration and used for selection."""

    model_config = ConfigDict(extra="forbid")

    id: str
    title: str
    entitlement: str
    accessibility: USExaminationNeuralModelAccessibility
    contextLength: int
    descriptionLocaleKey: str
