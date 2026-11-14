from __future__ import annotations

import base64
import hashlib
import hmac
import json

from cryptography.fernet import Fernet, InvalidToken

from app.error.billing_purchase_error import BillingPurchaseError
from app.error.billing_unavailable_error import BillingUnavailableError


class BillingRecoveryKeyCipher:
    def __init__(
        self,
        encryption_key: str | None,
    ) -> None:
        self._fernet = (
            Fernet(
                base64.urlsafe_b64encode(
                    hmac.digest(
                        base64.urlsafe_b64decode(
                            encryption_key,
                        ),
                        b"Doglyad billing recovery v1",
                        hashlib.sha256,
                    ),
                ),
            )
            if encryption_key
            else None
        )

    def seal(
        self,
        owner_id: str,
        key: str,
    ) -> bytes:
        if self._fernet is None:
            raise BillingUnavailableError()
        return self._fernet.encrypt(
            json.dumps(
                {"ownerId": owner_id, "key": key},
            ).encode(),
        )

    def open(
        self,
        owner_id: str,
        ciphertext: bytes,
    ) -> str:
        if self._fernet is None:
            raise BillingUnavailableError()
        try:
            value = json.loads(
                self._fernet.decrypt(
                    ciphertext,
                ),
            )
            if value["ownerId"] != owner_id or not isinstance(
                value["key"],
                str,
            ):
                raise BillingPurchaseError()
            return value["key"]
        except (InvalidToken, ValueError, KeyError, TypeError) as error:
            raise BillingPurchaseError() from error
