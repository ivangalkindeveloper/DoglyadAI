from __future__ import annotations

import calendar
import hashlib
import logging
import re
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
from app.model.billing.billing_identity_response import BillingIdentityResponse
from app.model.billing.billing_product_config import BillingProductConfig
from app.model.billing.billing_products_response import BillingProductsResponse
from app.model.billing.billing_status_response import BillingStatusResponse
from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.billing.apple_subscription_verifier import AppleSubscriptionVerifier
from app.service.billing.billing_catalog_response_service import BillingCatalogResponseService
from app.service.billing.billing_recovery_key_cipher import BillingRecoveryKeyCipher
from app.service.billing.robokassa_payment_provider import RobokassaPaymentProvider


class SubscriptionService:
    def __init__(
        self,
        database: BillingDatabase,
        configuration: Configuration,
        variables: Variables,
        robokassa: RobokassaPaymentProvider,
        apple: AppleSubscriptionVerifier,
    ) -> None:
        self.database = database
        self._configuration = configuration
        self._variables = variables
        self._robokassa = robokassa
        self._apple = apple
        self._recovery_cipher = BillingRecoveryKeyCipher(
            variables.report_generation_encryption_key,
        )
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

    @property
    def is_payment_available(
        self,
    ) -> bool:
        return self._robokassa.is_available

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
        async with self.database.session() as session, session.begin():
            owner = await self.database.lock_owner(
                session,
                owner_id,
            )
            return self._owner_recovery_key(
                owner,
            )

    def _owner_recovery_key(
        self,
        owner: BillingOwnerDB,
    ) -> str:
        if owner.recovery_ciphertext is not None:
            key = self._recovery_cipher.open(
                owner.id,
                owner.recovery_ciphertext,
            )
            if owner.recovery_hash != self._hash(
                key,
            ):
                raise BillingPurchaseError()
            return key
        key = secrets.token_hex(
            24,
        ).upper()
        owner.recovery_ciphertext = self._recovery_cipher.seal(
            owner.id,
            key,
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
            recoveryKey=key.strip().upper(),
        )

    def plans(
        self,
        language: LanguageCode,
    ) -> BillingProductsResponse:
        return BillingCatalogResponseService.make(
            self._catalog,
            self._configuration,
            language,
        )

    async def status(
        self,
        owner_id: str,
    ) -> BillingStatusResponse | None:
        now = self._now()
        async with self.database.session() as session, session.begin():
            owner = await self.database.lock_owner(
                session,
                owner_id,
            )
            subscription = await session.scalar(
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
                recoveryKey=self._owner_recovery_key(
                    owner,
                ),
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
                    BillingSubscriptionDB.starts_at <= now,
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

    async def submit_payment(
        self,
        order_id: str,
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
            if order.source != "robokassa":
                raise BillingPurchaseError()
            if order.status not in ("created", "pending"):
                return
            now = self._now()
            if order.subscription_id is None and order.consent_at is None:
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
                order.merchant_login = self._variables.robokassa_merchant_login
                order.is_test = self._variables.is_robokassa_test
                order.submitted_at = now
                is_initial_attempt = True
            elif (
                order.merchant_login != self._variables.robokassa_merchant_login
                or order.is_test is not self._variables.is_robokassa_test
            ):
                raise BillingConflictError()
        # Commit the dispatch marker and immutable renewal method BEFORE network I/O.
        # After a crash/timeout, cancellation cannot turn a possibly paid order into an unsent one.
        try:
            await self._dispatch_payment(
                order_id,
                is_initial_attempt=is_initial_attempt,
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
        is_initial_attempt: bool,
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
            if order.source != "robokassa":
                raise BillingPurchaseError()
            if order.status not in ("created", "pending"):
                return
            if not order.invoice_id:
                raise BillingPurchaseError()
            if not is_initial_attempt:
                data = await self._robokassa.payment(
                    order.invoice_id,
                )
                if (
                    data.get(
                        "status",
                    )
                    == "pending"
                    and not order.confirmation_url
                    and order.subscription_id is None
                ):
                    order.confirmation_url = await self._robokassa.invoice(
                        order.invoice_id,
                    )
            else:
                if order.submitted_at is None:
                    raise BillingConflictError()
                payload: dict[str, Any] = {
                    "invoice_id": order.invoice_id,
                    "amount": {"value": f"{Decimal(order.amount_minor) / 100:.2f}", "currency": order.currency},
                    "description": (order.receipt_description or "Doglyad")[:100],
                    "email": order.receipt_email,
                    "is_auto_renewing": order.is_auto_renewing,
                    "expires_at": (
                        self._utc(
                            order.created_at,
                        )
                        + timedelta(
                            seconds=self._configuration.server.billing.checkout_ttl_seconds,
                        )
                    ).isoformat(),
                }
                if order.subscription_id:
                    if not order.renewal_payment_method_id:
                        raise BillingConflictError()
                    payload["payment_method_id"] = order.renewal_payment_method_id
                data = await self._robokassa.create(
                    order_id,
                    payload,
                )
            data["metadata"] = {"order_id": order.id}
            if data.get(
                "status",
            ) in ("succeeded", "canceled"):
                pass
            elif not is_initial_attempt and self._now() - self._utc(
                order.submitted_at or order.created_at,
            ) >= timedelta(
                seconds=self._configuration.server.billing.unknown_payment_retry_seconds,
            ):
                raise BillingConflictError()
            order.provider_invoice_uuid = (
                data.get(
                    "invoice_uuid",
                )
                or order.provider_invoice_uuid
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
            order.confirmation_url = order.confirmation_url or (
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

    async def reconcile_pending_payment(
        self,
        order_id: str,
        *,
        is_cancel_requested: bool = False,
    ) -> None:
        async with self.database.session() as session, session.begin():
            order = await session.get(
                BillingPaymentDB,
                order_id,
            )
            if order is None:
                raise BillingPurchaseError()
            if order.status in ("succeeded", "refunded", "canceled"):
                return
            owner_id, invoice_id = order.owner_id, order.invoice_id
            await self.database.lock_owner(
                session,
                owner_id,
            )
            await session.refresh(
                order,
                with_for_update=True,
            )
            is_expired = (
                self._utc(
                    order.created_at,
                )
                + timedelta(
                    seconds=self._configuration.server.billing.checkout_ttl_seconds,
                )
                <= self._now()
            )
            if order.submitted_at is None:
                if is_cancel_requested or is_expired:
                    order.status = "canceled"
                return
            if (
                self._utc(
                    order.submitted_at,
                )
                + timedelta(
                    seconds=self._configuration.server.billing.unknown_payment_retry_seconds,
                )
                <= self._now()
            ):
                order.status = "needsReview"
            order.reconciliation_attempted_at = datetime.now(
                UTC,
            )
            is_initial = order.period_key is None
            is_url_missing = not order.confirmation_url
        await self.payment_notification(
            invoice_id,
        )
        async with self.database.session() as session:
            order = await session.get(
                BillingPaymentDB,
                order_id,
            )
            if order is None or order.status in ("succeeded", "refunded", "canceled"):
                return
        if not is_initial or not (is_cancel_requested or is_expired or is_url_missing):
            return
        info = await self._robokassa.invoice_information(
            invoice_id,
        )
        if info is None:
            return
        if (is_cancel_requested or is_expired) and info["invoiceStatus"] == "NotPaid" and not info["payments"]:
            await self._robokassa.deactivate_invoice(
                invoice_id,
            )
            info = await self._robokassa.invoice_information(
                invoice_id,
            )
            if info is None:
                raise BillingPaymentError()
        async with self.database.session() as session, session.begin():
            await self.database.lock_owner(
                session,
                owner_id,
            )
            order = await session.get(
                BillingPaymentDB,
                order_id,
                with_for_update=True,
            )
            if order is None or order.status in ("succeeded", "refunded"):
                return
            if info["invoiceStatus"] == "Expired" and not info["payments"]:
                order.status = "canceled"
                return
            if info["invoiceStatus"] == "NotPaid" and not order.confirmation_url:
                order.confirmation_url = self._robokassa._checkout_url(
                    info.get(
                        "invoicePaymentUrl",
                    ),
                )
                order.provider_id = invoice_id

    async def payment_notification(
        self,
        payment_id: str,
        *,
        receipt_email: str | None = None,
    ) -> None:
        async with self.database.session() as session:
            order = await session.scalar(
                select(
                    BillingPaymentDB,
                ).where(
                    BillingPaymentDB.invoice_id == payment_id,
                ),
            )
            if order is None or order.source != "robokassa" or order.submitted_at is None:
                raise BillingPurchaseError()
            if (
                order.merchant_login != self._variables.robokassa_merchant_login
                or order.is_test is not self._variables.is_robokassa_test
            ):
                raise BillingPurchaseError()
            order_id = order.id
        data = await self._robokassa.payment(
            payment_id,
        )
        if (
            data.get(
                "id",
            )
            != payment_id
        ):
            raise BillingPurchaseError()
        data["metadata"] = {"order_id": order_id}
        data["receipt_email"] = receipt_email
        await self.apply_payment(
            data,
        )
        await self.reconcile_refunds(
            order_id,
        )

    async def robokassa_notification(
        self,
        fields: dict[str, str],
    ) -> None:
        self._robokassa.verify_notification(
            fields,
        )
        invoice_id = fields["InvId"]
        email = fields.get(
            "EMail",
            "",
        ).strip()
        receipt_email = (
            email
            if len(
                email,
            )
            <= 254
            and re.fullmatch(
                r"[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+",
                email,
            )
            else None
        )
        async with self.database.session() as session:
            order = await session.scalar(
                select(
                    BillingPaymentDB,
                ).where(
                    BillingPaymentDB.invoice_id == invoice_id,
                ),
            )
            if (
                order is None
                or order.submitted_at is None
                or order.merchant_login != self._variables.robokassa_merchant_login
                or order.is_test is not self._variables.is_robokassa_test
            ):
                raise BillingPurchaseError()
            if (
                self._money_minor(
                    fields["OutSum"],
                )
                != order.amount_minor
            ):
                raise BillingPurchaseError()
            if (
                fields.get(
                    "Shp_order_id",
                    order.id,
                )
                != order.id
            ):
                raise BillingPurchaseError()
            order_id = order.id
        if self._variables.is_robokassa_test:
            data = self._robokassa._pending(
                invoice_id,
            )
            data.update(
                status="succeeded",
                paid=True,
                amount={"value": fields["OutSum"], "currency": "RUB"},
                metadata={"order_id": order_id},
                receipt_email=receipt_email,
            )
            await self.apply_payment(
                data,
            )
        else:
            # SuccessURL, mobile callbacks and valid signatures do not replace the
            # production canonical read. Do not acknowledge until it is successful.
            await self.payment_notification(
                invoice_id,
                receipt_email=receipt_email,
            )
            async with self.database.session() as session:
                order = await session.get(
                    BillingPaymentDB,
                    order_id,
                )
                if order is None or order.status not in ("succeeded", "refunded"):
                    raise BillingPaymentError()

    async def apply_payment(
        self,
        data: dict[str, Any],
        *,
        refunds: list[dict[str, Any]] | None = None,
    ) -> None:
        if data.get(
            "status",
        ) not in ("succeeded", "canceled"):
            return
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
                if (
                    data.get(
                        "status",
                    )
                    == "canceled"
                    and "amount" not in data
                ):
                    data["amount"] = {"value": f"{Decimal(order.amount_minor) / 100:.2f}", "currency": order.currency}
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
                    == self._variables.robokassa_merchant_login
                    and data.get(
                        "test",
                    )
                    is self._variables.is_robokassa_test
                    and order.invoice_id == provider_id
                    and order.merchant_login == self._variables.robokassa_merchant_login
                    and order.is_test is self._variables.is_robokassa_test
                    and order.submitted_at is not None
                    and (order.provider_id is None or order.provider_id == provider_id)
                )
            except (KeyError, ValueError, ArithmeticError) as error:
                raise BillingPurchaseError() from error
            if not is_expected:
                raise BillingPurchaseError()
            if not order.receipt_email and data.get(
                "receipt_email",
            ):
                order.receipt_email = data["receipt_email"]
            if order.receipt_email and order.subscription_id:
                subscription = await session.get(
                    BillingSubscriptionDB,
                    order.subscription_id,
                )
                if subscription is not None and not subscription.receipt_email:
                    subscription.receipt_email = order.receipt_email
            order.provider_id = provider_id
            order.provider_operation_key = (
                data.get(
                    "op_key",
                )
                or order.provider_operation_key
            )
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
            event_id = f"robokassa:payment:{provider_id}"
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
                    start = now
                    if order.previous_subscription_id:
                        previous = await session.get(
                            BillingSubscriptionDB,
                            order.previous_subscription_id,
                        )
                        if previous is None or previous.owner_id != order.owner_id or previous.source != "robokassa":
                            raise BillingPurchaseError()
                    previous_subscriptions = await session.scalars(
                        select(
                            BillingSubscriptionDB,
                        ).where(
                            BillingSubscriptionDB.owner_id == order.owner_id,
                            BillingSubscriptionDB.source == "robokassa",
                            BillingSubscriptionDB.is_revoked.is_(
                                False,
                            ),
                        ),
                    )
                    for previous in previous_subscriptions:
                        previous.is_revoked = True
                        previous.is_auto_renewing = False
                        previous.next_charge_at = None
                    method = data.get(
                        "payment_method",
                        {},
                    )
                    subscription = BillingSubscriptionDB(
                        id=str(
                            uuid4(),
                        ),
                        owner_id=order.owner_id,
                        source="robokassa",
                        receipt_email=order.receipt_email,
                        external_id=provider_id,
                        plan_id=order.plan_id,
                        entitlement=order.entitlement,
                        starts_at=start,
                        paid_until=start,
                        updated_at=now,
                        is_auto_renewing=order.is_auto_renewing
                        and method.get(
                            "saved",
                        )
                        is True,
                        payment_method_id=method.get(
                            "id",
                        )
                        if order.is_auto_renewing
                        and method.get(
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
                        source="robokassa",
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
                    subscription.is_revoked = subscription.is_revoked or last_paid is None
                    subscription.is_auto_renewing = False
                    subscription.next_charge_at = None

    async def request_refund(
        self,
        payment_id: str,
        amount_minor: int,
        operation_id: str,
    ) -> str:
        if self._variables.is_robokassa_test or not self._variables.robokassa_password3:
            raise BillingUnavailableError()
        async with self.database.session() as session, session.begin():
            order = await session.get(
                BillingPaymentDB,
                payment_id,
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
            existing = await session.get(
                BillingRefundDB,
                operation_id,
            )
            if existing:
                if existing.payment_id != payment_id or existing.amount_minor != amount_minor:
                    raise BillingConflictError()
                return existing.id
            if (
                order.source != "robokassa"
                or order.status != "succeeded"
                or not order.provider_operation_key
                or order.is_test
                or order.merchant_login != self._variables.robokassa_merchant_login
            ):
                raise BillingPurchaseError()
            reserved = await session.scalar(
                select(
                    func.coalesce(
                        func.sum(
                            BillingRefundDB.amount_minor,
                        ),
                        0,
                    ),
                ).where(
                    BillingRefundDB.payment_id == payment_id,
                    BillingRefundDB.status != "canceled",
                ),
            )
            if (
                not 0
                < amount_minor
                <= order.amount_minor
                - int(
                    reserved or 0,
                )
            ):
                raise BillingPurchaseError()
            now = self._now()
            session.add(
                BillingRefundDB(
                    id=operation_id,
                    payment_id=payment_id,
                    amount_minor=amount_minor,
                    currency=order.currency,
                    status="needsReview",
                    created_at=now,
                    updated_at=now,
                ),
            )
            op_key = order.provider_operation_key
        # No automated replay of Refund/Create after a timeout/crash.
        request_id = await self._robokassa.refund(
            op_key,
            f"{Decimal(amount_minor) / 100:.2f}",
            operation_id,
        )
        async with self.database.session() as session, session.begin():
            refund = await session.get(
                BillingRefundDB,
                operation_id,
                with_for_update=True,
            )
            if refund is None:
                raise BillingPaymentError()
            refund.provider_request_id = request_id
            refund.status = "pending"
        await self.reconcile_refunds(
            payment_id,
        )
        return operation_id

    async def reconcile_refunds(
        self,
        payment_id: str,
    ) -> None:
        async with self.database.session() as session:
            refunds = list(
                await session.scalars(
                    select(
                        BillingRefundDB,
                    ).where(
                        BillingRefundDB.payment_id == payment_id,
                        BillingRefundDB.provider_request_id.is_not(
                            None,
                        ),
                        BillingRefundDB.status == "pending",
                    ),
                ),
            )
        for item in refunds:
            if not item.provider_request_id:
                continue
            result = await self._robokassa.refund_state(
                item.provider_request_id,
            )
            if (
                self._money_minor(
                    result["amount"],
                )
                != item.amount_minor
            ):
                raise BillingPurchaseError()
            async with self.database.session() as session, session.begin():
                order = await session.get(
                    BillingPaymentDB,
                    payment_id,
                )
                if order is None:
                    raise BillingPurchaseError()
                await self.database.lock_owner(
                    session,
                    order.owner_id,
                )
                refund = await session.get(
                    BillingRefundDB,
                    item.id,
                    with_for_update=True,
                )
                if refund is None or refund.status != "pending":
                    continue
                refund.status = {"finished": "succeeded", "processing": "pending", "canceled": "canceled"}[
                    result["label"]
                ]
                refund.updated_at = self._now()
                await session.flush()
                total = await session.scalar(
                    select(
                        func.coalesce(
                            func.sum(
                                BillingRefundDB.amount_minor,
                            ),
                            0,
                        ),
                    ).where(
                        BillingRefundDB.payment_id == payment_id,
                        BillingRefundDB.status == "succeeded",
                    ),
                )
                order.refunded_amount_minor = int(
                    total or 0,
                )
                if order.refunded_amount_minor > order.amount_minor:
                    raise BillingPurchaseError()
                if order.refunded_amount_minor == order.amount_minor:
                    order.status = "refunded"
                    await session.flush()
                    subscription = (
                        await session.get(
                            BillingSubscriptionDB,
                            order.subscription_id,
                        )
                        if order.subscription_id
                        else None
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
                        subscription.is_revoked = subscription.is_revoked or last_paid is None
                        subscription.is_auto_renewing = False
                        subscription.next_charge_at = None
                # Receipt correction is not implied by a successful money refund.
                order.is_receipt_pending = True

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

    async def set_auto_renewal(
        self,
        owner_id: str,
        is_auto_renewing: bool,
    ) -> None:
        if is_auto_renewing:
            raise BillingConflictError()
        async with self.database.session() as session, session.begin():
            await self.database.lock_owner(
                session,
                owner_id,
            )
            subscriptions = list(
                await session.scalars(
                    select(
                        BillingSubscriptionDB,
                    )
                    .where(
                        BillingSubscriptionDB.owner_id == owner_id,
                        BillingSubscriptionDB.source == "robokassa",
                        BillingSubscriptionDB.is_revoked.is_(
                            False,
                        ),
                        BillingSubscriptionDB.paid_until > self._now(),
                    )
                    .order_by(
                        BillingSubscriptionDB.starts_at.desc(),
                    )
                    .with_for_update(),
                ),
            )
            if not subscriptions:
                raise BillingPurchaseError()
            for item in subscriptions:
                item.is_auto_renewing = False
                item.next_charge_at = item.paid_until if item.is_auto_renewing else None

            if not is_auto_renewing:
                await session.execute(
                    update(
                        BillingPaymentDB,
                    )
                    .where(
                        BillingPaymentDB.owner_id == owner_id,
                        BillingPaymentDB.status.in_(
                            ("created", "pending", "needsReview"),
                        ),
                    )
                    .values(
                        is_auto_renewing=False,
                    ),
                )

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
                    BillingSubscriptionDB.source == "robokassa",
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
        await self.reconcile_robokassa()
        async with self.database.session() as session:
            pending = list(
                await session.scalars(
                    select(
                        BillingPaymentDB.id,
                    )
                    .where(
                        BillingPaymentDB.source == "robokassa",
                        BillingPaymentDB.status.in_(
                            ("created", "pending", "needsReview"),
                        ),
                    )
                    .order_by(
                        BillingPaymentDB.reconciliation_attempted_at.asc().nullsfirst(),
                        BillingPaymentDB.created_at,
                    )
                    .limit(
                        self._configuration.server.billing.batch_size,
                    ),
                ),
            )
        for order_id in pending:
            try:
                async with self.database.session() as session:
                    pending_order = await session.get(
                        BillingPaymentDB,
                        order_id,
                    )
                    is_submitted = pending_order is not None and pending_order.submitted_at is not None
                if is_submitted:
                    await self.reconcile_pending_payment(
                        order_id,
                    )
                else:
                    await self.submit_payment(
                        order_id,
                    )
            except (BillingPaymentError, BillingPurchaseError, BillingUnavailableError):
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
                        BillingSubscriptionDB.source == "robokassa",
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
                replacement = await session.scalar(
                    select(
                        BillingPaymentDB.id,
                    )
                    .where(
                        BillingPaymentDB.previous_subscription_id == subscription.id,
                        BillingPaymentDB.status.in_(
                            ("created", "pending", "needsReview"),
                        ),
                    )
                    .limit(
                        1,
                    ),
                )
                if replacement:
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
                        receipt_email=subscription.receipt_email,
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
                    BillingPaymentDB.source == "robokassa",
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
                BillingSubscriptionDB.source == "robokassa",
                BillingSubscriptionDB.paid_until <= self._now(),
            ),
        )
        for subscription in expired:
            subscription.is_auto_renewing = False
            subscription.next_charge_at = None
        # The next pending-order query must not reuse a just-canceled renewal.
        await session.flush()

    async def reconcile_robokassa(
        self,
    ) -> None:
        async with self.database.session() as session:
            orders = list(
                await session.scalars(
                    select(
                        BillingPaymentDB.id,
                    )
                    .where(
                        BillingPaymentDB.source == "robokassa",
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
                if order is None or not order.provider_id or not order.invoice_id:
                    continue
                # Record attempts as well as successes so a failing provider object
                # cannot starve the rest of the bounded reconciliation queue.
                order.reconciliation_attempted_at = datetime.now(
                    UTC,
                )
                provider_id = order.invoice_id
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
