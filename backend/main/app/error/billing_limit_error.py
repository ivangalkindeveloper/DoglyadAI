from __future__ import annotations

from app.error.api_error import ApiError


class BillingLimitError(ApiError):
    code = "billingLimitExceeded"
    description = "The subscription limit has been reached"
    status_code = 403

    def __init__(
        self,
    ) -> None:
        super().__init__()
