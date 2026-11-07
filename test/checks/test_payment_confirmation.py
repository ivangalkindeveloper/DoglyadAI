import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from payment_confirmation_evidence import verify_pending


class PaymentConfirmationTests(unittest.TestCase):
    def test_pending_requires_canonical_test_payment_and_no_paid_access(self):
        identity = "12345678-1234-1234-1234-123456789abc"
        ledger = dict(
            id="upgrade",
            provider_id=identity,
            owner_id="owner",
            plan_id="pro_weekly",
            status="pending",
            channel="sdk",
            was_submitted=True,
            has_subscription=False,
            payment_count=1,
            active_base=0,
            active_pro=0,
            amount_minor=24900,
            currency="RUB",
        )
        payment = dict(
            id=identity,
            test=True,
            status="pending",
            paid=False,
            metadata=dict(order_id="upgrade"),
            amount=dict(value="249.00", currency="RUB"),
        )

        def verify(row, response):
            with (
                patch(
                    "payment_confirmation_evidence.subprocess.check_output",
                    return_value=json.dumps(row),
                ),
                patch(
                    "payment_confirmation_evidence.urllib.request.urlopen",
                    return_value=io.BytesIO(json.dumps(response).encode()),
                ),
            ):
                return verify_pending(
                    "doglyad-regression-unit",
                    "pro_weekly",
                    dict(
                        REGRESSION_YOOKASSA_SHOP_ID="test",
                        REGRESSION_YOOKASSA_SECRET_KEY="test-key",
                    ),
                )

        self.assertEqual(verify(ledger, payment)["activeTier"], "none")
        for change in [
            dict(active_pro=1),
            dict(active_base=1),
            dict(payment_count=3),
            dict(has_subscription=True),
            dict(was_submitted=False),
            dict(plan_id="pro_monthly"),
        ]:
            with self.assertRaises(ValueError):
                verify({**ledger, **change}, payment)
        for change in [
            dict(test=False),
            dict(paid=True),
            dict(status="succeeded"),
            dict(metadata=dict(order_id="other")),
        ]:
            with self.assertRaises(ValueError):
                verify(ledger, {**payment, **change})
