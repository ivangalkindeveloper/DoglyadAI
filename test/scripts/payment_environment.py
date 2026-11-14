"""Load test-only Robokassa credentials without executing or printing env contents."""
from __future__ import annotations
import os
from pathlib import Path
from dotenv import dotenv_values

KEYS = ('ROBOKASSA_MERCHANT_LOGIN', 'ROBOKASSA_PASSWORD1', 'ROBOKASSA_PASSWORD2')


def payment_environment(root: Path, config: dict) -> dict[str, str]:
    configured = config.get('robokassaCredentialsFile')
    values = dotenv_values(root / configured, interpolate=False) if configured else {}
    result = {}
    for key in KEYS:
        value = os.environ.get('REGRESSION_' + key) or values.get(key)
        if not value:
            raise ValueError(f'Missing regression {key}; configure robokassaCredentialsFile')
        result['REGRESSION_' + key] = value
    result['REGRESSION_IS_ROBOKASSA_LIVE_ENABLED'] = 'false'
    return result


def verify_test_merchant(environment: dict[str, str]) -> None:
    # Robokassa has no /me endpoint. Development forces IsTest=1 on the backend.
    # This is configuration validation, not evidence that the merchant accepted a payment.
    if any(not environment.get('REGRESSION_' + key) for key in KEYS):
        raise ValueError('Robokassa test credentials are required')
    if environment.get('REGRESSION_IS_ROBOKASSA_LIVE_ENABLED', 'false').lower() != 'false':
        raise ValueError('Real payments are forbidden in regression')
