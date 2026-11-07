"""Require a real YooKassa 3-D Secure pending payment without paid access."""

import base64
from decimal import Decimal
import json
from pathlib import Path
import re
import ssl
import subprocess
import urllib.request
import certifi


def verify_pending(project: str, plan_id: str, environment: dict) -> dict:
    if not project.startswith("doglyad-regression-") or plan_id != "pro_weekly":
        raise ValueError("Pending payment proof requires the isolated Pro purchase")
    query = """
    SELECT row_to_json(evidence) FROM (
      SELECT p.id,p.owner_id,p.provider_id,p.plan_id,p.status,p.amount_minor,p.currency,p.channel,
        p.submitted_at IS NOT NULL AS was_submitted,
        p.subscription_id IS NOT NULL AS has_subscription,
        (SELECT count(*) FROM billing_payments WHERE owner_id=p.owner_id) AS payment_count,
        (SELECT count(*) FROM billing_subscriptions WHERE owner_id=p.owner_id AND NOT is_revoked AND paid_until>now() AND entitlement='base') AS active_base,
        (SELECT count(*) FROM billing_subscriptions WHERE owner_id=p.owner_id AND NOT is_revoked AND paid_until>now() AND entitlement='pro') AS active_pro
      FROM billing_payments p
      WHERE p.owner_id=(SELECT id FROM billing_owners ORDER BY created_at DESC LIMIT 1)
      ORDER BY p.created_at DESC LIMIT 1
    ) evidence
    """
    raw = subprocess.check_output(
        [
            "docker",
            "exec",
            project + "-database-1",
            "psql",
            "-U",
            "regression",
            "-d",
            "regression",
            "-tA",
            "-c",
            query,
        ],
        text=True,
    )
    ledger = json.loads(raw)
    if (
        ledger["plan_id"] != plan_id
        or ledger["status"] != "pending"
        or ledger["channel"] != "sdk"
        or not ledger["was_submitted"]
        or ledger["has_subscription"]
        or ledger["payment_count"] != 1
        or ledger["active_base"] != 0
        or ledger["active_pro"] != 0
    ):
        raise ValueError("Pending Pro purchase granted access or duplicated an order")
    identity = ledger["provider_id"]
    if not isinstance(identity, str) or not re.fullmatch(r"[a-f0-9-]{36}", identity):
        raise ValueError("Missing canonical pending payment ID")
    credentials = (
        environment["REGRESSION_YOOKASSA_SHOP_ID"]
        + ":"
        + environment["REGRESSION_YOOKASSA_SECRET_KEY"]
    )
    request = urllib.request.Request(
        "https://api.yookassa.ru/v3/payments/" + identity,
        headers={
            "Authorization": "Basic " + base64.b64encode(credentials.encode()).decode()
        },
    )
    with urllib.request.urlopen(
        request, timeout=20, context=ssl.create_default_context(cafile=certifi.where())
    ) as response:
        payment = json.load(response)
    catalog = json.loads(
        (
            Path(__file__).resolve().parents[2]
            / "backend/main/config/development/billing.json"
        ).read_text()
    )
    plan = next(item for item in catalog["products"] if item["id"] == plan_id)
    if (
        payment.get("id") != identity
        or payment.get("test") is not True
        or payment.get("status") != "pending"
        or payment.get("paid") is not False
        or payment.get("metadata", {}).get("order_id") != ledger["id"]
        or Decimal(payment["amount"]["value"]) * 100 != ledger["amount_minor"]
        or ledger["amount_minor"] != plan["price"]["amountMinor"]
        or payment["amount"]["currency"] != ledger["currency"]
        or ledger["currency"] != plan["price"]["currencyIso2Code"]
    ):
        raise ValueError("YooKassa did not confirm the selected pending test purchase")
    return dict(
        provider="yookassa",
        test=True,
        status="pending",
        planId=plan_id,
        paymentId=ledger["id"],
        providerPaymentId=identity,
        activeTier="none",
        paymentCount=1,
    )
