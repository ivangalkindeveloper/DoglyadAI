from __future__ import annotations

import html
import json
import secrets
from typing import Any
from urllib.parse import parse_qs, urlsplit

from fastapi import Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.core.application.main_container import MainContainer
from app.core.application.service_dependencies import ServiceDependencies
from app.error.billing_access_denied_error import BillingAccessDeniedError
from app.error.billing_purchase_error import BillingPurchaseError
from app.model.billing.billing_webhook_response import BillingWebhookResponse
from app.service.billing.subscription_service import SubscriptionService


class PaymentGateway:
    async def page(
        self,
        request: Request,
    ) -> HTMLResponse:
        csrf = secrets.token_urlsafe(
            32,
        )
        apple_token = request.query_params.get(
            "externalPurchaseToken",
            "",
        )
        if (
            len(
                apple_token,
            )
            > 16384
        ):
            raise BillingPurchaseError()
        body = (
            f'<form method="post" action="/pay/bind">'
            f'<input type="hidden" name="csrf" value="{csrf}">'
            f'<input type="hidden" name="apple_token" value="{html.escape(apple_token)}">'
            f"<label>{self._text(request, 'subscriptionPaymentCodeLabel')}"
            '<input name="code" autocomplete="off" minlength="8" maxlength="8" required></label>'
            f"<button>{self._text(request, 'subscriptionPaymentContinueButton')}</button></form>"
        )
        response = self._page(
            request,
            body,
        )
        response.set_cookie(
            "dg_csrf",
            csrf,
            secure=True,
            httponly=True,
            samesite="lax",
            max_age=request.app.state.server_config.billing.checkout_ttl_seconds,
            path="/pay",
        )
        return response

    async def bind(
        self,
        request: Request,
    ) -> HTMLResponse:
        form = await self._form(
            request,
        )
        service = await ServiceDependencies.subscriptions(
            request,
        )
        browser_token, plan = await service.bind_checkout(
            form.get(
                "code",
                "",
            ),
            form.get(
                "apple_token",
            )
            or None,
        )
        amount = f"{plan.price.amountMinor // 100}.{plan.price.amountMinor % 100:02d} {plan.price.currencyIso2Code}"
        period = self._text(
            request,
            plan.period.locale_key,
        )
        tier = self._text(
            request,
            "subscriptionBaseLabel" if plan.entitlement == "base" else "subscriptionProLabel",
        )
        csrf = secrets.token_urlsafe(
            32,
        )
        body = (
            f"<p>{tier} · {period} · {amount}</p>"
            f'<form method="post" action="/pay/confirm">'
            f'<input type="hidden" name="csrf" value="{csrf}">'
            '<label><input name="consent" type="checkbox" value="yes" required>'
            f"{self._text(request, 'subscriptionPaymentConsentDescription')}</label>"
            f"<button>{self._text(request, 'subscriptionPaymentPayButton')}</button></form>"
        )
        response = self._page(
            request,
            body,
        )
        response.set_cookie(
            "dg_checkout",
            browser_token,
            secure=True,
            httponly=True,
            samesite="lax",
            max_age=request.app.state.server_config.billing.checkout_ttl_seconds,
            path="/pay",
        )
        response.set_cookie(
            "dg_csrf",
            csrf,
            secure=True,
            httponly=True,
            samesite="lax",
            max_age=request.app.state.server_config.billing.checkout_ttl_seconds,
            path="/pay",
        )
        return response

    async def confirm(
        self,
        request: Request,
    ) -> RedirectResponse:
        form = await self._form(
            request,
        )
        service = await ServiceDependencies.subscriptions(
            request,
        )
        url = await service.start_checkout_payment(
            request.cookies.get(
                "dg_checkout",
                "",
            ),
            is_auto_renewal_accepted=form.get(
                "consent",
            )
            == "yes",
        )
        if (
            urlsplit(
                url,
            ).scheme
            != "https"
        ):
            raise BillingPurchaseError()
        return RedirectResponse(
            url,
            status_code=303,
            headers={"Cache-Control": "no-store", "Referrer-Policy": "no-referrer"},
        )

    async def complete(
        self,
        request: Request,
    ) -> HTMLResponse:
        return self._page(
            request,
            f"<p>{self._text(request, 'subscriptionPaymentCompleteDescription')}</p>"
            f'<a href="doglyad://subscription/complete">{self._text(request, "subscriptionPaymentReturnButton")}</a>',
        )

    async def yookassa(
        self,
        request: Request,
    ) -> BillingWebhookResponse:
        body = await self._json(
            request,
        )
        if not isinstance(
            body,
            dict,
        ) or not isinstance(
            body.get(
                "object",
            ),
            dict,
        ):
            raise BillingPurchaseError()
        event = body.get(
            "event",
        )
        if event not in ("payment.succeeded", "payment.canceled", "refund.succeeded"):
            return BillingWebhookResponse(
                status="ignored",
            )
        value = body["object"].get(
            "payment_id" if event == "refund.succeeded" else "id",
        )
        if (
            not isinstance(
                value,
                str,
            )
            or len(
                value,
            )
            > 64
            or not all(
                (c in "0123456789abcdef-" for c in value),
            )
        ):
            raise BillingPurchaseError()
        service = await ServiceDependencies.subscriptions(
            request,
        )
        await service.payment_notification(
            value,
        )
        return BillingWebhookResponse(
            status="accepted",
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

    @staticmethod
    async def _form(
        request: Request,
    ) -> dict[str, str]:
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
        service: SubscriptionService = await ServiceDependencies.subscriptions(
            request,
        )
        del service
        raw = await request.body()
        try:
            values = parse_qs(
                raw.decode(),
                max_num_fields=8,
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
        form = {key: value[0] for key, value in values.items()}
        csrf = request.cookies.get(
            "dg_csrf",
            "",
        )
        if not csrf or not secrets.compare_digest(
            csrf,
            form.get(
                "csrf",
                "",
            ),
        ):
            raise BillingAccessDeniedError()
        origin = request.headers.get(
            "origin",
        )
        public_url = request.app.state.variables.billing_public_url or ""
        parsed = urlsplit(
            public_url,
        )
        if origin and origin != f"{parsed.scheme}://{parsed.netloc}":
            raise BillingAccessDeniedError()
        return form

    @staticmethod
    def _text(
        request: Request,
        key: str,
    ) -> str:
        container: MainContainer = request.app.state.container
        language = container.configuration.language(
            request.headers.get(
                "accept-language",
            ),
        )
        return html.escape(
            container.configuration.application_localizations[language].strings[key],
        )

    def _page(
        self,
        request: Request,
        body: str,
    ) -> HTMLResponse:
        container: MainContainer = request.app.state.container
        privacy = html.escape(
            container.configuration.application["privacyPolicyUrl"],
            quote=True,
        )
        terms = html.escape(
            container.configuration.application["termsAndConditionsUrl"],
            quote=True,
        )
        return HTMLResponse(
            '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">'
            "<title>Doglyad</title><style>"
            "body{font:17px system-ui;max-width:480px;margin:48px auto;padding:20px;color:#172033}"
            "input,button{font:inherit;padding:12px;margin:12px 0;max-width:100%;box-sizing:border-box}"
            "label{display:block}input:not([type=checkbox]){display:block;width:100%}"
            "button{cursor:pointer;border:0;border-radius:12px;background:#316bea;color:white}"
            "footer{margin-top:28px;display:flex;gap:20px;font-size:14px}</style></head><body>"
            f"<h1>{self._text(request, 'subscriptionPaymentTitle')}</h1>{body}<footer>"
            f'<a href="{privacy}">{self._text(request, "buttonPrivacyPolicy")}</a>'
            f'<a href="{terms}">{self._text(request, "buttonTermsAndConditions")}</a></footer></body></html>',
            headers={
                "Cache-Control": "no-store",
                "Referrer-Policy": "no-referrer",
                "X-Content-Type-Options": "nosniff",
                "Content-Security-Policy": (
                    "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; "
                    "frame-ancestors 'none'; base-uri 'none'"
                ),
            },
        )
