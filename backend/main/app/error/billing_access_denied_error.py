from __future__ import annotations

from app.error.api_error import ApiError


class BillingAccessDeniedError(ApiError):
    code = "billingAccessDenied"
    description = "Subscription credentials are invalid"
    status_code = 401
