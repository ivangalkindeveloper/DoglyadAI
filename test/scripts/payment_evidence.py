"""Verify test-mode Robokassa evidence from the backend's signed ResultURL ledger.

SQL subscription profiles do not create payment events and cannot satisfy this proof.
OpStateExt does not support test payments. Browser selectors remain a manual gap.
"""
from __future__ import annotations
import json
from pathlib import Path
import re
import subprocess


def owner_ids(project: str) -> set[str]:
    if not project.startswith('doglyad-regression-'):
        raise ValueError('Payment evidence requires the isolated regression project')
    return set(subprocess.check_output(['docker', 'exec', project + '-database-1', 'psql', '-U', 'regression', '-d', 'regression', '-tA', '-c', 'SELECT id FROM billing_owners'], text=True).splitlines())


def verify_payment(project: str, plan_id: str, environment: dict[str, str], before_owners: set[str] | None = None, outcome: str = 'succeeded') -> dict:
    if not project.startswith('doglyad-regression-') or not re.fullmatch(r'(?:base|pro)_(?:weekly|monthly|six_months|annual)', plan_id):
        raise ValueError('Payment evidence requires an isolated project and known plan')
    if outcome in {'declined', 'declined-retry', 'canceled'}:
        raise ValueError('A test-mode browser failure cannot prove a canceled or declined Robokassa operation; verify this case manually')
    query = """SELECT row_to_json(e) FROM (
      SELECT p.id,p.owner_id,p.invoice_id,p.provider_id,p.plan_id,p.source,p.status,p.amount_minor,p.currency,p.channel,p.is_test,
        p.merchant_login,p.submitted_at IS NOT NULL AS was_submitted,
        EXISTS(SELECT 1 FROM billing_events b WHERE b.id='robokassa:payment:'||p.invoice_id AND b.source='robokassa') AS signed_event,
        EXISTS(SELECT 1 FROM billing_subscriptions s WHERE s.id=p.subscription_id AND s.source='robokassa' AND NOT s.is_revoked AND s.paid_until>now()) AS has_access,
        (SELECT count(*) FROM billing_payments q WHERE q.owner_id=p.owner_id AND q.source='robokassa') AS payment_count
      FROM billing_payments p WHERE p.owner_id=(SELECT id FROM billing_owners ORDER BY created_at DESC LIMIT 1)
      ORDER BY p.created_at DESC LIMIT 1) e"""
    raw = subprocess.check_output(['docker', 'exec', project + '-database-1', 'psql', '-U', 'regression', '-d', 'regression', '-tA', '-c', query], text=True)
    if not raw.strip():
        raise ValueError('No provider-backed order exists')
    ledger = json.loads(raw)
    if ledger['source'] != 'robokassa' or ledger['plan_id'] != plan_id or ledger['channel'] != 'redirect' or ledger['payment_count'] != 1:
        raise ValueError('The checkout does not match the selected plan or duplicated its order')
    if before_owners is not None and ledger['owner_id'] in before_owners:
        raise ValueError('An earlier owner cannot satisfy a new purchase')
    if ledger['is_test'] is not True or not ledger['was_submitted'] or ledger['merchant_login'] != environment.get('REGRESSION_ROBOKASSA_MERCHANT_LOGIN'):
        raise ValueError('The order does not belong to the configured test merchant')
    if not re.fullmatch(r'[1-9][0-9]{0,18}', ledger['invoice_id'] or ''):
        raise ValueError('Missing numeric Robokassa invoice')
    catalog = json.loads((Path(__file__).resolve().parents[2] / 'backend/main/config/development/billing.json').read_text())
    plan = next(item for item in catalog['products'] if item['id'] == plan_id)
    if ledger['amount_minor'] != plan['price']['amountMinor'] or ledger['currency'] != plan['price']['currencyIso2Code']:
        raise ValueError('The payment does not match the selected price')
    if outcome == 'pending':
        if ledger['status'] != 'pending' or ledger['has_access'] or ledger['signed_event']:
            raise ValueError('Pending checkout incorrectly granted access')
    elif outcome in {'succeeded', 'confirmed', 'active-rejected'}:
        if ledger['status'] != 'succeeded' or not ledger['has_access'] or not ledger['signed_event']:
            raise ValueError('A verified signed test ResultURL and paid access are required')
    else:
        raise ValueError('Unsupported provider outcome')
    return dict(provider='robokassa', test=True, status=outcome, planId=plan_id, paymentId=ledger['id'], providerPaymentId=ledger['invoice_id'], amountMinor=ledger['amount_minor'], currency=ledger['currency'], channel='redirect', paymentCount=1, **({'activeTier':'none'} if outcome=='pending' else {}))
