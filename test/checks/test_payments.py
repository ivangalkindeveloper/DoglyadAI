from __future__ import annotations
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from payment_environment import verify_test_merchant
from payment_evidence import verify_payment


class PaymentEnvironmentTests(unittest.TestCase):
    environment = {'REGRESSION_ROBOKASSA_MERCHANT_LOGIN': 'test', 'REGRESSION_ROBOKASSA_PASSWORD1': 'first', 'REGRESSION_ROBOKASSA_PASSWORD2': 'second'}

    def test_live_gate_and_missing_credentials_are_rejected(self):
        verify_test_merchant(self.environment)
        for change in [{'REGRESSION_ROBOKASSA_PASSWORD2': ''}, {'REGRESSION_IS_ROBOKASSA_LIVE_ENABLED': 'true'}]:
            with self.assertRaises(ValueError):
                verify_test_merchant({**self.environment, **change})

    def test_closing_the_browser_cannot_prove_a_canceled_invoice(self):
        with self.assertRaisesRegex(ValueError, 'manually'):
            verify_payment('doglyad-regression-unit', 'base_weekly', self.environment, outcome='canceled')

    def test_browser_failure_alone_cannot_prove_a_test_decline(self):
        with self.assertRaisesRegex(ValueError, 'manually'):
            verify_payment('doglyad-regression-unit', 'base_weekly', self.environment, outcome='declined')
