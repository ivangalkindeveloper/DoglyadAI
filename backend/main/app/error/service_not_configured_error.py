from __future__ import annotations

from app.error.api_error import ApiError


class ServiceNotConfiguredError(ApiError):
    code = "serviceNotConfigured"
    description = "Service is not configured"
    status_code = 500

    def __init__(
        self,
    ) -> None:
        super().__init__()
