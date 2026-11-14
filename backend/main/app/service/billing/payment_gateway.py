from __future__ import annotations

import json
from typing import Any
from urllib.parse import parse_qs

from fastapi import Request
from fastapi.responses import PlainTextResponse, RedirectResponse

from app.core.application.service_dependencies import ServiceDependencies
from app.error.billing_purchase_error import BillingPurchaseError
from app.model.billing.billing_webhook_response import BillingWebhookResponse


class PaymentGateway:
    def __init__(
        self,
    ) -> None:
        pass

    async def return_to_application(
        self,
    ) -> RedirectResponse:
        return RedirectResponse(
            "doglyad://subscription/complete",
            status_code=303,
            headers={"Cache-Control": "no-store"},
        )

    async def robokassa(
        self,
        request: Request,
    ) -> PlainTextResponse:
        if (
            request.headers.get(
                "content-type",
                "",
            ).split(
                ";",
            )[0]
            != "application/x-www-form-urlencoded"
        ):
            raise BillingPurchaseError()
        try:
            values = parse_qs(
                (await request.body()).decode(),
                max_num_fields=32,
                strict_parsing=True,
            )
        except (ValueError, UnicodeDecodeError) as error:
            raise BillingPurchaseError() from error
        if any(
            (
                len(
                    value,
                )
                != 1
                for value in values.values()
            ),
        ):
            raise BillingPurchaseError()
        fields = {key: value[0] for key, value in values.items()}
        service = await ServiceDependencies.subscriptions(
            request,
        )
        await service.robokassa_notification(
            fields,
        )
        return PlainTextResponse(
            "OK" + fields["InvId"],
            headers={"Cache-Control": "no-store"},
        )

    async def apple(
        self,
        request: Request,
    ) -> BillingWebhookResponse:
        body = await self._json(
            request,
        )
        signed = (
            body.get(
                "signedPayload",
            )
            if isinstance(
                body,
                dict,
            )
            else None
        )
        if (
            not isinstance(
                signed,
                str,
            )
            or not 1
            <= len(
                signed,
            )
            <= 65536
        ):
            raise BillingPurchaseError()
        service = await ServiceDependencies.subscriptions(
            request,
        )
        await service.apple_notification(
            signed,
        )
        return BillingWebhookResponse(
            status="accepted",
        )

    @staticmethod
    async def _json(
        request: Request,
    ) -> Any:
        try:
            return await request.json()
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            raise BillingPurchaseError() from error
