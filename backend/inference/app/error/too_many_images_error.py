from __future__ import annotations

from app.error.api_error import ApiError


class TooManyImagesError(ApiError):
    code = "tooManyImages"
    description = "Too many images"
    status_code = 422

    def __init__(
        self,
    ) -> None:
        super().__init__()
