from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Request

from app.core.application.service_dependencies import ServiceDependencies
from app.core.http.http_header import HttpHeader
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.service.billing.subscription_service import SubscriptionService


class BillingDependencies:
    @staticmethod
    async def owner(
        request: Request,
        service: Annotated[
            SubscriptionService,
            Depends(
                ServiceDependencies.subscriptions,
            ),
        ],
    ) -> str:
        authorization = request.headers.get(
            HttpHeader.AUTHORIZATION,
            "",
        )
        if not authorization.startswith(
            "Bearer ",
        ):
            raise BillingAccessDeniedError()
        return await service.authenticate(
            authorization[7:],
        )

    @staticmethod
    async def dictation_access(
        request: Request,
    ) -> None:
        service = await ServiceDependencies.subscriptions(
            request,
        )
        owner = await BillingDependencies.owner(
            request,
            service,
        )
        await service.require_feature(
            owner,
            "formCompletionViaMicrophone",
        )

    @staticmethod
    async def email_access(
        request: Request,
    ) -> None:
        service = await ServiceDependencies.subscriptions(
            request,
        )
        owner = await BillingDependencies.owner(
            request,
            service,
        )
        await service.require_feature(
            owner,
            "sendingReportByEmail",
        )
