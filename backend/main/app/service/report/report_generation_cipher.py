from __future__ import annotations

import json
from typing import Any

from cryptography.fernet import Fernet


class ReportGenerationCipher:
    def __init__(
        self,
        key: str,
    ) -> None:
        self._fernet = Fernet(
            key.encode(
                "ascii",
            ),
        )

    def seal(
        self,
        value: dict[str, Any],
    ) -> bytes:
        return self._fernet.encrypt(
            json.dumps(
                value,
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode(),
        )

    def open(
        self,
        value: bytes,
    ) -> dict[str, Any]:
        decoded = json.loads(
            self._fernet.decrypt(
                value,
            ),
        )
        if not isinstance(
            decoded,
            dict,
        ):
            raise ValueError(
                "Invalid encrypted generation document",
            )
        return decoded
