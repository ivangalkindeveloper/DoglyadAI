import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from payment_confirmation_evidence import verify_pending
from payment_evidence import verify_payment


class PaymentConfirmationTests(unittest.TestCase):
    def test_pending_and_success_require_distinct_signed_callback_evidence(self):
        catalog = json.loads((Path(__file__).resolve().parents[2] / 'backend/main/config/development/billing.json').read_text())
        plan = next(p for p in catalog['products'] if p['id']=='pro_weekly')
        ledger = dict(id='order', provider_id='123', invoice_id='123', owner_id='owner', source='robokassa', plan_id='pro_weekly', status='pending', channel='redirect', was_submitted=True, payment_count=1, has_access=False, signed_event=False, is_test=True, merchant_login='test', amount_minor=plan['price']['amountMinor'], currency='RUB')
        env = {'REGRESSION_ROBOKASSA_MERCHANT_LOGIN': 'test'}
        def verify(row, outcome='pending'):
            with patch('payment_evidence.subprocess.check_output', return_value=json.dumps(row)):
                return verify_payment('doglyad-regression-unit', 'pro_weekly', env, outcome=outcome)
        self.assertEqual(verify(ledger)['activeTier'], 'none')
        for change in [dict(has_access=True), dict(signed_event=True), dict(is_test=False), dict(merchant_login='other'), dict(payment_count=2), dict(was_submitted=False), dict(amount_minor=1)]:
            with self.assertRaises(ValueError):
                verify({**ledger, **change})
        success = {**ledger, 'status':'succeeded', 'has_access':True, 'signed_event':True}
        self.assertEqual(verify(success, 'succeeded')['providerPaymentId'], '123')
        with self.assertRaises(ValueError):
            verify({**success, 'signed_event':False}, 'succeeded')
