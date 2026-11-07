from __future__ import annotations

import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from payment_environment import verify_test_merchant
from payment_evidence import verify_payment


class PaymentEnvironmentTests(unittest.TestCase):
    environment = {
        "REGRESSION_YOOKASSA_SHOP_ID": "123",
        "REGRESSION_YOOKASSA_SECRET_KEY": "test-secret",
    }

    def verify(self, response):
        with patch(
            "payment_environment.urllib.request.urlopen",
            return_value=io.BytesIO(json.dumps(response).encode()),
        ):
            verify_test_merchant(self.environment)

    def test_only_exact_test_shop_is_accepted(self):
        self.verify({"account_id": "123", "test": True})
        for response in [
            {"account_id": "123", "test": False},
            {"account_id": "123"},
            {"account_id": "123", "test": "true"},
            {"account_id": "another-shop", "test": True},
        ]:
            with self.subTest(response=response), self.assertRaises(ValueError):
                self.verify(response)

    def test_cancelled_sdk_checkout_cannot_have_dispatch_or_access(self):
        evidence = dict(
            id="order",
            owner_id="new-owner",
            plan_id="base_weekly",
            status="canceled",
            channel="sdk",
            has_provider_payment=False,
            has_token=False,
            was_submitted=False,
            has_subscription=False,
            has_access=False,
        )

        def verify(value, previous=None):
            with patch(
                "payment_evidence.subprocess.check_output",
                return_value=json.dumps(value),
            ):
                return verify_payment(
                    "doglyad-regression-unit",
                    "base_weekly",
                    {},
                    previous or {"old-owner"},
                    "canceled",
                )

        self.assertFalse(verify(evidence)["providerSubmitted"])
        for key in (
            "has_provider_payment",
            "has_token",
            "was_submitted",
            "has_subscription",
            "has_access",
        ):
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify({**evidence, key: True})
        for change in [
            dict(status="pending"),
            dict(plan_id="pro_weekly"),
            dict(owner_id="old-owner"),
        ]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                verify({**evidence, **change})

    def test_provider_decline_requires_canonical_failure_without_access(self):
        provider_id = "12345678-1234-1234-1234-123456789abc"
        ledger = dict(
            id="order",
            owner_id="new",
            provider_id=provider_id,
            plan_id="base_weekly",
            status="canceled",
            amount_minor=14900,
            currency="RUB",
            channel="sdk",
            was_submitted=True,
            has_subscription=False,
            has_access=False,
            payment_count=1,
        )
        payment = dict(
            id=provider_id,
            test=True,
            status="canceled",
            paid=False,
            cancellation_details=dict(reason="insufficient_funds"),
            metadata=dict(order_id="order"),
            amount=dict(value="149.00", currency="RUB"),
        )

        def verify(record, response, outcome="declined"):
            with (
                patch(
                    "payment_evidence.subprocess.check_output",
                    return_value=json.dumps(record),
                ),
                patch(
                    "payment_evidence.urllib.request.urlopen",
                    return_value=io.BytesIO(json.dumps(response).encode()),
                ),
            ):
                return verify_payment(
                    "doglyad-regression-unit",
                    "base_weekly",
                    self.environment,
                    {"old"},
                    outcome,
                )

        self.assertEqual(verify(ledger, payment)["status"], "declined")
        retry = dict(
            id="retry",
            plan_id="base_weekly",
            status="canceled",
            has_provider=False,
            has_token=False,
            was_submitted=False,
            has_subscription=False,
        )
        retried = {**ledger, "payment_count": 2, "retry": retry}
        self.assertTrue(
            verify(retried, payment, "declined-retry")["retryCanceledWithoutSubmission"]
        )
        for change in [
            dict(has_provider=True),
            dict(has_token=True),
            dict(was_submitted=True),
            dict(has_subscription=True),
            dict(plan_id="pro_weekly"),
            dict(id="order"),
            dict(status="pending"),
        ]:
            with self.assertRaises(ValueError):
                verify(
                    {**retried, "retry": {**retry, **change}}, payment, "declined-retry"
                )
        for change in [
            dict(has_access=True),
            dict(payment_count=2),
            dict(owner_id="old"),
            dict(was_submitted=False),
        ]:
            with self.assertRaises(ValueError):
                verify({**ledger, **change}, payment)
        for change in [
            dict(test=False),
            dict(status="succeeded"),
            dict(paid=True),
            dict(cancellation_details=dict(reason="canceled_by_merchant")),
            dict(metadata=dict(order_id="different")),
        ]:
            with self.assertRaises(ValueError):
                verify(ledger, {**payment, **change})


if __name__ == "__main__":
    unittest.main()
