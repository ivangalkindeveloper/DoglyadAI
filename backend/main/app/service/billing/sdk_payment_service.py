from __future__ import annotations

import hashlib
from datetime import UTC, datetime, timedelta
from uuid import UUID, uuid4

from sqlalchemy import select

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.database.billing_payment_db import BillingPaymentDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.error.billing_conflict_error import BillingConflictError
from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.model.billing.billing_payment_response import BillingPaymentResponse
from app.model.billing.billing_period import BillingPeriod
from app.model.billing.billing_prepare_payment_response import BillingPreparePaymentResponse
from app.model.billing.billing_tokenize_payment_request import BillingTokenizePaymentRequest
from app.service.billing.subscription_service import SubscriptionService


class SDKPaymentService:
    def __init__(
        self,
        subscriptions: SubscriptionService,
        configuration: Configuration,
        variables: Variables,
    ) -> None:
        self._subscriptions = subscriptions
        self._database = subscriptions.database
        self._configuration = configuration
        self._variables = variables

    async def prepare(
        self,
        owner_id: str,
        plan_id: str,
        language: LanguageCode,
    ) -> BillingPreparePaymentResponse:
        settings = self._variables
        if not (
            settings.yookassa_shop_id and settings.yookassa_secret_key and settings.yookassa_client_application_key
        ):
            raise BillingUnavailableError()
        # Prices and tier are read from the server catalog, never from a client amount.
        plan = next(
            (
                item
                for item in self._subscriptions.plans(
                    language,
                ).products
                if item.id == plan_id
            ),
            None,
        )
        if plan is None:
            raise BillingPurchaseError()
        now = self._now()
        async with self._database.session() as session, session.begin():
            await self._database.lock_owner(
                session,
                owner_id,
            )
            active = await session.scalar(
                select(
                    BillingSubscriptionDB.id,
                )
                .where(
                    BillingSubscriptionDB.owner_id == owner_id,
                    BillingSubscriptionDB.is_revoked.is_(
                        False,
                    ),
                    BillingSubscriptionDB.paid_until > now,
                )
                .limit(
                    1,
                ),
            )
            if active:
                raise BillingConflictError()
            await self._subscriptions.replace_expired_subscriptions(
                session,
                owner_id,
            )
            pending = await session.scalar(
                select(
                    BillingPaymentDB,
                )
                .where(
                    BillingPaymentDB.owner_id == owner_id,
                    BillingPaymentDB.status.in_(
                        ("awaitingToken", "created", "pending", "needsReview"),
                    ),
                )
                .with_for_update()
                .limit(
                    1,
                ),
            )
            if (
                pending
                and pending.channel == "sdk"
                and pending.status == "awaitingToken"
                and (
                    pending.plan_id != plan_id
                    or self._utc(
                        pending.created_at,
                    )
                    + timedelta(
                        seconds=self._configuration.server.billing.checkout_ttl_seconds,
                    )
                    <= now
                )
            ):
                pending.status = "canceled"
                pending = None
            if pending and (pending.channel != "sdk" or pending.plan_id != plan_id or pending.status == "needsReview"):
                raise BillingConflictError()
            if pending is None:
                pending = BillingPaymentDB(
                    id=str(
                        uuid4(),
                    ),
                    owner_id=owner_id,
                    plan_id=plan.id,
                    entitlement=plan.entitlement,
                    amount_minor=plan.price.amountMinor,
                    currency=plan.price.currencyIso2Code,
                    interval_months=plan.period.interval_months,
                    interval_days=plan.period.interval_days,
                    channel="sdk",
                    status="awaitingToken",
                    terms_version=self._subscriptions.terms_version,
                    created_at=now,
                )
                session.add(
                    pending,
                )
            strings = self._configuration.application_localizations[language].strings
            tier = strings["subscriptionBaseLabel" if plan.entitlement == "base" else "subscriptionProLabel"]
            period = strings[
                BillingPeriod.from_interval(
                    pending.interval_months,
                    pending.interval_days,
                ).locale_key
            ]
            description = (
                strings["paywallPlanTitle"]
                .replace(
                    "{prefix}",
                    tier,
                )
                .replace(
                    "{description}",
                    period,
                )
            )
            response = BillingPreparePaymentResponse.model_validate(
                {
                    "payment": self._response(
                        pending,
                    ),
                    "shopId": settings.yookassa_shop_id,
                    "clientApplicationKey": settings.yookassa_client_application_key,
                    "shopName": "Doglyad",
                    "description": description,
                    "termsVersion": pending.terms_version,
                    "price": {"amountMinor": pending.amount_minor, "currencyIso2Code": pending.currency},
                },
            )
        return response

    async def tokenize(
        self,
        owner_id: str,
        body: BillingTokenizePaymentRequest,
    ) -> BillingPaymentResponse:
        if not body.isAutoRenewalAccepted:
            raise BillingPurchaseError()
        payment_id = str(
            body.paymentId,
        )
        token_hash = hashlib.sha256(
            body.paymentToken.encode(),
        ).hexdigest()
        async with self._database.session() as session, session.begin():
            await self._database.lock_owner(
                session,
                owner_id,
            )
            order = await session.scalar(
                select(
                    BillingPaymentDB,
                )
                .where(
                    BillingPaymentDB.id == payment_id,
                    BillingPaymentDB.owner_id == owner_id,
                    BillingPaymentDB.channel == "sdk",
                )
                .with_for_update(),
            )
            if order is None:
                raise BillingAccessDeniedError()
            if order.status in ("succeeded", "canceled", "refunded"):
                return self._response(
                    order,
                )
            if (
                order.status == "needsReview"
                or body.termsVersion != order.terms_version
                or (order.payment_token_hash is not None and order.payment_token_hash != token_hash)
            ):
                raise BillingConflictError()
            if order.status == "awaitingToken":
                if (
                    self._utc(
                        order.created_at,
                    )
                    + timedelta(
                        seconds=self._configuration.server.billing.checkout_ttl_seconds,
                    )
                    <= self._now()
                ):
                    raise BillingConflictError()
                order.payment_token_hash = token_hash
                order.consent_at = self._now()
                order.status = "created"
        # The order and token hash are durable before the first provider request.
        # No raw token is written to the database, task queue or log.
        await self._subscriptions.submit_payment(
            payment_id,
            payment_token=body.paymentToken,
        )
        return await self.check(
            owner_id,
            payment_id,
        )

    async def check(
        self,
        owner_id: str,
        payment_id: str,
        *,
        is_abandoned: bool = False,
    ) -> BillingPaymentResponse:
        async with self._database.session() as session, session.begin():
            await self._database.lock_owner(
                session,
                owner_id,
            )
            order = await session.scalar(
                select(
                    BillingPaymentDB,
                )
                .where(
                    BillingPaymentDB.id == payment_id,
                    BillingPaymentDB.owner_id == owner_id,
                    BillingPaymentDB.channel == "sdk",
                )
                .with_for_update(),
            )
            if order is None:
                raise BillingAccessDeniedError()
            if is_abandoned and order.status == "awaitingToken":
                order.status = "canceled"
            provider_id = order.provider_id
        if provider_id:
            await self._subscriptions.payment_notification(
                provider_id,
            )
        async with self._database.session() as session:
            order = await session.get(
                BillingPaymentDB,
                payment_id,
            )
            if order is None:
                raise BillingAccessDeniedError()
            return self._response(
                order,
            )

    @staticmethod
    def _response(
        order: BillingPaymentDB,
    ) -> BillingPaymentResponse:
        return BillingPaymentResponse.model_validate(
            {
                "id": UUID(
                    order.id,
                ),
                "planId": order.plan_id,
                "status": order.status,
                "confirmationUrl": order.confirmation_url,
                "paymentMethodType": order.payment_method_type,
            },
        )

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
