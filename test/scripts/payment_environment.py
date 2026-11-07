"""Load only the YooKassa test merchant credentials used by regression."""

from __future__ import annotations

import base64
import json
import os
from pathlib import Path
import ssl
import urllib.error
import urllib.request

from dotenv import dotenv_values
import certifi

KEYS = ("YOOKASSA_SHOP_ID", "YOOKASSA_SECRET_KEY", "YOOKASSA_CLIENT_APPLICATION_KEY")


def payment_environment(root: Path, config: dict) -> dict[str, str]:
    configured = config.get("yookassaCredentialsFile")
    values = dotenv_values(root / configured, interpolate=False) if configured else {}
    result = {}
    for key in KEYS:
        value = os.environ.get("REGRESSION_" + key) or values.get(key)
        if not value:
            raise ValueError(
                f"Missing regression {key}; configure yookassaCredentialsFile in test/secrets/config.local.json"
            )
        result["REGRESSION_" + key] = value
    return result


def verify_test_merchant(environment: dict[str, str]) -> None:
    credentials = (
        environment["REGRESSION_YOOKASSA_SHOP_ID"]
        + ":"
        + environment["REGRESSION_YOOKASSA_SECRET_KEY"]
    )
    request = urllib.request.Request(
        "https://api.yookassa.ru/v3/me",
        headers={
            "Authorization": "Basic " + base64.b64encode(credentials.encode()).decode()
        },
    )
    try:
        with urllib.request.urlopen(
            request,
            timeout=20,
            context=ssl.create_default_context(cafile=certifi.where()),
        ) as response:
            merchant = json.load(response)
    except (urllib.error.URLError, ValueError):
        raise ValueError(
            "Cannot verify the YooKassa test merchant; no payment was started"
        ) from None
    if (
        merchant.get("test") is not True
        or str(merchant.get("account_id")) != environment["REGRESSION_YOOKASSA_SHOP_ID"]
    ):
        raise ValueError(
            "Regression requires the configured YooKassa test merchant; live payments are forbidden"
        )
