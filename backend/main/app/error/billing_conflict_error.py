from __future__ import annotations

from app.error.api_error import ApiError


class BillingConflictError(ApiError):
    code = "billingConflict"
    description = "The purchase or operation is already being processed"
    status_code = 409

    def __init__(
        self,
    ) -> None:
        super().__init__()
