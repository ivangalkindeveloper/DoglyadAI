from __future__ import annotations

from app.error.api_error import ApiError


class BillingUnavailableError(ApiError):
    code = "billingUnavailable"
    description = "Subscription service is not configured"
    status_code = 503
