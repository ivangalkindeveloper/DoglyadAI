from __future__ import annotations

from fastapi import HTTPException

import app.core.load_configs as _configuration
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)


def resolve_neural_model(selected_id: str | None) -> USExaminationNeuralModel:
    if not selected_id:
        model = next(iter(_configuration.neural_models.values()))
    else:
        selected_model = _configuration.neural_models.get(selected_id)
        if not selected_model:
            raise HTTPException(
                status_code=400,
                detail=f"Unknown neural model id: {selected_id}",
            )
        model = selected_model

    if model.accessibility is not USExaminationNeuralModelAccessibility.AVAILABLE:
        raise HTTPException(
            status_code=400,
            detail=f"Neural model is not available: {model.id}",
        )
    return model
