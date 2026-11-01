from __future__ import annotations

from app.error.billing_payment_error import BillingPaymentError


class BillingPaymentRejectedError(BillingPaymentError):
    """The provider definitively rejected payment creation, without creating a payment."""
