from __future__ import annotations

from app.error.api_error import ApiError


class BillingLegalUpdateRequiredError(ApiError):
    code = "billingLegalUpdateRequired"
    description = "Accept the current legal documents before starting a new purchase"
    status_code = 409

    def __init__(
        self,
    ) -> None:
        super().__init__()
