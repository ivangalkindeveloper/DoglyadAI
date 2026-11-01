from __future__ import annotations

from app.error.api_error import ApiError


class BillingPurchaseError(ApiError):
    code = "billingPurchaseInvalid"
    description = "The purchase could not be verified"
    status_code = 400
