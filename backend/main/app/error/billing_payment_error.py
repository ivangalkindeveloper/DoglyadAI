from __future__ import annotations

from app.error.api_error import ApiError


class BillingPaymentError(ApiError):
    code = "billingPaymentError"
    description = "The payment provider could not complete the operation"
    status_code = 502
