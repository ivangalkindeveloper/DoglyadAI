from __future__ import annotations

from app.error.api_error import ApiError


class NeuralModelUnavailableError(ApiError):
    code = "neuralModelUnavailable"
    description = "Neural model is not available"
    status_code = 400

    def __init__(
        self,
    ) -> None:
        super().__init__()
