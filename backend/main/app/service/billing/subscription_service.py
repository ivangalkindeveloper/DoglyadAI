from __future__ import annotations

import calendar
import hashlib
import logging
import secrets
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any
from uuid import UUID, uuid4

from appstoreserverlibrary.models.Environment import Environment
from sqlalchemy import case, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.database.billing_checkout_db import BillingCheckoutDB
from app.database.billing_credential_db import BillingCredentialDB
from app.database.billing_database import BillingDatabase
from app.database.billing_event_db import BillingEventDB
from app.database.billing_owner_db import BillingOwnerDB
from app.database.billing_payment_db import BillingPaymentDB
from app.database.billing_refund_db import BillingRefundDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.database.billing_usage_db import BillingUsageDB
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.error.billing_conflict_error import BillingConflictError
from app.error.billing_limit_error import BillingLimitError
from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_payment_rejected_error import BillingPaymentRejectedError
from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.model.billing.billing_catalog import BillingCatalog
from app.model.billing.billing_checkout_response import BillingCheckoutResponse
from app.model.billing.billing_identity_response import BillingIdentityResponse
from app.model.billing.billing_product_config import BillingProductConfig
from app.model.billing.billing_product_response import BillingProductResponse
from app.model.billing.billing_products_response import BillingProductsResponse
from app.model.billing.billing_status_response import BillingStatusResponse
from app.model.billing.billing_tier_response import BillingTierResponse
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.billing.apple_subscription_verifier import AppleSubscriptionVerifier
from app.service.billing.yookassa_payment_provider import YooKassaPaymentProvider


class SubscriptionService:
    def __init__(
        self,
        database: BillingDatabase,
        configuration: Configuration,
        variables: Variables,
        yookassa: YooKassaPaymentProvider,
        apple: AppleSubscriptionVerifier,
    ) -> None:
        self.database = database
        self._configuration = configuration
        self._variables = variables
        self._yookassa = yookassa
        self._apple = apple
        self._catalog = BillingCatalog.model_validate_json(
            (variables.configuration_directory / "billing.json").read_text(),
        )
        for language in LanguageCode:
            self.plans(
                language,
            )

    @property
    def terms_version(
        self,
    ) -> str:
        return self._catalog.termsVersion

    async def register(
        self,
    ) -> BillingIdentityResponse:
        owner_id = str(
            uuid4(),
        )
        token = secrets.token_urlsafe(
            48,
        )
        async with self.database.session() as session, session.begin():
            session.add(
                BillingOwnerDB(
                    id=owner_id,
                    created_at=self._now(),
                ),
            )
            await session.flush()
            session.add(
                BillingCredentialDB(
                    owner_id=owner_id,
                    token_hash=self._hash(
                        token,
                    ),
                ),
            )
        return BillingIdentityResponse(
            ownerId=UUID(
                owner_id,
            ),
            accessToken=token,
        )

    async def authenticate(
        self,
        token: str,
    ) -> str:
        if (
            not 32
            <= len(
                token,
            )
            <= 256
        ):
            raise BillingAccessDeniedError()
        async with self.database.session() as session:
            credential = await session.get(
                BillingCredentialDB,
                self._hash(
                    token,
                ),
            )
            if credential is None:
                raise BillingAccessDeniedError()
            return credential.owner_id

    async def recovery_key(
        self,
        owner_id: str,
    ) -> str:
        # Only hashes are persisted. Requesting a new key explicitly rotates the old one.
        key = secrets.token_hex(
            24,
        ).upper()
        async with self.database.session() as session, session.begin():
            owner = await self.database.lock_owner(
                session,
                owner_id,
            )
            owner.recovery_hash = self._hash(
                key,
            )
        return key

    async def recover(
        self,
        key: str,
    ) -> BillingIdentityResponse:
        token = secrets.token_urlsafe(
            48,
        )
        async with self.database.session() as session, session.begin():
            owner = await session.scalar(
                select(
                    BillingOwnerDB,
                )
                .where(
                    BillingOwnerDB.recovery_hash
                    == self._hash(
                        key.strip().upper(),
                    ),
                )
                .with_for_update(),
            )
            if owner is None:
                raise BillingAccessDeniedError()
            session.add(
                BillingCredentialDB(
                    owner_id=owner.id,
                    token_hash=self._hash(
                        token,
                    ),
                ),
            )
            owner_id = owner.id
        return BillingIdentityResponse(
            ownerId=UUID(
                owner_id,
            ),
            accessToken=token,
        )

    def plans(
        self,
        language: LanguageCode,
    ) -> BillingProductsResponse:
        return BillingProductsResponse(
            tiers=[
                BillingTierResponse(
                    id=tier.id,
                    title=self._configuration.text(
                        language,
                        tier.titleLocaleKey,
                    ),
                    features=[
                        self._configuration.text(
                            language,
                            key,
                        )
                        for key in tier.featureLocaleKeys
                    ],
                )
                for tier in self._catalog.tiers
            ],
            products=[
                BillingProductResponse(
                    id=plan.id,
                    period=plan.period,
                    entitlement=plan.entitlement,
                    price=plan.price,
                    title=self._configuration.text(
                        language,
                        plan.titleLocaleKey,
                    ),
                    priceTemplate=self._configuration.text(
                        language,
                        plan.priceTemplateLocaleKey,
                    ),
                )
                for plan in self._catalog.products
            ],
        )

    async def status(
        self,
        owner_id: str,
    ) -> BillingStatusResponse | None:
        now = self._now()
        async with self.database.session() as session:
            subscription = await session.scalar(
                select(
                    BillingSubscriptionDB,
                )
                .where(
                    BillingSubscriptionDB.owner_id == owner_id,
                    BillingSubscriptionDB.is_revoked.is_(
                        False,
                    ),
                    BillingSubscriptionDB.paid_until > now,
                )
                .order_by(
                    case(
                        (BillingSubscriptionDB.entitlement == "pro", 1),
                        else_=0,
                    ).desc(),
                    BillingSubscriptionDB.paid_until.desc(),
                )
                .limit(
                    1,
                ),
            )
            if subscription is None:
                return None
            used = await session.scalar(
                select(
                    func.count(),
                )
                .select_from(
                    BillingUsageDB,
                )
                .where(
                    BillingUsageDB.owner_id == owner_id,
                    BillingUsageDB.day == now.date().isoformat(),
                    BillingUsageDB.status.in_(
                        ("pending", "completed"),
                    ),
                ),
            )
            subscription_type = subscription.entitlement
            entitlement = self._configuration.application["entitlements"][subscription_type]
            return BillingStatusResponse(
                type=subscription_type,
                source=subscription.source,
                planId=subscription.plan_id,
                expiresAt=self._utc(
                    subscription.paid_until,
                ),
                isAutoRenewing=subscription.is_auto_renewing,
                availableCountPerDay=max(
                    0,
                    int(
                        entitlement["requestCountPerDay"],
                    )
                    - int(
                        used or 0,
                    ),
                ),
            )

    async def reserve(
        self,
        owner_id: str,
        operation_id: str,
    ) -> None:
        try:
            operation_id = str(
                UUID(
                    operation_id,
                ),
            )
        except ValueError as error:
            raise BillingPurchaseError() from error
        async with self.database.session() as session, session.begin():
            await self.database.lock_owner(
                session,
                owner_id,
            )
            if await session.get(
                BillingUsageDB,
                operation_id,
            ):
                raise BillingConflictError()
            now = self._now()
            subscription = await session.scalar(
                select(
                    BillingSubscriptionDB,
                )
                .where(
                    BillingSubscriptionDB.owner_id == owner_id,
                    BillingSubscriptionDB.is_revoked.is_(
                        False,
                    ),
                    BillingSubscriptionDB.paid_until > now,
                )
                .order_by(
                    case(
                        (BillingSubscriptionDB.entitlement == "pro", 1),
                        else_=0,
                    ).desc(),
                )
                .limit(
                    1,
                ),
            )
            if subscription is None:
                raise BillingLimitError()
            period = subscription.entitlement
            limit = int(
                self._configuration.application["entitlements"][period]["requestCountPerDay"],
            )
            used = await session.scalar(
                select(
                    func.count(),
                )
                .select_from(
                    BillingUsageDB,
                )
                .where(
                    BillingUsageDB.owner_id == owner_id,
                    BillingUsageDB.day == now.date().isoformat(),
                    BillingUsageDB.status.in_(
                        ("pending", "completed"),
                    ),
                ),
            )
            if (
                int(
                    used or 0,
                )
                >= limit
            ):
                raise BillingLimitError()
            session.add(
                BillingUsageDB(
                    id=operation_id,
                    owner_id=owner_id,
                    day=now.date().isoformat(),
                    status="pending",
                    created_at=now,
                ),
            )

    async def finish_usage(
        self,
        owner_id: str,
        operation_id: str,
        *,
        is_success: bool,
    ) -> None:
        async with self.database.session() as session, session.begin():
            usage = await session.get(
                BillingUsageDB,
                operation_id,
            )
            if usage and usage.owner_id == owner_id and usage.status == "pending":
                usage.status = "completed" if is_success else "failed"

    async def require_feature(
        self,
        owner_id: str,
        feature: str,
    ) -> None:
        status = await self.status(
            owner_id,
        )
        if status is None or self._configuration.application["entitlements"][status.type][feature] != "Available":
            raise BillingLimitError()

    async def require_report(
        self,
        owner_id: str,
        body: USExaminationRequest,
    ) -> None:
        status = await self.status(
            owner_id,
        )
        if status is None:
            raise BillingLimitError()
        model = self._configuration.resolve_neural_model(
            body.settingsAI.selectedNeuralModelId,
        )
        if model.entitlement == "pro" and status.type != "pro":
            raise BillingLimitError()
        if self._configuration.application["entitlements"][status.type]["settingsAI"] != "Available":
            defaults = self._configuration.application["ultrasound"]["neuralModel"]
            settings = body.settingsAI
            if (
                settings.isMarkdown
                or settings.temperature not in (None, defaults["temperature"])
                or settings.maxTokens not in (None, defaults["maxTokens"])
            ):
                raise BillingLimitError()

    async def create_checkout(
        self,
        owner_id: str,
        plan_id: str,
    ) -> BillingCheckoutResponse:
        self._plan(
            plan_id,
        )
        if not self._yookassa.is_available or not self._variables.billing_public_url:
            raise BillingUnavailableError()
        code = secrets.token_hex(
            4,
        ).upper()
        checkout_id = str(
            uuid4(),
        )
        expires = self._now() + timedelta(
            seconds=self._configuration.server.billing.checkout_ttl_seconds,
        )
        async with self.database.session() as session, session.begin():
            await self.database.lock_owner(
                session,
                owner_id,
            )
            active = await session.scalar(
                select(
                    BillingSubscriptionDB,
                )
                .where(
                    BillingSubscriptionDB.owner_id == owner_id,
                    BillingSubscriptionDB.is_revoked.is_(
                        False,
                    ),
                    BillingSubscriptionDB.paid_until > self._now(),
                )
                .limit(
                    1,
                ),
            )
            if active:
                raise BillingConflictError()
            session.add(
                BillingCheckoutDB(
                    id=checkout_id,
                    owner_id=owner_id,
                    plan_id=plan_id,
                    code_hash=self._hash(
                        code,
                    ),
                    expires_at=expires,
                ),
            )
        return BillingCheckoutResponse(
            id=UUID(
                checkout_id,
            ),
            code=code,
            expiresAt=expires,
        )

    async def bind_checkout(
        self,
        code: str,
        apple_token: str | None,
    ) -> tuple[str, BillingProductConfig]:
        browser_token = secrets.token_urlsafe(
            48,
        )
        async with self.database.session() as session, session.begin():
            checkout = await session.scalar(
                select(
                    BillingCheckoutDB,
                )
                .where(
                    BillingCheckoutDB.code_hash
                    == self._hash(
                        code.strip().upper(),
                    ),
                )
                .with_for_update(),
            )
            if (
                checkout is None
                or self._utc(
                    checkout.expires_at,
                )
                <= self._now()
                or checkout.browser_hash
            ):
                raise BillingAccessDeniedError()
            checkout.browser_hash = self._hash(
                browser_token,
            )
            if apple_token:
                # Attribution only; this is never an authentication credential.
                if (
                    len(
                        apple_token,
                    )
                    > 16384
                ):
                    raise BillingPurchaseError()
                checkout.apple_token = apple_token
            plan = self._plan(
                checkout.plan_id,
            )
        return browser_token, plan

    async def start_checkout_payment(
        self,
        browser_token: str,
        *,
        is_auto_renewal_accepted: bool,
    ) -> str:
        if not is_auto_renewal_accepted:
            raise BillingPurchaseError()
        async with self.database.session() as session, session.begin():
            checkout = await session.scalar(
                select(
                    BillingCheckoutDB,
                )
                .where(
                    BillingCheckoutDB.browser_hash
                    == self._hash(
                        browser_token,
                    ),
                )
                .with_for_update(),
            )
            if (
                checkout is None
                or self._utc(
                    checkout.expires_at,
                )
                <= self._now()
            ):
                raise BillingAccessDeniedError()
            await self.database.lock_owner(
                session,
                checkout.owner_id,
            )
            if checkout.payment_id:
                previous = await session.get(
                    BillingPaymentDB,
                    checkout.payment_id,
                )
                if previous is not None and previous.status == "canceled" and previous.provider_id is None:
                    checkout.payment_id = None
            if checkout.payment_id:
                order_id = checkout.payment_id
            else:
                active = await session.scalar(
                    select(
                        BillingSubscriptionDB,
                    )
                    .where(
                        BillingSubscriptionDB.owner_id == checkout.owner_id,
                        BillingSubscriptionDB.is_revoked.is_(
                            False,
                        ),
                        BillingSubscriptionDB.paid_until > self._now(),
                    )
                    .limit(
                        1,
                    ),
                )
                if active:
                    raise BillingConflictError()
                await self.replace_expired_subscriptions(
                    session,
                    checkout.owner_id,
                )
                # Serialize first purchases, including ones started from another browser.
                pending = await session.scalar(
                    select(
                        BillingPaymentDB,
                    )
                    .where(
                        BillingPaymentDB.owner_id == checkout.owner_id,
                        BillingPaymentDB.status.in_(
                            ("awaitingToken", "created", "pending", "needsReview"),
                        ),
                    )
                    .limit(
                        1,
                    ),
                )
                plan = self._plan(
                    checkout.plan_id,
                )
                if pending:
                    if (
                        pending.channel != "redirect"
                        or pending.plan_id != plan.id
                        or pending.subscription_id is not None
                        or pending.status == "needsReview"
                    ):
                        raise BillingConflictError()
                    order_id = pending.id
                else:
                    order_id = str(
                        uuid4(),
                    )
                    session.add(
                        BillingPaymentDB(
                            id=order_id,
                            owner_id=checkout.owner_id,
                            plan_id=plan.id,
                            entitlement=plan.entitlement,
                            amount_minor=plan.price.amountMinor,
                            currency=plan.price.currencyIso2Code,
                            interval_months=plan.period.interval_months,
                            interval_days=plan.period.interval_days,
                            status="created",
                            created_at=self._now(),
                        ),
                    )
                await session.flush()
                checkout.payment_id = order_id
                checkout.is_auto_renewal_accepted = True
                checkout.terms_version = self._catalog.termsVersion
        await self.submit_payment(
            order_id,
        )
        async with self.database.session() as session:
            order = await session.get(
                BillingPaymentDB,
                order_id,
            )
            if order is None or not order.confirmation_url:
                raise BillingPaymentError()
            return order.confirmation_url

    async def submit_payment(
        self,
        order_id: str,
        *,
        payment_token: str | None = None,
    ) -> None:
        is_initial_attempt = False
        async with self.database.session() as session, session.begin():
            order = await session.get(
                BillingPaymentDB,
                order_id,
            )
            if order is None:
                raise BillingPurchaseError()
            await self.database.lock_owner(
                session,
                order.owner_id,
            )
            await session.refresh(
                order,
                with_for_update=True,
            )
            if order.status not in ("created", "pending"):
                return
            if not order.provider_id:
                now = self._now()
                if order.channel == "sdk" and not payment_token and order.submitted_at is None:
                    if (
                        self._utc(
                            order.created_at,
                        )
                        + timedelta(
                            seconds=self._configuration.server.billing.checkout_ttl_seconds,
                        )
                        <= now
                    ):
                        order.status = "canceled"
                    return
                anchor = order.submitted_at or order.created_at
                if now - self._utc(
                    anchor,
                ) >= timedelta(
                    seconds=self._configuration.server.billing.unknown_payment_retry_seconds,
                ):
                    raise BillingConflictError()
                if order.channel == "sdk":
                    if not payment_token:
                        return
                    if not order.consent_at or order.payment_token_hash != self._hash(
                        payment_token,
                    ):
                        raise BillingPurchaseError()
                if order.submitted_at is None:
                    if order.subscription_id:
                        subscription = await session.get(
                            BillingSubscriptionDB,
                            order.subscription_id,
                        )
                        if not subscription or not subscription.is_auto_renewing or not subscription.payment_method_id:
                            order.status = "canceled"
                            return
                        order.renewal_payment_method_id = subscription.payment_method_id
                    order.submitted_at = now
                    is_initial_attempt = True
        # Commit the dispatch marker and immutable renewal method BEFORE network I/O.
        # After a crash/timeout, cancellation cannot turn a possibly paid order into an unsent one.
        try:
            await self._dispatch_payment(
                order_id,
                payment_token=payment_token,
            )
        except (BillingPaymentRejectedError, BillingUnavailableError) as error:
            # A rejection after an earlier unknown attempt cannot prove that earlier
            # attempt did not charge. Keep it unresolved for reconciliation.
            if is_initial_attempt:
                async with self.database.session() as session, session.begin():
                    order = await session.get(
                        BillingPaymentDB,
                        order_id,
                    )
                    if order is None:
                        raise BillingPurchaseError() from error
                    await self.database.lock_owner(
                        session,
                        order.owner_id,
                    )
                    await session.refresh(
                        order,
                        with_for_update=True,
                    )
                    if order.provider_id is None and order.status in ("created", "pending"):
                        order.status = "canceled"
                        if order.subscription_id:
                            subscription = await session.get(
                                BillingSubscriptionDB,
                                order.subscription_id,
                            )
                            if subscription:
                                subscription.is_auto_renewing = False
                                subscription.next_charge_at = None
            raise

    async def _dispatch_payment(
        self,
        order_id: str,
        *,
        payment_token: str | None,
    ) -> None:
        async with self.database.session() as session, session.begin():
            order = await session.get(
                BillingPaymentDB,
                order_id,
            )
            if order is None:
                raise BillingPurchaseError()
            await self.database.lock_owner(
                session,
                order.owner_id,
            )
            await session.refresh(
                order,
                with_for_update=True,
            )
            if order.status not in ("created", "pending"):
                return
            if order.provider_id:
                data = await self._yookassa.payment(
                    order.provider_id,
                )
            else:
                if order.submitted_at is None or self._now() - self._utc(
                    order.submitted_at,
                ) >= timedelta(
                    seconds=self._configuration.server.billing.unknown_payment_retry_seconds,
                ):
                    raise BillingConflictError()
                payload: dict[str, Any] = {
                    "amount": {"value": f"{Decimal(order.amount_minor) / 100:.2f}", "currency": order.currency},
                    "capture": True,
                    "description": f"Doglyad {order.plan_id}",
                    "metadata": {"order_id": order.id},
                }
                if order.subscription_id:
                    if not order.renewal_payment_method_id:
                        raise BillingConflictError()
                    payload["payment_method_id"] = order.renewal_payment_method_id
                elif order.channel == "sdk":
                    if not payment_token:
                        return
                    payload["payment_token"] = payment_token
                    payload["save_payment_method"] = True
                else:
                    payload["save_payment_method"] = True
                    payload["confirmation"] = {
                        "type": "redirect",
                        "return_url": (self._variables.billing_public_url or "").rstrip(
                            "/",
                        )
                        + "/complete",
                    }
                data = await self._yookassa.create(
                    order_id,
                    payload,
                )
            if (
                not isinstance(
                    data.get(
                        "id",
                    ),
                    str,
                )
                or not data["id"]
            ):
                raise BillingPaymentError()
            if order.provider_id and order.provider_id != data["id"]:
                raise BillingPaymentError()
            order.provider_id = data["id"]
            order.confirmation_url = (
                data.get(
                    "confirmation",
                    {},
                ).get(
                    "confirmation_url",
                )
                or None
            )
            method_type = data.get(
                "payment_method",
                {},
            ).get(
                "type",
            )
            order.payment_method_type = (
                method_type.strip() or None
                if isinstance(
                    method_type,
                    str,
                )
                else None
            )
            if order.status == "created":
                order.status = "pending"
        await self.apply_payment(
            data,
        )

    async def payment_notification(
        self,
        payment_id: str,
    ) -> None:
        # Both payment and refund objects come from the authenticated provider API.
        data = await self._yookassa.payment(
            payment_id,
        )
        if (
            data.get(
                "id",
            )
            != payment_id
        ):
            raise BillingPurchaseError()
        refunds = (
            await self._yookassa.refunds(
                payment_id,
            )
            if data.get(
                "status",
            )
            == "succeeded"
            else None
        )
        await self.apply_payment(
            data,
            refunds=refunds,
        )

    async def apply_payment(
        self,
        data: dict[str, Any],
        *,
        refunds: list[dict[str, Any]] | None = None,
    ) -> None:
        provider_id = data.get(
            "id",
        )
        if not isinstance(
            provider_id,
            str,
        ):
            raise BillingPurchaseError()
        metadata = data.get(
            "metadata",
            {},
        )
        order_id = (
            metadata.get(
                "order_id",
            )
            if isinstance(
                metadata,
                dict,
            )
            else None
        )
        async with self.database.session() as session, session.begin():
            order = (
                await session.get(
                    BillingPaymentDB,
                    order_id,
                )
                if isinstance(
                    order_id,
                    str,
                )
                else None
            )
            if order is None:
                # Unknown merchant transactions are not subscriptions.
                return
            await self.database.lock_owner(
                session,
                order.owner_id,
            )
            await session.refresh(
                order,
                with_for_update=True,
            )
            try:
                amount = Decimal(
                    str(
                        data["amount"]["value"],
                    ),
                )
                is_expected = (
                    amount
                    == Decimal(
                        order.amount_minor,
                    )
                    / 100
                    and data["amount"]["currency"] == order.currency
                    and str(
                        data["recipient"]["account_id"],
                    )
                    == self._variables.yookassa_shop_id
                    and data.get(
                        "test",
                    )
                    is self._variables.is_yookassa_test
                    and (order.provider_id is None or order.provider_id == provider_id)
                )
            except (KeyError, ValueError, ArithmeticError) as error:
                raise BillingPurchaseError() from error
            if not is_expected:
                raise BillingPurchaseError()
            order.provider_id = provider_id
            state = data.get(
                "status",
            )
            if state == "canceled":
                if order.status not in ("succeeded", "refunded"):
                    order.status = "canceled"
                    if order.subscription_id:
                        subscription = await session.get(
                            BillingSubscriptionDB,
                            order.subscription_id,
                        )
                        if subscription:
                            subscription.is_auto_renewing = False
                            subscription.next_charge_at = None
                return
            if (
                state != "succeeded"
                or data.get(
                    "paid",
                )
                is not True
            ):
                return
            event_id = f"yookassa:payment:{provider_id}"
            if (
                await session.get(
                    BillingEventDB,
                    event_id,
                )
                is None
            ):
                now = self._now()
                subscription = (
                    await session.get(
                        BillingSubscriptionDB,
                        order.subscription_id,
                    )
                    if order.subscription_id
                    else None
                )
                if subscription is None:
                    method = data.get(
                        "payment_method",
                        {},
                    )
                    subscription = BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=order.owner_id,
                        source="yookassa",
                        external_id=provider_id,
                        plan_id=order.plan_id,
                        entitlement=order.entitlement,
                        paid_until=now,
                        updated_at=now,
                        is_auto_renewing=method.get(
                            "saved",
                        )
                        is True,
                        payment_method_id=method.get(
                            "id",
                        )
                        if method.get(
                            "saved",
                        )
                        is True
                        else None,
                        amount_minor=order.amount_minor,
                        currency=order.currency,
                        interval_months=order.interval_months,
                        interval_days=order.interval_days,
                    )
                    session.add(
                        subscription,
                    )
                    await session.flush()
                    order.subscription_id = subscription.id
                start = max(
                    now,
                    self._utc(
                        subscription.paid_until,
                    ),
                )
                order.period_until = self._add_months(
                    start,
                    order.interval_months,
                ) + timedelta(
                    days=order.interval_days,
                )
                order.completed_at = now
                order.status = "succeeded"
                subscription.paid_until = order.period_until
                subscription.updated_at = now
                subscription.next_charge_at = order.period_until if subscription.is_auto_renewing else None
                session.add(
                    BillingEventDB(
                        id=event_id,
                        source="yookassa",
                        received_at=now,
                    ),
                )
            refunded_amount = data.get(
                "refunded_amount",
            )
            refunded_minor = 0
            if refunded_amount is not None:
                if (
                    not isinstance(
                        refunded_amount,
                        dict,
                    )
                    or refunded_amount.get(
                        "currency",
                    )
                    != order.currency
                ):
                    raise BillingPurchaseError()
                refunded_minor = self._money_minor(
                    refunded_amount.get(
                        "value",
                    ),
                )
            if refunded_minor > order.amount_minor:
                raise BillingPurchaseError()
            # Canonical reads can arrive out of order. Confirmed money never regresses.
            order.refunded_amount_minor = max(
                order.refunded_amount_minor,
                refunded_minor,
            )
            if refunds is not None:
                await self._record_refunds(
                    session,
                    order,
                    refunds,
                )
            if order.refunded_amount_minor == order.amount_minor and order.status != "refunded":
                order.status = "refunded"
                await session.flush()
                subscription = await session.get(
                    BillingSubscriptionDB,
                    order.subscription_id,
                )
                if subscription:
                    last_paid = await session.scalar(
                        select(
                            func.max(
                                BillingPaymentDB.period_until,
                            ),
                        ).where(
                            BillingPaymentDB.subscription_id == subscription.id,
                            BillingPaymentDB.status == "succeeded",
                        ),
                    )
                    subscription.paid_until = last_paid or self._now()
                    subscription.is_revoked = last_paid is None
                    subscription.is_auto_renewing = False
                    subscription.next_charge_at = None

    async def _record_refunds(
        self,
        session: AsyncSession,
        order: BillingPaymentDB,
        refunds: list[dict[str, Any]],
    ) -> None:
        for item in refunds:
            refund_id = item.get(
                "id",
            )
            status = item.get(
                "status",
            )
            amount = item.get(
                "amount",
            )
            if (
                not isinstance(
                    refund_id,
                    str,
                )
                or not refund_id.strip()
                or len(
                    refund_id,
                )
                > 128
                or item.get(
                    "payment_id",
                )
                != order.provider_id
                or status not in ("pending", "succeeded", "canceled")
                or not isinstance(
                    amount,
                    dict,
                )
                or amount.get(
                    "currency",
                )
                != order.currency
            ):
                raise BillingPurchaseError()
            amount_minor = self._money_minor(
                amount.get(
                    "value",
                ),
            )
            if not 0 < amount_minor <= order.amount_minor:
                raise BillingPurchaseError()
            try:
                created_at = datetime.fromisoformat(
                    item["created_at"].replace(
                        "Z",
                        "+00:00",
                    ),
                )
            except (KeyError, ValueError, AttributeError, TypeError) as error:
                raise BillingPurchaseError() from error
            if created_at.tzinfo is None:
                raise BillingPurchaseError()
            existing = await session.get(
                BillingRefundDB,
                refund_id,
            )
            if existing is None:
                session.add(
                    BillingRefundDB(
                        id=refund_id,
                        payment_id=order.id,
                        amount_minor=amount_minor,
                        currency=order.currency,
                        status=status,
                        created_at=created_at,
                        updated_at=self._now(),
                    ),
                )
            else:
                if (
                    existing.payment_id != order.id
                    or existing.amount_minor != amount_minor
                    or existing.currency != order.currency
                    or self._utc(
                        existing.created_at,
                    )
                    != self._utc(
                        created_at,
                    )
                ):
                    raise BillingPurchaseError()
                if existing.status in ("succeeded", "canceled") and existing.status != status:
                    if status == "pending":
                        continue
                    raise BillingPurchaseError()
                existing.status = status
                existing.updated_at = self._now()
            # Repeated IDs within or across paginated results remain one ledger row.
            await session.flush()
        recorded = await session.scalar(
            select(
                func.coalesce(
                    func.sum(
                        BillingRefundDB.amount_minor,
                    ),
                    0,
                ),
            ).where(
                BillingRefundDB.payment_id == order.id,
                BillingRefundDB.status == "succeeded",
            ),
        )
        if recorded is not None and recorded > order.refunded_amount_minor:
            # A refund may change between the payment read and the list read. Retry
            # the canonical payment rather than commit contradictory money totals.
            raise BillingPaymentError()

    @staticmethod
    def _money_minor(
        value: Any,
    ) -> int:
        try:
            amount = Decimal(
                str(
                    value,
                ),
            )
            minor = amount * 100
            if not amount.is_finite() or amount < 0 or minor != minor.to_integral_value():
                raise BillingPurchaseError()
            return int(
                minor,
            )
        except (ValueError, ArithmeticError) as error:
            raise BillingPurchaseError() from error

    async def cancel(
        self,
        owner_id: str,
    ) -> None:
        async with self.database.session() as session, session.begin():
            await self.database.lock_owner(
                session,
                owner_id,
            )
            subscriptions = await session.scalars(
                select(
                    BillingSubscriptionDB,
                )
                .where(
                    BillingSubscriptionDB.owner_id == owner_id,
                    BillingSubscriptionDB.source == "yookassa",
                )
                .with_for_update(),
            )
            for subscription in subscriptions:
                subscription.is_auto_renewing = False
                subscription.next_charge_at = None

    async def sync_apple(
        self,
        owner_id: str,
        signed: str,
    ) -> BillingIdentityResponse | None:
        transaction, environment = await self._apple.transaction(
            signed,
        )
        if environment is Environment.SANDBOX and not self._variables.is_apple_sandbox_allowed:
            raise BillingPurchaseError()
        original_id = str(
            transaction.originalTransactionId or "",
        )
        if not original_id:
            raise BillingPurchaseError()
        return await self._sync_apple_state(
            owner_id,
            original_id,
            environment,
        )

    async def _sync_apple_state(
        self,
        owner_id: str,
        original_id: str,
        environment: Environment,
    ) -> BillingIdentityResponse | None:
        current, renewal = await self._apple.current(
            original_id,
            environment,
        )
        product_id = str(
            current.productId or "",
        )
        product = next(
            (product for product in self._catalog.products if product.id == product_id),
            None,
        )
        if (
            not current.expiresDate
            or str(
                current.originalTransactionId,
            )
            != original_id
        ):
            raise BillingPurchaseError()
        original_owner = self._apple.owner_id(
            current,
        )
        restored: BillingIdentityResponse | None = None
        async with self.database.session() as session, session.begin():
            # All paths serialize on the original owner before the subscription row.
            # Restoration must not invert the lock order used by provider callbacks.
            await self.database.lock_owner(
                session,
                original_owner,
            )
            subscription = await session.scalar(
                select(
                    BillingSubscriptionDB,
                )
                .where(
                    BillingSubscriptionDB.source == "apple",
                    BillingSubscriptionDB.apple_environment == environment.value,
                    BillingSubscriptionDB.external_id == original_id,
                )
                .with_for_update(),
            )
            if product is None:
                if subscription is None or subscription.plan_id != product_id:
                    raise BillingPurchaseError()
                # A retired product is no longer offered. A previously verified
                # subscription still retains its tier for reconciliation/restoration.
                entitlement = subscription.entitlement
            else:
                entitlement = product.entitlement
            if subscription is None:
                if original_owner != owner_id:
                    raise BillingPurchaseError()
                subscription = BillingSubscriptionDB(
                    id=str(
                        uuid4(),
                    ),
                    owner_id=owner_id,
                    source="apple",
                    apple_environment=environment.value,
                    external_id=original_id,
                    plan_id=product_id,
                    entitlement=entitlement,
                    updated_at=self._now(),
                    paid_until=self._now(),
                )
                session.add(
                    subscription,
                )
            elif subscription.owner_id != original_owner:
                raise BillingPurchaseError()
            elif (
                subscription.owner_id != owner_id
                and not current.revocationDate
                and int(
                    current.expiresDate,
                )
                > int(
                    self._now().timestamp() * 1000,
                )
            ):
                # Restore only a server-verified existing purchase; never trust a supplied UUID.
                token = secrets.token_urlsafe(
                    48,
                )
                session.add(
                    BillingCredentialDB(
                        owner_id=subscription.owner_id,
                        token_hash=self._hash(
                            token,
                        ),
                    ),
                )
                restored = BillingIdentityResponse(
                    ownerId=UUID(
                        subscription.owner_id,
                    ),
                    accessToken=token,
                )
            expiry = max(
                int(
                    current.expiresDate,
                ),
                int(
                    renewal.gracePeriodExpiresDate or 0,
                ),
            )
            subscription.paid_until = datetime.fromtimestamp(
                expiry / 1000,
                UTC,
            ).replace(
                microsecond=0,
            )
            subscription.is_revoked = current.revocationDate is not None
            subscription.is_auto_renewing = renewal.autoRenewStatus == 1
            subscription.plan_id = product_id
            subscription.entitlement = entitlement
            subscription.updated_at = self._now()
        return restored

    async def apple_notification(
        self,
        signed: str,
    ) -> None:
        notification, _ = await self._apple.notification(
            signed,
        )
        data = notification.data
        if data and data.signedTransactionInfo:
            transaction, _ = await self._apple.transaction(
                data.signedTransactionInfo,
            )
            await self.sync_apple(
                self._apple.owner_id(
                    transaction,
                ),
                data.signedTransactionInfo,
            )

    async def tick(
        self,
    ) -> None:
        # A terminated worker must not hold a generation reservation beyond its timeout.
        async with self.database.session() as session, session.begin():
            await session.execute(
                update(
                    BillingUsageDB,
                )
                .where(
                    BillingUsageDB.status == "pending",
                    BillingUsageDB.created_at
                    < self._now()
                    - timedelta(
                        seconds=self._configuration.server.billing.pending_usage_timeout_seconds,
                    ),
                )
                .values(
                    status="failed",
                ),
            )
        await self.reconcile_apple()
        await self.reconcile_yookassa()
        async with self.database.session() as session:
            pending = list(
                await session.scalars(
                    select(
                        BillingPaymentDB.id,
                    )
                    .where(
                        BillingPaymentDB.status.in_(
                            ("created", "pending"),
                        ),
                    )
                    .limit(
                        self._configuration.server.billing.batch_size,
                    ),
                ),
            )
        for order_id in pending:
            try:
                await self.submit_payment(
                    order_id,
                )
            except BillingPaymentError:
                logging.getLogger(
                    __name__,
                ).warning(
                    "Payment reconciliation deferred: order=%s",
                    order_id,
                )
            except BillingConflictError:
                async with self.database.session() as session, session.begin():
                    order = await session.get(
                        BillingPaymentDB,
                        order_id,
                    )
                    if order is not None:
                        await self.database.lock_owner(
                            session,
                            order.owner_id,
                        )
                        await session.refresh(
                            order,
                            with_for_update=True,
                        )
                    if order and order.status in ("created", "pending"):
                        order.status = "needsReview"
                logging.getLogger(
                    __name__,
                ).error(
                    "Unknown payment outcome requires reconciliation: order=%s",
                    order_id,
                )
        async with self.database.session() as session:
            due = list(
                await session.execute(
                    select(
                        BillingSubscriptionDB.id,
                        BillingSubscriptionDB.owner_id,
                    )
                    .where(
                        BillingSubscriptionDB.source == "yookassa",
                        BillingSubscriptionDB.is_auto_renewing.is_(
                            True,
                        ),
                        BillingSubscriptionDB.next_charge_at <= self._now(),
                    )
                    .order_by(
                        BillingSubscriptionDB.next_charge_at,
                        BillingSubscriptionDB.id,
                    )
                    .limit(
                        self._configuration.server.billing.batch_size,
                    ),
                ),
            )
        for subscription_id, owner_id in due:
            async with self.database.session() as session, session.begin():
                await self.database.lock_owner(
                    session,
                    owner_id,
                )
                subscription = await session.get(
                    BillingSubscriptionDB,
                    subscription_id,
                    with_for_update=True,
                )
                if (
                    subscription is None
                    or not subscription.is_auto_renewing
                    or subscription.is_revoked
                    or subscription.next_charge_at is None
                    or self._utc(
                        subscription.next_charge_at,
                    )
                    > self._now()
                ):
                    continue
                key = self._utc(
                    subscription.next_charge_at,
                ).isoformat()
                existing = await session.scalar(
                    select(
                        BillingPaymentDB.id,
                    ).where(
                        BillingPaymentDB.subscription_id == subscription.id,
                        BillingPaymentDB.period_key == key,
                    ),
                )
                if existing:
                    continue
                session.add(
                    BillingPaymentDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=owner_id,
                        subscription_id=subscription.id,
                        period_key=key,
                        plan_id=subscription.plan_id,
                        entitlement=subscription.entitlement,
                        amount_minor=subscription.amount_minor,
                        currency=subscription.currency,
                        interval_months=subscription.interval_months,
                        interval_days=subscription.interval_days,
                        renewal_payment_method_id=subscription.payment_method_id,
                        status="created",
                        created_at=self._now(),
                    ),
                )

    async def replace_expired_subscriptions(
        self,
        session: AsyncSession,
        owner_id: str,
    ) -> None:
        """Requires the owner lock. A new purchase replaces only unsent old renewals."""
        renewals = list(
            await session.scalars(
                select(
                    BillingPaymentDB,
                ).where(
                    BillingPaymentDB.owner_id == owner_id,
                    BillingPaymentDB.subscription_id.is_not(
                        None,
                    ),
                    BillingPaymentDB.status.in_(
                        ("created", "pending", "needsReview"),
                    ),
                ),
            ),
        )
        if any(
            (order.provider_id or order.submitted_at or order.status == "needsReview" for order in renewals),
        ):
            raise BillingConflictError()
        for order in renewals:
            order.status = "canceled"
        expired = await session.scalars(
            select(
                BillingSubscriptionDB,
            ).where(
                BillingSubscriptionDB.owner_id == owner_id,
                BillingSubscriptionDB.source == "yookassa",
                BillingSubscriptionDB.paid_until <= self._now(),
            ),
        )
        for subscription in expired:
            subscription.is_auto_renewing = False
            subscription.next_charge_at = None
        # The next pending-order query must not reuse a just-canceled renewal.
        await session.flush()

    async def reconcile_yookassa(
        self,
    ) -> None:
        async with self.database.session() as session:
            orders = list(
                await session.scalars(
                    select(
                        BillingPaymentDB.id,
                    )
                    .where(
                        BillingPaymentDB.status.in_(
                            ("succeeded", "refunded"),
                        ),
                        BillingPaymentDB.provider_id.is_not(
                            None,
                        ),
                    )
                    .order_by(
                        BillingPaymentDB.reconciliation_attempted_at.asc().nulls_first(),
                        BillingPaymentDB.id,
                    )
                    .limit(
                        self._configuration.server.billing.batch_size,
                    ),
                ),
            )
        for order_id in orders:
            async with self.database.session() as session, session.begin():
                order = await session.get(
                    BillingPaymentDB,
                    order_id,
                )
                if order is None or not order.provider_id:
                    continue
                # Record attempts as well as successes so a failing provider object
                # cannot starve the rest of the bounded reconciliation queue.
                order.reconciliation_attempted_at = self._now()
                provider_id = order.provider_id
            try:
                await self.payment_notification(
                    provider_id,
                )
            except (BillingPaymentError, BillingPurchaseError):
                logging.getLogger(
                    __name__,
                ).warning(
                    "Completed payment reconciliation deferred: order=%s",
                    order_id,
                )

    async def reconcile_apple(
        self,
    ) -> None:
        async with self.database.session() as session:
            subscriptions = list(
                await session.scalars(
                    select(
                        BillingSubscriptionDB,
                    )
                    .where(
                        BillingSubscriptionDB.source == "apple",
                        BillingSubscriptionDB.updated_at
                        < self._now()
                        - timedelta(
                            seconds=self._configuration.server.billing.apple_reconciliation_interval_seconds,
                        ),
                    )
                    .order_by(
                        BillingSubscriptionDB.updated_at,
                    )
                    .limit(
                        self._configuration.server.billing.batch_size,
                    ),
                ),
            )
        for subscription in subscriptions:
            environment = Environment(
                subscription.apple_environment,
            )
            if environment is Environment.SANDBOX and not self._variables.is_apple_sandbox_allowed:
                continue
            try:
                await self._sync_apple_state(
                    subscription.owner_id,
                    subscription.external_id,
                    environment,
                )
            except (BillingPurchaseError, BillingUnavailableError):
                logging.getLogger(
                    __name__,
                ).warning(
                    "Apple subscription reconciliation deferred: subscription=%s",
                    subscription.id,
                )

    def _plan(
        self,
        plan_id: str,
    ) -> BillingProductConfig:
        plan = next(
            (plan for plan in self._catalog.products if plan.id == plan_id),
            None,
        )
        if plan is None:
            raise BillingPurchaseError()
        return plan

    @staticmethod
    def _now() -> datetime:
        return datetime.now(
            UTC,
        ).replace(
            microsecond=0,
        )

    @staticmethod
    def _utc(
        value: datetime,
    ) -> datetime:
        return (
            value.replace(
                tzinfo=UTC,
            )
            if value.tzinfo is None
            else value.astimezone(
                UTC,
            )
        )

    @staticmethod
    def _hash(
        value: str,
    ) -> str:
        return hashlib.sha256(
            value.encode(),
        ).hexdigest()

    @staticmethod
    def _add_months(
        value: datetime,
        months: int,
    ) -> datetime:
        month = value.month - 1 + months
        year = value.year + month // 12
        month = month % 12 + 1
        return value.replace(
            year=year,
            month=month,
            day=min(
                value.day,
                calendar.monthrange(
                    year,
                    month,
                )[1],
            ),
        )
