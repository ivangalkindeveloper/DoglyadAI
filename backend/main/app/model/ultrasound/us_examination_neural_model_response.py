from __future__ import annotations

from pydantic import BaseModel

from app.model.non_blank_string import NonBlankString
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)


class USExaminationNeuralModelResponse(BaseModel):
    """Client response with the description resolved for one language."""

    id: NonBlankString
    title: NonBlankString
    entitlement: NonBlankString
    accessibility: USExaminationNeuralModelAccessibility
    contextLength: int
    description: NonBlankString
