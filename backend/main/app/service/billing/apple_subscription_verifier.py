from __future__ import annotations

import asyncio
import time
from typing import Any
from uuid import UUID

import httpx
import jwt
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import SignedDataVerifier, VerificationException

from app.core.configuration.variables import Variables
from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError
from app.model.http_client_config import HttpClientConfig


class AppleSubscriptionVerifier:
    def __init__(
        self,
        client: httpx.AsyncClient,
        variables: Variables,
        configuration: HttpClientConfig,
    ) -> None:
        self._client = client
        self._variables = variables
        self._configuration = configuration
        roots_path = variables.apple_root_certificates_path
        roots = (
            [
                path.read_bytes()
                for path in sorted(
                    roots_path.glob(
                        "*.cer",
                    ),
                )
            ]
            if roots_path
            else []
        )
        self._verifiers = (
            {
                environment: SignedDataVerifier(
                    roots,
                    True,
                    environment,
                    variables.apple_bundle_id,
                    variables.apple_app_id,
                )
                for environment in (Environment.PRODUCTION, Environment.SANDBOX)
            }
            if roots
            else {}
        )

    async def transaction(
        self,
        signed: str,
    ) -> tuple[Any, Environment]:
        for environment, verifier in self._verifiers.items():
            try:
                transaction = await asyncio.to_thread(
                    verifier.verify_and_decode_signed_transaction,
                    signed,
                )
                return transaction, environment
            except VerificationException:
                # Never log a signed transaction or provider exception text.
                continue
        if not self._verifiers:
            raise BillingUnavailableError()
        raise BillingPurchaseError()

    async def notification(
        self,
        signed: str,
    ) -> tuple[Any, Environment]:
        for environment, verifier in self._verifiers.items():
            try:
                notification = await asyncio.to_thread(
                    verifier.verify_and_decode_notification,
                    signed,
                )
                return notification, environment
            except VerificationException:
                continue
        if not self._verifiers:
            raise BillingUnavailableError()
        raise BillingPurchaseError()

    async def current(
        self,
        original_id: str,
        environment: Environment,
    ) -> tuple[Any, Any]:
        settings = self._variables
        if not (settings.apple_issuer_id and settings.apple_key_id and settings.apple_private_key_path):
            raise BillingUnavailableError()
        now = int(
            time.time(),
        )
        token = jwt.encode(
            {
                "iss": settings.apple_issuer_id,
                "iat": now,
                "exp": now + 300,
                "aud": "appstoreconnect-v1",
                "bid": settings.apple_bundle_id,
            },
            settings.apple_private_key_path.read_bytes(),
            algorithm="ES256",
            headers={"kid": settings.apple_key_id},
        )
        host = "api.storekit.apple.com" if environment is Environment.PRODUCTION else "api.storekit-sandbox.apple.com"
        try:
            async with asyncio.timeout(
                self._configuration.operation_timeout_seconds,
            ):
                response = await self._client.get(
                    f"https://{host}/inApps/v1/subscriptions/{original_id}",
                    headers={"Authorization": f"Bearer {token}"},
                    timeout=self._configuration.timeout(),
                )
                response.raise_for_status()
                data = response.json()
                for group in data.get(
                    "data",
                    [],
                ):
                    for item in group.get(
                        "lastTransactions",
                        [],
                    ):
                        if (
                            str(
                                item.get(
                                    "originalTransactionId",
                                ),
                            )
                            != original_id
                        ):
                            continue
                        verifier = self._verifiers[environment]
                        transaction = await asyncio.to_thread(
                            verifier.verify_and_decode_signed_transaction,
                            item["signedTransactionInfo"],
                        )
                        renewal = await asyncio.to_thread(
                            verifier.verify_and_decode_renewal_info,
                            item["signedRenewalInfo"],
                        )
                        return transaction, renewal
        except (httpx.HTTPError, ValueError, KeyError, VerificationException, TimeoutError) as error:
            raise BillingPurchaseError() from error
        raise BillingPurchaseError()

    @staticmethod
    def owner_id(
        transaction: Any,
    ) -> str:
        try:
            return str(
                UUID(
                    str(
                        transaction.appAccountToken,
                    ),
                ),
            )
        except (ValueError, AttributeError) as error:
            raise BillingPurchaseError() from error
