from __future__ import annotations

from app.error.api_error import ApiError


class AppCheckAccessDeniedError(ApiError):
    code = "appCheckAccessDenied"
    description = "App Check verification failed"
    status_code = 403
