from __future__ import annotations

from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import select

from app.core.configuration.configuration import Configuration
from app.core.configuration.variables import Variables
from app.core.localization.language_code import LanguageCode
from app.database.billing_payment_db import BillingPaymentDB
from app.database.billing_subscription_db import BillingSubscriptionDB
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.error.billing_conflict_error import BillingConflictError
from app.error.billing_payment_error import BillingPaymentError
from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.model.billing.billing_payment_response import BillingPaymentResponse
from app.model.billing.billing_prepare_payment_response import BillingPreparePaymentResponse
from app.model.billing.billing_price import BillingPrice
from app.service.billing.subscription_service import SubscriptionService


class CheckoutPaymentService:
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
        *,
        is_auto_renewing: bool = True,
        expected_price: BillingPrice | None = None,
    ) -> BillingPreparePaymentResponse:
        if not self._subscriptions.is_payment_available or (
            not self._variables.is_robokassa_test and not self._variables.is_robokassa_live_enabled
        ):
            raise BillingUnavailableError()
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
        if expected_price is not None and expected_price != plan.price:
            raise BillingConflictError()
        async with self._database.session() as session:
            previous = await session.scalar(
                select(
                    BillingPaymentDB,
                )
                .where(
                    BillingPaymentDB.owner_id == owner_id,
                    BillingPaymentDB.period_key.is_(
                        None,
                    ),
                    BillingPaymentDB.status.in_(
                        ("created", "pending", "needsReview"),
                    ),
                )
                .order_by(
                    BillingPaymentDB.created_at.desc(),
                )
                .limit(
                    1,
                ),
            )
            previous_id = previous.id if previous else None
            is_replacement_requested = previous is not None and (
                previous.plan_id != plan_id
                or previous.is_auto_renewing != is_auto_renewing
                or previous.amount_minor != plan.price.amountMinor
                or previous.currency != plan.price.currencyIso2Code
            )
        if previous_id:
            await self._subscriptions.reconcile_pending_payment(
                previous_id,
                is_cancel_requested=is_replacement_requested,
            )
            async with self._database.session() as session:
                previous = await session.get(
                    BillingPaymentDB,
                    previous_id,
                )
                if previous and previous.status == "succeeded" and previous.plan_id == plan_id:
                    resumed = previous
                else:
                    resumed = None
            if resumed:
                return BillingPreparePaymentResponse(
                    payment=await self._response(
                        resumed,
                    ),
                    checkoutUrl=resumed.confirmation_url,
                )
        now = self._now()
        async with self._database.session() as session, session.begin():
            await self._database.lock_owner(
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
                    BillingSubscriptionDB.starts_at <= now,
                    BillingSubscriptionDB.paid_until > now,
                )
                .limit(
                    1,
                ),
            )
            if active and active.source != "robokassa":
                raise BillingConflictError()
            await self._subscriptions.replace_expired_subscriptions(
                session,
                owner_id,
            )
            order = await session.scalar(
                select(
                    BillingPaymentDB,
                )
                .where(
                    BillingPaymentDB.owner_id == owner_id,
                    BillingPaymentDB.source == "robokassa",
                    BillingPaymentDB.status.in_(
                        ("created", "pending", "needsReview"),
                    ),
                )
                .with_for_update()
                .limit(
                    1,
                ),
            )
            if order and (
                order.plan_id != plan_id
                or order.subscription_id
                or order.is_auto_renewing != is_auto_renewing
                or order.amount_minor != plan.price.amountMinor
                or order.currency != plan.price.currencyIso2Code
            ):
                raise BillingConflictError()
            if order is None:
                order = BillingPaymentDB(
                    id=str(
                        uuid4(),
                    ),
                    owner_id=owner_id,
                    previous_subscription_id=active.id if active else None,
                    plan_id=plan.id,
                    entitlement=plan.entitlement,
                    amount_minor=plan.price.amountMinor,
                    currency=plan.price.currencyIso2Code,
                    interval_months=plan.period.interval_months,
                    interval_days=plan.period.interval_days,
                    receipt_description="Doglyad " + plan.title,
                    channel="redirect",
                    status="created",
                    terms_version=self._subscriptions.terms_version,
                    consent_at=now,
                    is_auto_renewing=is_auto_renewing,
                    created_at=now,
                )
                session.add(
                    order,
                )
                await session.flush()
            order_id = order.id
        async with self._database.session() as session:
            order = await session.get(
                BillingPaymentDB,
                order_id,
            )
            is_submitted = order is not None and order.submitted_at is not None
        if is_submitted:
            await self._subscriptions.reconcile_pending_payment(
                order_id,
            )
        else:
            await self._subscriptions.submit_payment(
                order_id,
            )
        async with self._database.session() as session:
            order = await session.get(
                BillingPaymentDB,
                order_id,
            )
            if order is None:
                raise BillingPurchaseError()
            if order.status in ("created", "pending") and not order.confirmation_url:
                raise BillingPaymentError()
        return BillingPreparePaymentResponse(
            payment=await self._response(
                order,
            ),
            checkoutUrl=order.confirmation_url,
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
                    BillingPaymentDB.channel == "redirect",
                )
                .with_for_update(),
            )
            if order is None:
                raise BillingAccessDeniedError()
        await self._subscriptions.reconcile_pending_payment(
            payment_id,
            is_cancel_requested=is_abandoned,
        )
        async with self._database.session() as session:
            order = await session.get(
                BillingPaymentDB,
                payment_id,
            )
            if order is None:
                raise BillingAccessDeniedError()
        return await self._response(
            order,
        )

    async def _response(
        self,
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
                "recoveryKey": await self._subscriptions.recovery_key(
                    order.owner_id,
                )
                if order.status == "succeeded"
                else None,
            },
        )

    @staticmethod
    def _now() -> datetime:
        return datetime.now(
            UTC,
        ).replace(
            microsecond=0,
        )
