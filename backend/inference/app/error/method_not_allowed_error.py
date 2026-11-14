from __future__ import annotations

from app.error.api_error import ApiError


class MethodNotAllowedError(ApiError):
    code = "methodNotAllowed"
    description = "Method is not allowed"
    status_code = 405

    def __init__(
        self,
    ) -> None:
        super().__init__()
