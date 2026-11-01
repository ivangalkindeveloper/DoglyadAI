from __future__ import annotations

from contextlib import AbstractAsyncContextManager
from types import TracebackType

from app.model.ultrasound.us_examination_request import USExaminationRequest
from app.service.billing.subscription_service import SubscriptionService


class BillingRequestGuard(AbstractAsyncContextManager[None]):
    def __init__(
        self,
        service: SubscriptionService,
        owner_id: str,
        operation_id: str,
    ) -> None:
        self._service = service
        self._owner_id = owner_id
        self._operation_id = operation_id

    async def __aenter__(
        self,
    ) -> None:
        await self._service.reserve(
            self._owner_id,
            self._operation_id,
        )

    async def authorize_report(
        self,
        body: USExaminationRequest,
    ) -> None:
        await self._service.require_report(
            self._owner_id,
            body,
        )

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_value: BaseException | None,
        traceback: TracebackType | None,
    ) -> None:
        await self._service.finish_usage(
            self._owner_id,
            self._operation_id,
            is_success=exc_type is None,
        )
