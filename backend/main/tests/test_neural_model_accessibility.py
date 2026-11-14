from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.configuration.configuration import Configuration
from app.error import ApiError
from app.model.ultrasound.us_examination_neural_model import USExaminationNeuralModel
from app.model.ultrasound.us_examination_neural_model_accessibility import (
    USExaminationNeuralModelAccessibility,
)


def _model(
    accessibility: USExaminationNeuralModelAccessibility,
) -> USExaminationNeuralModel:
    return USExaminationNeuralModel(
        id=f"test/{accessibility.value}",
        title="Test model",
        format="BF16",
        entitlement="base",
        accessibility=accessibility,
        contextLength=128000,
        descriptionLocaleKey="testModelDescription",
    )


def test_available_model_can_be_resolved(
    configuration: Configuration,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    model = _model(
        USExaminationNeuralModelAccessibility.AVAILABLE,
    )
    monkeypatch.setitem(
        configuration.neural_models,
        model.id,
        model,
    )

    assert (
        configuration.resolve_neural_model(
            model.id,
        )
        is model
    )


@pytest.mark.parametrize(
    "value",
    (None, "", "   "),
)
def test_model_format_must_be_nonblank(
    value: str | None,
) -> None:
    data = _model(
        USExaminationNeuralModelAccessibility.AVAILABLE,
    ).model_dump()
    data["format"] = value
    with pytest.raises(
        ValidationError,
    ):
        USExaminationNeuralModel.model_validate(
            data,
        )


@pytest.mark.parametrize(
    "accessibility",
    (
        USExaminationNeuralModelAccessibility.COMING_SOON,
        USExaminationNeuralModelAccessibility.UNAVAILABLE,
    ),
)
def test_inaccessible_model_is_rejected_before_generation(
    configuration: Configuration,
    accessibility: USExaminationNeuralModelAccessibility,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    model = _model(
        accessibility,
    )
    monkeypatch.setitem(
        configuration.neural_models,
        model.id,
        model,
    )

    with pytest.raises(
        ApiError,
    ) as error:
        configuration.resolve_neural_model(
            model.id,
        )

    assert error.value.status_code == 400
    assert error.value.description == "Neural model is not available"
