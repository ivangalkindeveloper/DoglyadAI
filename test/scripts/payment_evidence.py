"""Cross-check a real SDK test payment against PostgreSQL and YooKassa."""

from __future__ import annotations

import base64
from decimal import Decimal
from pathlib import Path
import json
import re
import ssl
import subprocess
import urllib.request

import certifi


def owner_ids(project: str) -> set[str]:
    if not project.startswith("doglyad-regression-"):
        raise ValueError("Payment evidence requires the isolated regression project")
    return set(
        subprocess.check_output(
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
                "SELECT id FROM billing_owners",
            ],
            text=True,
        ).splitlines()
    )


def verify_payment(
    project: str,
    plan_id: str,
    environment: dict[str, str],
    before_owners: set[str] | None = None,
    outcome: str = "succeeded",
) -> dict:
    if not project.startswith("doglyad-regression-") or not re.fullmatch(
        r"(?:base|pro)_(?:weekly|monthly|six_months|annual)", plan_id
    ):
        raise ValueError(
            "Payment verification requires the isolated regression project and a known plan"
        )
    if outcome == "pending":
        from payment_confirmation_evidence import verify_pending

        return verify_pending(project, plan_id, environment)
    if outcome in {"confirmed", "active-rejected"}:
        proof = verify_payment(project, plan_id, environment, outcome="succeeded")
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
                "SELECT count(*) FROM billing_payments WHERE owner_id=(SELECT id FROM billing_owners ORDER BY created_at DESC LIMIT 1)",
            ],
            text=True,
        )
        if int(raw.strip()) != 1:
            raise ValueError(
                "The payment attempt duplicated the existing provider order"
            )
        return {**proof, "status": outcome, "paymentCount": 1}
    if outcome == "canceled":
        query = """
        SELECT row_to_json(evidence) FROM (
          SELECT p.id, p.owner_id, p.plan_id, p.status, p.channel,
                 p.provider_id IS NOT NULL AS has_provider_payment,
                 p.payment_token_hash IS NOT NULL AS has_token,
                 p.submitted_at IS NOT NULL AS was_submitted,
                 p.subscription_id IS NOT NULL AS has_subscription,
                 EXISTS (SELECT 1 FROM billing_subscriptions s WHERE s.owner_id = p.owner_id
                   AND NOT s.is_revoked AND s.paid_until > now()) AS has_access
          FROM billing_payments p
          WHERE p.owner_id = (SELECT id FROM billing_owners ORDER BY created_at DESC LIMIT 1)
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
        if not raw.strip():
            raise ValueError("The SDK checkout did not create a verifiable order")
        ledger = json.loads(raw)
        if (
            ledger["plan_id"] != plan_id
            or ledger["status"] != "canceled"
            or ledger["channel"] != "sdk"
            or any(
                ledger[key]
                for key in (
                    "has_provider_payment",
                    "has_token",
                    "was_submitted",
                    "has_subscription",
                    "has_access",
                )
            )
            or before_owners is not None
            and ledger["owner_id"] in before_owners
        ):
            raise ValueError(
                "Canceled SDK checkout submitted a payment or granted access"
            )
        return dict(
            provider="yookassa",
            test=True,
            status="canceled",
            planId=plan_id,
            paymentId=ledger["id"],
            providerSubmitted=False,
        )
    if outcome in {"declined", "declined-retry"}:
        return verify_declined_payment(
            project,
            plan_id,
            environment,
            before_owners,
            retry=outcome == "declined-retry",
        )
    if outcome != "succeeded":
        raise ValueError("Unsupported provider outcome")
    query = """
    SELECT row_to_json(evidence) FROM (
      SELECT p.id, p.owner_id, p.provider_id, p.plan_id, p.status, p.amount_minor,
             p.currency, p.channel, s.source, s.entitlement, s.is_revoked,
             s.paid_until > now() AS is_active
      FROM billing_payments p JOIN billing_subscriptions s ON s.id = p.subscription_id
      WHERE p.owner_id = (SELECT id FROM billing_owners ORDER BY created_at DESC LIMIT 1)
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
    if not raw.strip():
        raise ValueError("No provider-backed subscription exists for the payment case")
    ledger = json.loads(raw)
    if before_owners is not None and ledger["owner_id"] in before_owners:
        raise ValueError("A previous owner's purchase cannot satisfy this payment case")
    if (
        ledger["plan_id"] != plan_id
        or ledger["status"] != "succeeded"
        or ledger["source"] != "yookassa"
        or ledger["channel"] != "sdk"
        or ledger["is_revoked"]
        or not ledger["is_active"]
    ):
        raise ValueError("The ledger does not confirm the selected SDK purchase")
    catalog = json.loads(
        (
            Path(__file__).resolve().parents[2]
            / "backend/main/config/development/billing.json"
        ).read_text()
    )
    expected = next(plan for plan in catalog["products"] if plan["id"] == plan_id)
    if (
        ledger["amount_minor"] != expected["price"]["amountMinor"]
        or ledger["currency"] != expected["price"]["currencyIso2Code"]
        or ledger["entitlement"] != expected["entitlement"]
    ):
        raise ValueError("The purchase does not match the Development catalog")
    provider_id = ledger["provider_id"]
    if not isinstance(provider_id, str) or not re.fullmatch(
        r"[a-f0-9-]{36}", provider_id
    ):
        raise ValueError("Missing canonical YooKassa payment ID")
    credentials = (
        environment["REGRESSION_YOOKASSA_SHOP_ID"]
        + ":"
        + environment["REGRESSION_YOOKASSA_SECRET_KEY"]
    )
    request = urllib.request.Request(
        "https://api.yookassa.ru/v3/payments/" + provider_id,
        headers={
            "Authorization": "Basic " + base64.b64encode(credentials.encode()).decode()
        },
    )
    with urllib.request.urlopen(
        request, timeout=20, context=ssl.create_default_context(cafile=certifi.where())
    ) as response:
        payment = json.load(response)
    if (
        payment.get("id") != provider_id
        or payment.get("test") is not True
        or payment.get("status") != "succeeded"
        or payment.get("paid") is not True
    ):
        raise ValueError("YooKassa did not confirm a successful test payment")
    amount = payment["amount"]
    if payment.get("metadata", {}).get("order_id") != ledger["id"]:
        raise ValueError("YooKassa payment belongs to another local order")
    if (
        Decimal(amount["value"]) * 100 != ledger["amount_minor"]
        or amount["currency"] != ledger["currency"]
    ):
        raise ValueError(
            "YooKassa amount does not match the selected plan in the ledger"
        )
    # Never persist provider bodies, card data, tokens or personal information.
    return {
        "provider": "yookassa",
        "test": True,
        "status": "succeeded",
        "planId": plan_id,
        "paymentId": ledger["id"],
        "providerPaymentId": provider_id,
        "amountMinor": ledger["amount_minor"],
        "currency": ledger["currency"],
        "channel": "sdk",
    }


def verify_declined_payment(
    project: str,
    plan_id: str,
    environment: dict,
    before_owners: set[str] | None,
    *,
    retry: bool = False,
) -> dict:
    query = """
    SELECT row_to_json(evidence) FROM (
      SELECT p.id, p.owner_id, p.provider_id, p.plan_id, p.status, p.amount_minor, p.currency, p.channel,
        p.submitted_at IS NOT NULL AS was_submitted,
        p.subscription_id IS NOT NULL AS has_subscription,
        (SELECT count(*) FROM billing_payments other WHERE other.owner_id=p.owner_id) AS payment_count,
        (SELECT row_to_json(latest) FROM (
          SELECT id, plan_id, status, provider_id IS NOT NULL AS has_provider,
            payment_token_hash IS NOT NULL AS has_token, submitted_at IS NOT NULL AS was_submitted,
            subscription_id IS NOT NULL AS has_subscription
          FROM billing_payments WHERE owner_id=p.owner_id ORDER BY created_at DESC LIMIT 1
        ) latest) AS retry,
        EXISTS (SELECT 1 FROM billing_subscriptions s WHERE s.owner_id=p.owner_id
          AND NOT s.is_revoked AND s.paid_until>now()) AS has_access
      FROM billing_payments p
      WHERE p.owner_id=(SELECT id FROM billing_owners ORDER BY created_at DESC LIMIT 1)
        AND p.provider_id IS NOT NULL
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
    if not raw.strip():
        raise ValueError("Missing provider-declined SDK order")
    ledger = json.loads(raw)
    if (
        ledger["plan_id"] != plan_id
        or ledger["status"] != "canceled"
        or ledger["channel"] != "sdk"
        or not ledger["was_submitted"]
        or ledger["has_subscription"]
        or ledger["has_access"]
        or ledger["payment_count"] != (2 if retry else 1)
        or not retry
        and before_owners is not None
        and ledger["owner_id"] in before_owners
    ):
        raise ValueError(
            "Declined purchase granted access, duplicated payment or reused an old owner"
        )
    if retry:
        attempt = ledger["retry"]
        if (
            attempt["id"] == ledger["id"]
            or attempt["plan_id"] != plan_id
            or attempt["status"] != "canceled"
            or any(
                attempt[key]
                for key in [
                    "has_provider",
                    "has_token",
                    "was_submitted",
                    "has_subscription",
                ]
            )
        ):
            raise ValueError(
                "Retry changed the selected product or submitted another payment"
            )
    provider_id = ledger["provider_id"]
    if not isinstance(provider_id, str) or not re.fullmatch(
        r"[a-f0-9-]{36}", provider_id
    ):
        raise ValueError("Missing declined provider payment ID")
    credentials = (
        environment["REGRESSION_YOOKASSA_SHOP_ID"]
        + ":"
        + environment["REGRESSION_YOOKASSA_SECRET_KEY"]
    )
    request = urllib.request.Request(
        "https://api.yookassa.ru/v3/payments/" + provider_id,
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
        payment.get("id") != provider_id
        or payment.get("test") is not True
        or payment.get("status") != "canceled"
        or payment.get("paid") is not False
        or payment.get("cancellation_details", {}).get("reason") != "insufficient_funds"
        or payment.get("metadata", {}).get("order_id") != ledger["id"]
        or Decimal(payment["amount"]["value"]) * 100 != ledger["amount_minor"]
        or ledger["amount_minor"] != plan["price"]["amountMinor"]
        or payment["amount"]["currency"] != ledger["currency"]
        or ledger["currency"] != plan["price"]["currencyIso2Code"]
    ):
        raise ValueError(
            "YooKassa did not canonically confirm the expected test decline"
        )
    return dict(
        provider="yookassa",
        test=True,
        status="declined-retry" if retry else "declined",
        providerStatus="canceled",
        planId=plan_id,
        paymentId=ledger["id"],
        providerPaymentId=provider_id,
        providerSubmitted=True,
        reason="insufficient_funds",
        hasAccess=False,
        paymentCount=2 if retry else 1,
        retryCanceledWithoutSubmission=retry,
        retryPaymentId=ledger["retry"]["id"] if retry else None,
    )
