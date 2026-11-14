"""Require one submitted test checkout without a signed success event or paid access."""
from payment_evidence import verify_payment


def verify_pending(project: str, plan_id: str, environment: dict) -> dict:
    return verify_payment(project, plan_id, environment, outcome='pending')
