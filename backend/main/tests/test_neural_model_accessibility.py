from __future__ import annotations

import pytest
from fastapi import HTTPException

from app.core.config import neural_models, resolve_neural_model
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)


def _model(accessibility: USExaminationNeuralModelAccessibility) -> USExaminationNeuralModel:
    return USExaminationNeuralModel(
        id=f"test/{accessibility.value}",
        title="Test model",
        entitlement="base",
        accessibility=accessibility,
        contextLength=128000,
        descriptionLocaleKey="testModelDescription",
    )


def test_available_model_can_be_resolved(monkeypatch: pytest.MonkeyPatch) -> None:
    model = _model(USExaminationNeuralModelAccessibility.AVAILABLE)
    monkeypatch.setitem(neural_models, model.id, model)

    assert resolve_neural_model(model.id) is model


@pytest.mark.parametrize(
    "accessibility",
    (
        USExaminationNeuralModelAccessibility.COMING_SOON,
        USExaminationNeuralModelAccessibility.UNAVAILABLE,
    ),
)
def test_inaccessible_model_is_rejected_before_generation(
    accessibility: USExaminationNeuralModelAccessibility,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    model = _model(accessibility)
    monkeypatch.setitem(neural_models, model.id, model)

    with pytest.raises(HTTPException) as error:
        resolve_neural_model(model.id)

    assert error.value.status_code == 400
    assert error.value.detail == f"Neural model is not available: {model.id}"
