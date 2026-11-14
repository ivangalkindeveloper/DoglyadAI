from __future__ import annotations

from typing import Any

import httpx

from app.core.configuration.variables import Variables
from app.model.http_client_config import HttpClientConfig
from app.service.billing.robokassa_payment_provider import RobokassaPaymentProvider


class BillingTestRobokassaProvider(RobokassaPaymentProvider):
    """Canonical-result fixture for ledger unit tests; real protocol is tested separately."""

    def __init__(
        self,
        client: httpx.AsyncClient,
        variables: Variables,
        configuration: HttpClientConfig,
    ) -> None:
        super().__init__(
            client=client,
            variables=variables,
            configuration=configuration,
        )

    async def payment(
        self,
        invoice_id: str,
    ) -> dict[str, Any]:
        raw = await self._request(
            "GET",
            "https://canonical.example/payments/" + invoice_id,
        )
        return self._json(
            raw,
        )
