from __future__ import annotations

from app.error.api_error import ApiError


class EmptyImageError(ApiError):
    code = "emptyImage"
    description = "Image must not be empty"
    status_code = 422

    def __init__(
        self,
    ) -> None:
        super().__init__()
